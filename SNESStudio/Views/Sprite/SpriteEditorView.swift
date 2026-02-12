import SwiftUI

struct SpriteEditorNSView: NSViewRepresentable {
    @Binding var entries: [OAMEntry]
    var tiles: [SNESTile]
    var palettes: [SNESPalette]
    var showGrid: Bool
    var zoom: CGFloat
    @Binding var selectedIndex: Int?
    var onBeginEdit: (() -> Void)?

    func makeNSView(context: Context) -> SpriteCanvas {
        let canvas = SpriteCanvas()
        canvas.entries = entries
        canvas.tiles = tiles
        canvas.palettes = palettes
        canvas.showGrid = showGrid
        canvas.zoom = zoom
        canvas.selectedEntryIndex = selectedIndex
        canvas.onEntrySelected = { idx in
            selectedIndex = idx
        }
        canvas.onEntryMoved = { idx, x, y in
            entries[idx].x = x
            entries[idx].y = y
        }
        canvas.onBeginEdit = onBeginEdit
        return canvas
    }

    func updateNSView(_ canvas: SpriteCanvas, context: Context) {
        canvas.entries = entries
        canvas.tiles = tiles
        canvas.palettes = palettes
        canvas.showGrid = showGrid
        canvas.zoom = zoom
        canvas.selectedEntryIndex = selectedIndex
        canvas.onEntrySelected = { idx in
            selectedIndex = idx
        }
        canvas.onEntryMoved = { idx, x, y in
            entries[idx].x = x
            entries[idx].y = y
        }
        canvas.onBeginEdit = onBeginEdit
    }
}

// MARK: - Container

struct SpriteEditorContainerView: View {
    @Bindable var state: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var entries: [OAMEntry] = []
    @State private var tiles: [SNESTile] = [.empty()]
    @State private var palettes: [SNESPalette] = SNESPalette.defaultPalettes()
    @State private var showGrid: Bool = false
    @State private var zoom: CGFloat = 2.0
    @State private var selectedIndex: Int? = nil
    @State private var metaSprites: [MetaSprite] = []
    @State private var selectedSpriteIndex: Int = 0
    @State private var selectedAnimIndex: Int = 0
    @State private var undoMgr = EditorUndoManager<[OAMEntry]>()
    @State private var showImportSheet = false
    @State private var editingSpriteNameIndex: Int? = nil

