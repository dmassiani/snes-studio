import SwiftUI

struct SpriteDrawingWindowView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var pixels: [UInt8] = []
    @State private var currentTool: TileEditorTool = .pencil
    @State private var selectedColorIndex: UInt8 = 1
    @State private var zoom: CGFloat = 16
    @State private var brushSize: Int = 1
    @State private var fillShapes: Bool = false
    @State private var showTileGrid: Bool = true
    @State private var showBG: Bool = false
    @State private var showLightTable: Bool = true
    @State private var cursorX: Int = 0
    @State private var cursorY: Int = 0
    @State private var undoMgr = EditorUndoManager<[UInt8]>()
    @State private var selectedPaletteIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var animateMainCanvas: Bool = false
    @State private var playbackPreviewIndex: Int = 0
    @State private var draggedFrameIndex: Int?

    private var session: SpriteDrawingSession { state.spriteDrawingSession }

    private var palettes: [SNESPalette] { state.assetStore.palettes }

    private var currentPalette: SNESPalette {
        guard selectedPaletteIndex < palettes.count else {
            return SNESPalette.defaultPalettes()[0]
        }
        return palettes[selectedPaletteIndex]
    }

    private var depth: TileDepth { session.tileDepth }

    /// Count of non-transparent 8x8 tiles in current canvas
    private var tileCount: Int {
        guard session.canvasWidth > 0, session.canvasHeight > 0 else { return 0 }
        let tilesX = session.canvasWidth / 8
        let tilesY = session.canvasHeight / 8
        var count = 0
        for tileRow in 0..<tilesY {
            for tileCol in 0..<tilesX {
                var allTransparent = true
                outer: for py in 0..<8 {
                    for px in 0..<8 {
                        let idx = (tileRow * 8 + py) * session.canvasWidth + (tileCol * 8 + px)
                        if idx < pixels.count, pixels[idx] != 0 {
                            allTransparent = false
                            break outer
                        }
                    }
                }
                if !allTransparent { count += 1 }
            }
        }
        return count
    }

    private var maxTiles: Int {
        guard session.canvasWidth > 0, session.canvasHeight > 0 else { return 0 }
        return (session.canvasWidth / 8) * (session.canvasHeight / 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            HStack(spacing: 0) {
                toolStrip
                canvasArea
                colorPanel
            }

            // Frame strip (only if animation has multiple frames)
            if session.hasAnimation {
                frameStrip
            }

            statusBar
        }
        .background(SNESTheme.bgMain)
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            pixels = session.canvasPixels
            selectedPaletteIndex = session.paletteIndex
        }
        .onReceive(NotificationCenter.default.publisher(for: .spriteDrawingUndo)) { _ in
            if let prev = undoMgr.undo(current: pixels) { pixels = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spriteDrawingRedo)) { _ in
            if let next = undoMgr.redo(current: pixels) { pixels = next }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spriteDrawingPrevFrame)) { _ in
            navigateFrame(delta: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .spriteDrawingNextFrame)) { _ in
            navigateFrame(delta: 1)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            // Canvas size picker
            Picker("Size", selection: Binding(
                get: { "\(session.canvasWidth)x\(session.canvasHeight)" },
                set: { newVal in
                    let parts = newVal.split(separator: "x")
                    if parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) {
                        resizeCanvas(to: w, height: h)
                    }
                }
            )) {
                Text("16x16").tag("16x16")
                Text("32x32").tag("32x32")
                Text("48x48").tag("48x48")
                Text("64x64").tag("64x64")
            }
            .frame(width: 90)

            Divider().frame(height: 16)

            Text(depth.label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)

            Divider().frame(height: 16)

            // Zoom
            Button {
                zoom = max(4, zoom - 4)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SNESTheme.textSecondary)
            .disabled(zoom <= 4)

            Text("\(Int(zoom))x")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 24)

            Button {
                zoom = min(32, zoom + 4)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SNESTheme.textSecondary)
            .disabled(zoom >= 32)

            Divider().frame(height: 16)

            // BG toggle
            Toggle("BG", isOn: $showBG)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textSecondary)
                .disabled(session.bgSnapshot == nil)

            // Light table toggle
            if session.hasAnimation {
                Toggle("Light", isOn: $showLightTable)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textSecondary)
            }

            Spacer()

            // Animation info
            if session.hasAnimation {
                Text(session.animationName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SNESTheme.info)

                Divider().frame(height: 16)
            }

            Button("Cancel") {
                stopPlayback()
                session.onCancel?()
                session.reset()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                stopPlayback()
                saveAndClose()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Tool Strip

    private var toolStrip: some View {
        VStack(spacing: 2) {
            Group {
                stripTool("pencil", tool: .pencil)
                stripTool("line.diagonal", tool: .line)
                stripTool("rectangle", tool: .rectangle)
                stripTool("circle", tool: .circle)
                stripTool("drop.fill", tool: .fill)
                stripTool("square.grid.2x2", tool: .dither)
                stripTool("eraser", tool: .eraser)
                stripTool("eyedropper", tool: .eyedropper)
                stripTool("rectangle.dashed", tool: .selection)
            }

            Divider().padding(.horizontal, 4)

            HStack(spacing: 3) {
                ForEach([1, 2, 3], id: \.self) { size in
                    Button {
                        brushSize = size
                    } label: {
                        Circle()
                            .fill(brushSize == size ? SNESTheme.info : SNESTheme.textSecondary)
                            .frame(width: CGFloat(size * 2 + 2), height: CGFloat(size * 2 + 2))
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)

            Divider().padding(.horizontal, 4)

            Button {
                fillShapes.toggle()
            } label: {
                Image(systemName: fillShapes ? "square.fill" : "square")
                    .font(.system(size: 11))
                    .foregroundStyle(fillShapes ? SNESTheme.info : SNESTheme.textDisabled)
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.plain)
            .help(fillShapes ? "Filled" : "Outline")

            Spacer()
        }
        .padding(.vertical, 6)
        .frame(width: 36)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .trailing) {
            SNESTheme.border.frame(width: 1)
        }
    }

    private func stripTool(_ icon: String, tool: TileEditorTool) -> some View {
        Button {
            currentTool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(currentTool == tool ? SNESTheme.info : SNESTheme.textSecondary)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentTool == tool ? SNESTheme.info.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Canvas Area

    private var previewScale: CGFloat {
        let maxDim = max(session.canvasWidth, session.canvasHeight)
        if maxDim <= 16 { return 4 }
        if maxDim <= 32 { return 3 }
        if maxDim <= 48 { return 2 }
        return 1.5
    }

    private var canvasArea: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        SpriteDrawingNSView(
                            pixels: $pixels,
                            canvasWidth: session.canvasWidth,
                            canvasHeight: session.canvasHeight,
                            palette: currentPalette,
                            selectedColorIndex: selectedColorIndex,
                            currentTool: currentTool,
                            zoom: zoom,
                            brushSize: brushSize,
                            fillShapes: fillShapes,
                            showTileGrid: showTileGrid,
                            bgImage: session.bgSnapshot,
                            showBG: showBG,
                            bgOffsetX: session.spriteScreenX,
                            bgOffsetY: session.spriteScreenY,
                            ghostPrevPixels: session.prevFramePixels,
                            ghostNextPixels: session.nextFramePixels,
                            showLightTable: showLightTable,
                            onBeginEdit: {
                                undoMgr.recordState(pixels)
                            },
                            onColorPicked: { colorIdx in
                                selectedColorIndex = colorIdx
                            },
                            onCursorMoved: { x, y in
                                cursorX = x
                                cursorY = y
                            },
                            onPrevFrame: {
                                navigateFrame(delta: -1)
                            },
                            onNextFrame: {
                                navigateFrame(delta: 1)
                            },
                            onTogglePlayback: {
                                togglePlayback()
                            }
                        )
                        .frame(
                            width: zoom * CGFloat(session.canvasWidth),
                            height: zoom * CGFloat(session.canvasHeight)
                        )
                        Spacer()
                    }
                    Spacer()
                }
            }
            .background(SNESTheme.bgEditor)

            // Mini preview — real-size sprite
            miniPreview
                .padding(8)
        }
    }

    // MARK: - Mini Preview

    /// Pixels shown in the mini preview: during playback shows the cycling frame, otherwise mirrors the main canvas.
    private var previewPixels: [UInt8] {
        if isPlaying, playbackPreviewIndex < session.allFramePixels.count {
            // During playback, if preview is on the frame we're editing, show live pixels
            if playbackPreviewIndex == session.currentFrameIndex {
                return pixels
            }
            return session.allFramePixels[playbackPreviewIndex]
        }
        return pixels
    }

    private var miniPreview: some View {
        let scale = previewScale
        let w = CGFloat(session.canvasWidth) * scale
        let h = CGFloat(session.canvasHeight) * scale
        let pxBuf = previewPixels

        return Canvas { ctx, size in
            // Checkerboard
            let cs: CGFloat = max(scale, 2)
            let cols = Int(ceil(size.width / cs))
            let rows = Int(ceil(size.height / cs))
            for row in 0..<rows {
                for col in 0..<cols {
                    let light = (row + col) % 2 == 0
                    ctx.fill(
                        Path(CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs, width: cs, height: cs)),
                        with: .color(light ? Color(white: 0.18) : Color(white: 0.12))
                    )
                }
            }
            // Pixels
            for py in 0..<session.canvasHeight {
                for px in 0..<session.canvasWidth {
                    let idx = py * session.canvasWidth + px
                    guard idx < pxBuf.count else { continue }
                    let colorIdx = Int(pxBuf[idx])
                    if colorIdx == 0 { continue }
                    let snesColor = currentPalette[colorIdx]
                    let rect = CGRect(
                        x: CGFloat(px) * scale,
                        y: CGFloat(py) * scale,
                        width: max(scale, 1),
                        height: max(scale, 1)
                    )
                    ctx.fill(Path(rect), with: .color(snesColor.color))
                }
            }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(SNESTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }

    // MARK: - Frame Strip

    private var frameStrip: some View {
        VStack(spacing: 0) {
            SNESTheme.border.frame(height: 1)

            HStack(spacing: 6) {
                // Prev button
                Button {
                    navigateFrame(delta: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(session.currentFrameIndex > 0 ? SNESTheme.textPrimary : SNESTheme.textDisabled)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(session.currentFrameIndex <= 0)

                // Frame thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(0..<session.frameCount, id: \.self) { frameIdx in
                            frameThumbnail(index: frameIdx)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Next button
                Button {
                    navigateFrame(delta: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(session.currentFrameIndex < session.frameCount - 1 ? SNESTheme.textPrimary : SNESTheme.textDisabled)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(session.currentFrameIndex >= session.frameCount - 1)

                Divider().frame(height: 20)

                // Play/Pause
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(isPlaying ? SNESTheme.warning : SNESTheme.success)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "Pause" : "Play animation")

                Toggle("Canvas", isOn: $animateMainCanvas)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
                    .help("Animer aussi le canvas principal")

                Divider().frame(height: 20)

                // Frame counter
                Text("Frame \(session.currentFrameIndex + 1)/\(session.frameCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textSecondary)
                    .frame(width: 80)

                Spacer()

                Divider().frame(height: 20)

                // Add frame
                Button {
                    addFrame()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Add empty frame")

                // Duplicate frame
                Button {
                    duplicateFrame()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Duplicate current frame")

                // Delete frame
                Button {
                    deleteFrame()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(session.frameCount > 1 ? SNESTheme.danger : SNESTheme.textDisabled)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(session.frameCount <= 1)
                .help("Delete current frame")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(SNESTheme.bgPanel)
        }
    }

    private func frameThumbnail(index frameIdx: Int) -> some View {
        let isCurrent = frameIdx == session.currentFrameIndex
        let framePixels = session.allFramePixels[frameIdx]

        return Button {
            goToFrame(frameIdx)
        } label: {
            Canvas { ctx, size in
                // Checkerboard background
                let cs: CGFloat = 3
                for row in 0..<Int(size.height / cs) + 1 {
                    for col in 0..<Int(size.width / cs) + 1 {
                        let light = (row + col) % 2 == 0
                        ctx.fill(
                            Path(CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs, width: cs, height: cs)),
                            with: .color(light ? Color(white: 0.15) : Color(white: 0.11))
                        )
                    }
                }
                // Draw pixels scaled to thumbnail
                let scaleX = size.width / CGFloat(session.canvasWidth)
                let scaleY = size.height / CGFloat(session.canvasHeight)
                let scale = min(scaleX, scaleY)
                let offX = (size.width - CGFloat(session.canvasWidth) * scale) / 2
                let offY = (size.height - CGFloat(session.canvasHeight) * scale) / 2

                for py in 0..<session.canvasHeight {
                    for px in 0..<session.canvasWidth {
                        let idx = py * session.canvasWidth + px
                        guard idx < framePixels.count else { continue }
                        let colorIdx = Int(framePixels[idx])
                        if colorIdx == 0 { continue }
                        let snesColor = currentPalette[colorIdx]
                        let rect = CGRect(
                            x: offX + CGFloat(px) * scale,
                            y: offY + CGFloat(py) * scale,
                            width: max(scale, 1),
                            height: max(scale, 1)
                        )
                        ctx.fill(Path(rect), with: .color(snesColor.color))
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isCurrent ? SNESTheme.info : SNESTheme.border, lineWidth: isCurrent ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(draggedFrameIndex == frameIdx ? 0.4 : 1.0)
        .onDrag {
            draggedFrameIndex = frameIdx
            return NSItemProvider(object: String(frameIdx) as NSString)
        }
        .onDrop(of: [.text], delegate: FrameReorderDropDelegate(
            targetIndex: frameIdx,
            draggedIndex: $draggedFrameIndex,
            onReorder: { source, destination in
                reorderFrame(from: source, to: destination)
            }
        ))
        .contextMenu {
            Button("Insert Before") {
                insertFrameBefore(index: frameIdx)
            }
            Button("Insert After") {
                insertFrameAfter(index: frameIdx)
            }

            Divider()

            Button("Duplicate") {
                duplicateFrame(at: frameIdx)
            }

            Divider()

            Button("Move Left") {
                moveFrame(at: frameIdx, delta: -1)
            }
            .disabled(frameIdx <= 0)

            Button("Move Right") {
                moveFrame(at: frameIdx, delta: 1)
            }
            .disabled(frameIdx >= session.frameCount - 1)

            Divider()

            Button("Delete", role: .destructive) {
                deleteFrame(at: frameIdx)
            }
            .disabled(session.frameCount <= 1)
        }
    }

    // MARK: - Color Panel

    private var colorPanel: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                if selectedColorIndex == 0 {
                    transparencyCheckerboard(size: 32)
                        .overlay(
                            Text("T")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white, lineWidth: 2)
                        )
                } else {
                    currentPalette[Int(selectedColorIndex)].color
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                Text(selectedColorIndex == 0 ? "T" : "#\(selectedColorIndex)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SNESTheme.textSecondary)
            }

            Divider().padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.fixed(22)), GridItem(.fixed(22))], spacing: 2) {
                ForEach(0..<min(depth.maxColorIndex + 1, 16), id: \.self) { idx in
                    Button {
                        selectedColorIndex = UInt8(idx)
                    } label: {
                        Group {
                            if idx == 0 {
                                transparencyCheckerboard(size: 22)
                            } else {
                                currentPalette[idx].color
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(selectedColorIndex == UInt8(idx) ? Color.white : SNESTheme.border.opacity(0.5),
                                        lineWidth: selectedColorIndex == UInt8(idx) ? 2 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().padding(.horizontal, 4)

            Text("Pal")
                .font(.system(size: 9))
                .foregroundStyle(SNESTheme.textDisabled)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(0..<palettes.count, id: \.self) { palIdx in
                        Button {
                            selectedPaletteIndex = palIdx
                        } label: {
                            HStack(spacing: 0) {
                                ForEach(0..<8, id: \.self) { ci in
                                    if ci == 0 {
                                        Canvas { ctx, sz in
                                            let half = sz.width / 2
                                            for r in 0..<2 {
                                                for c in 0..<2 {
                                                    let col: Color = (r + c) % 2 == 0 ? Color(white: 0.22) : Color(white: 0.13)
                                                    ctx.fill(Path(CGRect(x: CGFloat(c) * half, y: CGFloat(r) * (sz.height / 2), width: half, height: sz.height / 2)), with: .color(col))
                                                }
                                            }
                                        }
                                        .frame(width: 6, height: 10)
                                    } else {
                                        palettes[palIdx][ci].color
                                            .frame(width: 6, height: 10)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(selectedPaletteIndex == palIdx ? SNESTheme.info : SNESTheme.border,
                                            lineWidth: selectedPaletteIndex == palIdx ? 2 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: 62)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .leading) {
            SNESTheme.border.frame(width: 1)
        }
    }

    private func transparencyCheckerboard(size: CGFloat) -> some View {
        Canvas { ctx, sz in
            let cs = sz.width / 4
            for row in 0..<4 {
                for col in 0..<4 {
                    let color: Color = (row + col) % 2 == 0 ? Color(white: 0.22) : Color(white: 0.13)
                    ctx.fill(Path(CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs, width: cs, height: cs)), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text("(\(cursorX), \(cursorY))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)

            Divider().frame(height: 12)

            Text("Tiles: \(tileCount)/\(maxTiles)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)

            Divider().frame(height: 12)

            Text("OAM: \(tileCount)/128")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(tileCount > 128 ? SNESTheme.danger : SNESTheme.textSecondary)

            if session.hasAnimation {
                Divider().frame(height: 12)

                Text("Frame \(session.currentFrameIndex + 1)/\(session.frameCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.info)

                // Light table legend
                if showLightTable {
                    Divider().frame(height: 12)
                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 0.2, green: 0.5, blue: 1.0)).frame(width: 6, height: 6)
                        Text("Prev")
                            .font(.system(size: 9))
                            .foregroundStyle(SNESTheme.textDisabled)
                        Circle().fill(Color(red: 1.0, green: 0.3, blue: 0.2)).frame(width: 6, height: 6)
                        Text("Next")
                            .font(.system(size: 9))
                            .foregroundStyle(SNESTheme.textDisabled)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .top) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Frame Navigation

    private func navigateFrame(delta: Int) {
        let newIndex = session.currentFrameIndex + delta
        guard newIndex >= 0, newIndex < session.frameCount else { return }
        goToFrame(newIndex)
    }

    private func goToFrame(_ index: Int) {
        if let newPixels = session.goToFrame(index, savingCurrent: pixels) {
            undoMgr.clear()
            pixels = newPixels
        }
    }

    // MARK: - Frame Management

    private func addFrame() {
        stopPlayback()
        undoMgr.clear()
        pixels = session.addFrame(savingCurrent: pixels)
    }

    private func duplicateFrame() {
        stopPlayback()
        undoMgr.clear()
        pixels = session.duplicateFrame(savingCurrent: pixels)
    }

    private func duplicateFrame(at index: Int) {
        stopPlayback()
        undoMgr.clear()
        pixels = session.duplicateFrame(at: index, savingCurrent: pixels)
    }

    private func deleteFrame() {
        stopPlayback()
        if let newPixels = session.deleteFrame(savingCurrent: pixels) {
            undoMgr.clear()
            pixels = newPixels
        }
    }

    private func deleteFrame(at index: Int) {
        stopPlayback()
        if let newPixels = session.deleteFrame(at: index, savingCurrent: pixels) {
            undoMgr.clear()
            pixels = newPixels
        }
    }

    private func moveFrame(at index: Int, delta: Int) {
        stopPlayback()
        session.moveFrame(at: index, delta: delta, savingCurrent: pixels)
        pixels = session.canvasPixels
    }

    private func reorderFrame(from source: Int, to destination: Int) {
        stopPlayback()
        session.reorderFrame(from: source, to: destination, savingCurrent: pixels)
        pixels = session.canvasPixels
    }

    private func insertFrameBefore(index: Int) {
        stopPlayback()
        undoMgr.clear()
        // "after: index - 1" inserts at position index (before the target)
        pixels = session.insertEmptyFrame(after: index - 1, savingCurrent: pixels)
    }

    private func insertFrameAfter(index: Int) {
        stopPlayback()
        undoMgr.clear()
        pixels = session.insertEmptyFrame(after: index, savingCurrent: pixels)
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard session.frameCount > 1 else { return }
        // Save current edits so allFramePixels is up to date
        session.saveCurrentFrame(pixels)
        playbackPreviewIndex = session.currentFrameIndex
        isPlaying = true
        playbackTask = Task { @MainActor in
            while !Task.isCancelled {
                // Get frame duration from current preview frame (in 1/60s units)
                let duration: Int
                if playbackPreviewIndex < session.originalFrames.count {
                    duration = max(session.originalFrames[playbackPreviewIndex].duration, 1)
                } else {
                    duration = 4
                }
                let seconds = Double(duration) / 60.0
                try? await Task.sleep(for: .seconds(seconds))
                if Task.isCancelled { break }

                // Advance preview index (always loops)
                playbackPreviewIndex = (playbackPreviewIndex + 1) % session.frameCount

                // If "Canvas" checkbox is on, also switch the main canvas
                if animateMainCanvas {
                    if let newPixels = session.goToFrame(playbackPreviewIndex, savingCurrent: pixels) {
                        undoMgr.clear()
                        pixels = newPixels
                    }
                }
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    // MARK: - Actions

    private func resizeCanvas(to width: Int, height: Int) {
        undoMgr.recordState(pixels)
        let oldW = session.canvasWidth
        var newPixels = [UInt8](repeating: 0, count: width * height)

        let copyW = min(oldW, width)
        let copyH = min(session.canvasHeight, height)
        for y in 0..<copyH {
            for x in 0..<copyW {
                let oldIdx = y * oldW + x
                let newIdx = y * width + x
                if oldIdx < pixels.count {
                    newPixels[newIdx] = pixels[oldIdx]
                }
            }
        }

        // Also resize all other frame buffers
        for i in 0..<session.allFramePixels.count {
            if i == session.currentFrameIndex {
                session.allFramePixels[i] = newPixels
            } else {
                var resized = [UInt8](repeating: 0, count: width * height)
                let oldBuf = session.allFramePixels[i]
                for y in 0..<copyH {
                    for x in 0..<copyW {
                        let oldIdx = y * oldW + x
                        let newIdx = y * width + x
                        if oldIdx < oldBuf.count {
                            resized[newIdx] = oldBuf[oldIdx]
                        }
                    }
                }
                session.allFramePixels[i] = resized
            }
        }

        session.canvasWidth = width
        session.canvasHeight = height
        session.canvasPixels = newPixels
        pixels = newPixels
    }

    private func saveAndClose() {
        // Save current frame pixels first
        session.saveCurrentFrame(pixels)

        // Decompose each frame into tiles + OAM entries
        var allTiles = state.assetStore.tiles
        var newFrames: [SpriteFrame] = []

        for (i, framePixels) in session.allFramePixels.enumerated() {
            let result = SpriteDecomposer.decompose(
                pixels: framePixels,
                width: session.canvasWidth,
                height: session.canvasHeight,
                depth: session.tileDepth,
                paletteIndex: selectedPaletteIndex,
                existingTiles: allTiles
            )
            allTiles = result.tiles

            // Preserve original frame duration
            let duration = i < session.originalFrames.count
                ? session.originalFrames[i].duration
                : 4
            var frame = SpriteFrame(entries: result.entries, duration: duration)
            // Preserve original frame ID if possible
            if i < session.originalFrames.count {
                frame.id = session.originalFrames[i].id
            }
            newFrames.append(frame)
        }

        session.onSaveAllFrames?(allTiles, newFrames)
        session.reset()
        dismiss()
    }
}

// MARK: - Drop Delegate for frame reordering

struct FrameReorderDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggedIndex: Int?
    var onReorder: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggedIndex, source != targetIndex else { return }
        onReorder(source, targetIndex)
        draggedIndex = targetIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedIndex != nil
    }
}
