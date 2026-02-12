import SwiftUI

struct TileEditorView: NSViewRepresentable {
    @Binding var tiles: [SNESTile]
    var gridCols: Int
    var gridRows: Int
    var palette: SNESPalette
    var selectedColorIndex: UInt8
    var currentTool: TileEditorTool
    var zoom: CGFloat
    var brushSize: Int
    var fillShapes: Bool
    var onBeginEdit: (() -> Void)?
    var onColorPicked: ((UInt8) -> Void)?

    func makeNSView(context: Context) -> TileEditorCanvas {
        let canvas = TileEditorCanvas()
        canvas.tiles = tiles
        canvas.gridCols = gridCols
        canvas.gridRows = gridRows
        canvas.palette = palette
        canvas.selectedColorIndex = selectedColorIndex
        canvas.currentTool = currentTool
        canvas.zoom = zoom
        canvas.brushSize = brushSize
        canvas.fillShapes = fillShapes
        canvas.onTilesChanged = { newTiles in self.tiles = newTiles }
        canvas.onBeginEdit = onBeginEdit
        canvas.onColorPicked = onColorPicked
        return canvas
    }

    func updateNSView(_ canvas: TileEditorCanvas, context: Context) {
        canvas.gridCols = gridCols
        canvas.gridRows = gridRows
        canvas.tiles = tiles
        canvas.palette = palette
        canvas.selectedColorIndex = selectedColorIndex
        canvas.currentTool = currentTool
        canvas.zoom = zoom
        canvas.brushSize = brushSize
        canvas.fillShapes = fillShapes
        canvas.onTilesChanged = { newTiles in self.tiles = newTiles }
        canvas.onBeginEdit = onBeginEdit
        canvas.onColorPicked = onColorPicked
    }
}

// MARK: - Container

struct TileEditorContainerView: View {
    @Bindable var state: AppState

    @State private var tiles: [SNESTile] = [.empty()]
    @State private var selectedTileIndex: Int = 0
    @State private var selectedPaletteIndex: Int = 0
    @State private var selectedColorIndex: UInt8 = 1
    @State private var currentTool: TileEditorTool = .pencil
    @State private var zoom: CGFloat = 24
    @State private var depth: TileDepth = .bpp4
    @State private var gridCols: Int = 1
    @State private var gridRows: Int = 1
    @State private var brushSize: Int = 1
    @State private var fillShapes: Bool = false
    @State private var swapToIndex: UInt8 = 0
    @State private var undoMgr = EditorUndoManager<[SNESTile]>()

    private var safeTileIndex: Int {
        guard !tiles.isEmpty else { return 0 }
        return min(selectedTileIndex, tiles.count - 1)
    }

    /// Read palettes directly from AssetStore — always in sync with Palette Editor
    private var palettes: [SNESPalette] { state.assetStore.palettes }

    private var currentPalette: SNESPalette {
        guard selectedPaletteIndex < palettes.count else {
            return SNESPalette.defaultPalettes()[0]
        }
        return palettes[selectedPaletteIndex]
    }