    /// Current MetaSprite's animations (convenience)
    private var currentAnimations: [SpriteAnimation] {
        guard selectedSpriteIndex < metaSprites.count else { return [] }
        return metaSprites[selectedSpriteIndex].animations
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: MetaSprite sidebar
            metaSpriteSidebar
                .frame(width: 150)

            SNESTheme.border.frame(width: 1)

            // Center: Sprite canvas + timeline
            VStack(spacing: 0) {
                spriteToolbar

                ScrollView([.horizontal, .vertical]) {
                    SpriteEditorNSView(
                        entries: $entries,
                        tiles: tiles,
                        palettes: palettes,
                        showGrid: showGrid,
                        zoom: zoom,
                        selectedIndex: $selectedIndex,
                        onBeginEdit: {
                            undoMgr.recordState(entries)
                        }
                    )
                    .frame(width: 256 * zoom, height: 224 * zoom)
                }
                .background(SNESTheme.bgEditor)

                // Animation timeline
                if !currentAnimations.isEmpty,
                   selectedSpriteIndex < metaSprites.count {
                    AnimationTimelineView(
                        animations: $metaSprites[selectedSpriteIndex].animations,
                        selectedIndex: $selectedAnimIndex,
                        tiles: tiles,
                        palettes: palettes,
                        onFrameSelected: { frameIdx in
                            let anims = currentAnimations
                            guard selectedAnimIndex < anims.count,
                                  frameIdx < anims[selectedAnimIndex].frames.count else { return }
                            entries = anims[selectedAnimIndex].frames[frameIdx].entries
                        },
                        onAnimationChanged: { animIdx in
                            let anims = currentAnimations
                            guard animIdx < anims.count,
                                  let firstFrame = anims[animIdx].frames.first else { return }
                            entries = firstFrame.entries
                        }
                    )
                    .frame(height: 90)
                }
            }

            // Right: Sprite list
            SpriteListView(
                entries: $entries,
                selectedIndex: $selectedIndex
            )
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
        }
        .background(SNESTheme.bgEditor)
        .sheet(isPresented: $showImportSheet) {
            SpriteSheetImportView(state: state)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorUndo)) { _ in
            if let prev = undoMgr.undo(current: entries) { entries = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorRedo)) { _ in
            if let next = undoMgr.redo(current: entries) { entries = next }
        }
        .onChange(of: entries) {
            state.assetStore.spriteEntries = entries
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil, userInfo: ["debounce": true])
        }
        .onChange(of: metaSprites) {
            state.assetStore.metaSprites = metaSprites
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil, userInfo: ["debounce": true])
        }
        .onAppear {
            entries = state.assetStore.spriteEntries
            metaSprites = state.assetStore.metaSprites
            tiles = state.assetStore.tiles
            palettes = state.assetStore.palettes
        }
        .onDisappear {
            state.assetStore.spriteEntries = entries
            state.assetStore.metaSprites = metaSprites
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .assetStoreDidChange)) { notification in
            entries = state.assetStore.spriteEntries
            metaSprites = state.assetStore.metaSprites
            tiles = state.assetStore.tiles
            palettes = state.assetStore.palettes
            // Auto-select newly imported sprite/animation
            if let si = notification.userInfo?["selectSpriteIndex"] as? Int,
               si < metaSprites.count {
                selectedSpriteIndex = si
            }
            if let ai = notification.userInfo?["selectAnimIndex"] as? Int,
               selectedSpriteIndex < metaSprites.count,
               ai < metaSprites[selectedSpriteIndex].animations.count {
                selectedAnimIndex = ai
            }
        }
    }

    // MARK: - MetaSprite Sidebar

    private var metaSpriteSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SPRITES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
                Button {
                    let newSprite = MetaSprite(name: "Sprite \(metaSprites.count + 1)", animations: [
                        SpriteAnimation(name: "IDLE", frames: [SpriteFrame()])
                    ])
                    metaSprites.append(newSprite)
                    selectedSpriteIndex = metaSprites.count - 1
                    selectedAnimIndex = 0
                    loadCurrentAnimation()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Add sprite")

                Button {
                    guard !metaSprites.isEmpty, selectedSpriteIndex < metaSprites.count else { return }
                    metaSprites.remove(at: selectedSpriteIndex)
                    if metaSprites.isEmpty {
                        entries = []
                        selectedSpriteIndex = 0
                        selectedAnimIndex = 0
                    } else {
                        selectedSpriteIndex = min(selectedSpriteIndex, metaSprites.count - 1)
                        selectedAnimIndex = 0
                        loadCurrentAnimation()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(metaSprites.isEmpty)
                .help("Remove sprite")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            SNESTheme.border.frame(height: 1)

            // MetaSprite list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(metaSprites.indices, id: \.self) { spriteIdx in
                        metaSpriteRow(spriteIdx)
                    }
                }
                .padding(6)
            }
        }
        .background(SNESTheme.bgPanel)
    }

    private func metaSpriteRow(_ spriteIdx: Int) -> some View {
        let isSpriteSelected = spriteIdx == selectedSpriteIndex
        let sprite = metaSprites[spriteIdx]

        return VStack(spacing: 0) {
            // Sprite header: thumbnail + name
            HStack(spacing: 6) {
                // Thumbnail: first frame of first animation
                Canvas { ctx, size in
                    drawThumbnailCheckerboard(ctx: ctx, size: size)
                    if let firstAnim = sprite.animations.first,
                       let firstFrame = firstAnim.frames.first {
                        drawFrameThumbnail(ctx: ctx, size: size, frame: firstFrame)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSpriteSelected ? SNESTheme.info : SNESTheme.border, lineWidth: 1)
                )

                // Editable sprite name
                if editingSpriteNameIndex == spriteIdx {
                    TextField("", text: $metaSprites[spriteIdx].name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SNESTheme.textPrimary)
                        .onSubmit { editingSpriteNameIndex = nil }
                } else {
                    Text(sprite.name)
                        .font(.system(size: 10, weight: isSpriteSelected ? .semibold : .medium))
                        .foregroundStyle(isSpriteSelected ? SNESTheme.textPrimary : SNESTheme.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editingSpriteNameIndex = spriteIdx
                        }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSpriteSelected ? SNESTheme.info.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectSprite(spriteIdx)
            }
            .contextMenu {
                Button("Rename") {
                    editingSpriteNameIndex = spriteIdx
                }

                Divider()

                Button("Duplicate") {
                    duplicateSprite(at: spriteIdx)
                }

                Divider()

                Button("Delete", role: .destructive) {
                    deleteSprite(at: spriteIdx)
                }
                .disabled(metaSprites.count <= 1)
            }
        }
    }

    // MARK: - Sprite Actions

    private func duplicateSprite(at index: Int) {
        guard index < metaSprites.count else { return }
        var copy = metaSprites[index]
        copy.id = UUID()
        copy.name = metaSprites[index].name + " Copy"
        metaSprites.insert(copy, at: index + 1)
        selectSprite(index + 1)
    }

    private func deleteSprite(at index: Int) {
        guard metaSprites.count > 1, index < metaSprites.count else { return }
        metaSprites.remove(at: index)
        if metaSprites.isEmpty {
            entries = []
            selectedSpriteIndex = 0
            selectedAnimIndex = 0
        } else {
            selectedSpriteIndex = min(index, metaSprites.count - 1)
            selectedAnimIndex = 0
            loadCurrentAnimation()
        }
    }

    // MARK: - Selection helpers

    private func selectSprite(_ idx: Int) {
        selectedSpriteIndex = idx
        selectedAnimIndex = 0
        editingSpriteNameIndex = nil
        loadCurrentAnimation()
    }

    private func loadCurrentAnimation() {
        guard selectedSpriteIndex < metaSprites.count else {
            entries = []
            return
        }
        let anims = metaSprites[selectedSpriteIndex].animations
        guard selectedAnimIndex < anims.count,
              let firstFrame = anims[selectedAnimIndex].frames.first else {
            entries = []
            return
        }
        entries = firstFrame.entries
    }

    // MARK: - Thumbnail Drawing

    private func drawThumbnailCheckerboard(ctx: GraphicsContext, size: CGSize) {
        let cs: CGFloat = 4
        for row in 0..<Int(size.height / cs) + 1 {
            for col in 0..<Int(size.width / cs) + 1 {
                let light = (row + col) % 2 == 0
                ctx.fill(Path(CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs, width: cs, height: cs)),
                         with: .color(light ? Color(white: 0.15) : Color(white: 0.11)))
            }
        }
    }

    private func drawFrameThumbnail(ctx: GraphicsContext, size: CGSize, frame: SpriteFrame) {
        guard !frame.entries.isEmpty else { return }

        // Compute bounding box
        var minX = Int.max, minY = Int.max
        var maxX = Int.min, maxY = Int.min
        for entry in frame.entries {
            let s = entry.size.pixelSize
            minX = min(minX, entry.x)
            minY = min(minY, entry.y)
            maxX = max(maxX, entry.x + s)
            maxY = max(maxY, entry.y + s)
        }
        let bboxW = CGFloat(max(maxX - minX, 1))
        let bboxH = CGFloat(max(maxY - minY, 1))
        let fitScale = min(size.width / bboxW, size.height / bboxH) * 0.85
        let offX = (size.width - bboxW * fitScale) / 2 - CGFloat(minX) * fitScale
        let offY = (size.height - bboxH * fitScale) / 2 - CGFloat(minY) * fitScale

        for entry in frame.entries {
            guard entry.tileIndex < tiles.count else { continue }
            let tile = tiles[entry.tileIndex]
            let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]
            let px = CGFloat(entry.x) * fitScale + offX
            let py = CGFloat(entry.y) * fitScale + offY

            for ty in 0..<8 {
                for tx in 0..<8 {
                    let srcX = entry.flipH ? (7 - tx) : tx
                    let srcY = entry.flipV ? (7 - ty) : ty
                    let colorIdx = Int(tile.pixel(x: srcX, y: srcY))
                    if colorIdx == 0 { continue }
                    let snesColor = pal[colorIdx]
                    let rect = CGRect(
                        x: px + CGFloat(tx) * fitScale,
                        y: py + CGFloat(ty) * fitScale,
                        width: max(fitScale, 1),
                        height: max(fitScale, 1)
                    )
                    ctx.fill(Path(rect), with: .color(snesColor.color))
                }
            }
        }
    }

    // MARK: - Toolbar

    private var spriteToolbar: some View {
        HStack(spacing: 8) {
            Toggle("Grid", isOn: $showGrid)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textSecondary)

            Divider().frame(height: 16)

            Text("\(entries.count)/128 sprites")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(entries.count > 128 ? SNESTheme.danger : SNESTheme.textDisabled)

            Divider().frame(height: 16)

            Button {
                zoom = max(1, zoom - 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SNESTheme.textSecondary)
            .disabled(zoom <= 1)

            Text("\(Int(zoom))x")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 24)

            Button {
                zoom = min(6, zoom + 1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SNESTheme.textSecondary)
            .disabled(zoom >= 6)

            Spacer()

            Button {
                openSpriteDrawing()
            } label: {
                Label("Draw", systemImage: "paintbrush.pointed")
                    .font(.system(size: 11))
            }
            .help("Open pixel art drawing studio")

            Divider().frame(height: 16)

            Button {
                showImportSheet = true
            } label: {
                Label("Import Sheet...", systemImage: "square.and.arrow.down")
                    .font(.system(size: 11))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Sprite Drawing Studio

    private func openSpriteDrawing() {
        let session = state.spriteDrawingSession

        // Configure session from current MetaSprite context
        session.metaSpriteIndex = selectedSpriteIndex
        session.animationIndex = selectedAnimIndex
        session.tileDepth = .bpp4

        // Auto-detect palette from entries
        let detectedPalette: Int
        if selectedSpriteIndex < metaSprites.count,
           selectedAnimIndex < metaSprites[selectedSpriteIndex].animations.count,
           let firstFrame = metaSprites[selectedSpriteIndex].animations[selectedAnimIndex].frames.first,
           let firstEntry = firstFrame.entries.first {
            detectedPalette = firstEntry.paletteIndex
        } else if let firstEntry = entries.first {
            detectedPalette = firstEntry.paletteIndex
        } else {
            detectedPalette = 0
        }
        session.paletteIndex = detectedPalette

        // Load the full animation if we have one
        if selectedSpriteIndex < metaSprites.count,
           selectedAnimIndex < metaSprites[selectedSpriteIndex].animations.count {
            let anim = metaSprites[selectedSpriteIndex].animations[selectedAnimIndex]
            if !anim.frames.isEmpty {
                session.loadAnimation(animation: anim, tiles: tiles)
            } else {
                session.initCanvas(width: 32, height: 32)
            }
        } else if !entries.isEmpty {
            session.populateFromEntries(entries: entries, tiles: tiles)
        } else {
            session.initCanvas(width: 32, height: 32)
        }

        // Generate BG snapshot from tilemaps
        session.bgSnapshot = BGSnapshotRenderer.render(
            tilemaps: state.assetStore.tilemaps,
            tiles: tiles,
            palettes: palettes
        )

        // Save callback: inject decomposed tiles + OAM entries for ALL frames
        session.onSaveAllFrames = { [self] newTiles, newFrames in
            // Update tiles in asset store
            state.assetStore.tiles = newTiles
            tiles = newTiles

            // Update entries from first frame for the canvas preview
            if let firstFrame = newFrames.first {
                undoMgr.recordState(entries)
                entries = firstFrame.entries
            }

            // Replace the entire animation's frames
            if selectedSpriteIndex < metaSprites.count,
               selectedAnimIndex < metaSprites[selectedSpriteIndex].animations.count {
                metaSprites[selectedSpriteIndex].animations[selectedAnimIndex].frames = newFrames
            }

            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }

        session.onCancel = {
            // Nothing to do
        }

        session.isActive = true
        openWindow(id: "sprite-drawing")
    }
}