    var body: some View {
        HSplitView {
            // Left: Tileset browser
            TilesetBrowserView(
                tiles: $tiles,
                selectedIndex: $selectedTileIndex,
                palette: currentPalette,
                depth: $depth,
                gridCols: gridCols,
                gridRows: gridRows
            )
            .frame(minWidth: 140, idealWidth: 180, maxWidth: 240)

            // Editor area
            VStack(spacing: 0) {
                // Top: Settings bar
                settingsBar

                // Middle: Tool strip + Canvas + Color panel
                HStack(spacing: 0) {
                    toolStrip
                    canvasArea
                    colorPanel
                }

                // Bottom: Transforms bar
                SNESTheme.border.frame(height: 1)
                transformBar
            }
        }
        .onChange(of: tiles) {
            state.assetStore.tiles = tiles
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil, userInfo: ["debounce": true])
            if selectedTileIndex >= tiles.count {
                selectedTileIndex = max(0, tiles.count - 1)
            }
        }
        .onChange(of: gridCols) { ensureEnoughTiles() }
        .onChange(of: gridRows) { ensureEnoughTiles() }
        .onChange(of: selectedTileIndex) { ensureEnoughTiles() }
        .onReceive(NotificationCenter.default.publisher(for: .editorUndo)) { _ in
            if let prev = undoMgr.undo(current: tiles) { tiles = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorRedo)) { _ in
            if let next = undoMgr.redo(current: tiles) { tiles = next }
        }
        .onAppear {
            tiles = state.assetStore.tiles
            ensureEnoughTiles()
        }
        .onDisappear {
            state.assetStore.tiles = tiles
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .assetStoreDidChange)) { _ in
            tiles = state.assetStore.tiles
        }
    }

    // MARK: - Settings bar (top)

    private var settingsBar: some View {
        HStack(spacing: 8) {
            Text("Grid")
                .font(.system(size: 9))
                .foregroundStyle(SNESTheme.textDisabled)
            Stepper("\(gridCols)", value: $gridCols, in: 1...8)
                .frame(width: 58)
            Text("\u{00D7}")
                .font(.system(size: 9))
                .foregroundStyle(SNESTheme.textSecondary)
            Stepper("\(gridRows)", value: $gridRows, in: 1...8)
                .frame(width: 58)

            Divider().frame(height: 14)

            Picker("Depth", selection: $depth) {
                ForEach(TileDepth.allCases, id: \.self) { d in
                    Text(d.label).tag(d)
                }
            }
            .frame(width: 85)

            Divider().frame(height: 14)

            Picker("Zoom", selection: $zoom) {
                Text("8x").tag(CGFloat(8))
                Text("16x").tag(CGFloat(16))
                Text("24x").tag(CGFloat(24))
                Text("32x").tag(CGFloat(32))
            }
            .frame(width: 75)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Tool strip (left)

    private var toolStrip: some View {
        VStack(spacing: 2) {
            // Drawing tools
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

            // Brush size (visual dots)
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

            // Fill toggle
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

    // MARK: - Canvas (center)

    private var canvasArea: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if !tiles.isEmpty {
                    TileEditorView(
                        tiles: gridTileBinding(),
                        gridCols: gridCols,
                        gridRows: gridRows,
                        palette: currentPalette,
                        selectedColorIndex: selectedColorIndex,
                        currentTool: currentTool,
                        zoom: zoom,
                        brushSize: brushSize,
                        fillShapes: fillShapes,
                        onBeginEdit: {
                            undoMgr.recordState(tiles)
                        },
                        onColorPicked: { colorIdx in
                            selectedColorIndex = colorIdx
                        }
                    )
                    .frame(
                        width: zoom * 8 * CGFloat(gridCols),
                        height: zoom * 8 * CGFloat(gridRows)
                    )
                }
                Spacer()
            }
            Spacer()
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Color panel (right)

    private var colorPanel: some View {
        VStack(spacing: 8) {
            // Current color indicator
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

            // 2-column color grid
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

            // Palette selector (vertical scroll)
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

    /// Reusable checkerboard view for transparent color indicator
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

    // MARK: - Transform bar (bottom)

    private var transformBar: some View {
        HStack(spacing: 6) {
            transformButton("arrow.left.and.right", help: "Flip H") { applyTransform { $0.flippedHorizontally() } }
            transformButton("arrow.up.and.down", help: "Flip V") { applyTransform { $0.flippedVertically() } }
            transformButton("arrow.clockwise", help: "Rotate 90\u{00B0}") { applyTransform { $0.rotatedClockwise() } }

            Divider().frame(height: 14)

            transformButton("arrow.left", help: "Shift Left") { applyTransform { $0.shifted(dx: -1, dy: 0) } }
            transformButton("arrow.up", help: "Shift Up") { applyTransform { $0.shifted(dx: 0, dy: -1) } }
            transformButton("arrow.down", help: "Shift Down") { applyTransform { $0.shifted(dx: 0, dy: 1) } }
            transformButton("arrow.right", help: "Shift Right") { applyTransform { $0.shifted(dx: 1, dy: 0) } }

            Divider().frame(height: 14)

            // Replace color
            Group {
                if selectedColorIndex == 0 {
                    transparencyCheckerboard(size: 12)
                } else {
                    currentPalette[Int(selectedColorIndex)].color
                        .frame(width: 12, height: 12)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 1).stroke(SNESTheme.border, lineWidth: 0.5))
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(SNESTheme.textDisabled)
            Picker("", selection: $swapToIndex) {
                ForEach(0..<min(depth.maxColorIndex + 1, 16), id: \.self) { i in
                    Text("\(i)").tag(UInt8(i))
                }
            }
            .frame(width: 50)
            Button {
                replaceColor(from: selectedColorIndex, to: swapToIndex)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Replace color")

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Helpers

    private func transformButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 22, height: 20)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func ensureEnoughTiles() {
        let needed = safeTileIndex + gridCols * gridRows
        if needed > tiles.count {
            let toAdd = needed - tiles.count
            tiles.append(contentsOf: (0..<toAdd).map { _ in .empty(depth: depth) })
        }
    }

    private func gridTileBinding() -> Binding<[SNESTile]> {
        let start = safeTileIndex
        let count = gridCols * gridRows
        return Binding<[SNESTile]>(
            get: {
                let end = min(start + count, tiles.count)
                guard start < end else { return [] }
                return Array(tiles[start..<end])
            },
            set: { newTiles in
                for i in 0..<min(newTiles.count, count) {
                    let idx = start + i
                    if idx < tiles.count {
                        tiles[idx] = newTiles[i]
                    }
                }
            }
        )
    }

    // MARK: - Actions

    private func applyTransform(_ transform: (SNESTile) -> SNESTile) {
        undoMgr.recordState(tiles)
        let start = safeTileIndex
        let count = gridCols * gridRows
        for i in 0..<count {
            let idx = start + i
            guard idx < tiles.count else { continue }
            tiles[idx] = transform(tiles[idx])
        }
    }

    private func replaceColor(from: UInt8, to: UInt8) {
        guard from != to else { return }
        undoMgr.recordState(tiles)
        let start = safeTileIndex
        let count = gridCols * gridRows
        for i in 0..<count {
            let idx = start + i
            guard idx < tiles.count else { continue }
            for y in 0..<8 {
                for x in 0..<8 {
                    if tiles[idx].pixel(x: x, y: y) == from {
                        tiles[idx].setPixel(x: x, y: y, value: to)
                    }
                }
            }
        }
    }
}
