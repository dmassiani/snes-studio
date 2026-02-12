import SwiftUI

// MARK: - NSViewRepresentable wrapper

struct LevelEditorNSView: NSViewRepresentable {
    @Binding var level: SNESLevel
    var tiles: [SNESTile]
    var palettes: [SNESPalette]
    var activeLayerIndex: Int
    var showGrid: Bool
    var zoom: CGFloat
    var cameraX: CGFloat
    var stampTilemap: SNESTilemap?
    var currentTool: TilemapTool
    var onCellSelected: ((Int, Int) -> Void)?
    var onBeginEdit: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.backgroundColor = NSColor(SNESTheme.bgEditor)

        let canvas = LevelCanvas()
        configureCanvas(canvas)
        canvas.onLevelChanged = { newLevel in level = newLevel }
        canvas.frame.size = canvas.intrinsicContentSize
        scrollView.documentView = canvas

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let canvas = scrollView.documentView as? LevelCanvas else { return }
        configureCanvas(canvas)
        canvas.onLevelChanged = { newLevel in level = newLevel }
        canvas.frame.size = canvas.intrinsicContentSize
    }

    private func configureCanvas(_ canvas: LevelCanvas) {
        canvas.level = level
        canvas.tiles = tiles
        canvas.palettes = palettes
        canvas.activeLayerIndex = activeLayerIndex
        canvas.showGrid = showGrid
        canvas.zoom = zoom
        canvas.cameraX = cameraX
        canvas.stampTilemap = stampTilemap
        canvas.currentTool = currentTool
        canvas.onCellSelected = onCellSelected
        canvas.onBeginEdit = onBeginEdit
    }
}

// MARK: - Container (screen-based, 2-column layout)

struct LevelEditorContainerView: View {
    @Bindable var state: AppState
    var screenID: UUID

    @State private var level: SNESLevel = .create(name: "Empty", bgMode: 1, widthTiles: 32, heightTiles: 28)
    @State private var tiles: [SNESTile] = [.empty()]
    @State private var palettes: [SNESPalette] = SNESPalette.defaultPalettes()
    @State private var tilemaps: [SNESTilemap] = [.empty()]
    @State private var activeLayerIndex: Int = 0
    @State private var showGrid: Bool = true
    @State private var zoom: CGFloat = 2
    @State private var cameraX: CGFloat = 0
    @State private var selectedTilemapIndex: Int = 0
    @State private var selectedCellX: Int = 0
    @State private var selectedCellY: Int = 0
    @State private var currentTool: TilemapTool = .stamp
    @State private var undoMgr = EditorUndoManager<SNESLevel>()
    @State private var showPreviewPopover: Bool = false

    private var selectedTilemap: SNESTilemap? {
        guard selectedTilemapIndex >= 0, selectedTilemapIndex < tilemaps.count else { return nil }
        return tilemaps[selectedTilemapIndex]
    }

    var body: some View {
        HSplitView {
            // LEFT: Toolbar + Canvas + Bottom bar
            VStack(spacing: 0) {
                levelToolbar

                LevelEditorNSView(
                    level: $level,
                    tiles: tiles,
                    palettes: palettes,
                    activeLayerIndex: activeLayerIndex,
                    showGrid: showGrid,
                    zoom: zoom,
                    cameraX: cameraX,
                    stampTilemap: currentTool == .stamp ? selectedTilemap : nil,
                    currentTool: currentTool,
                    onCellSelected: { x, y in
                        selectedCellX = x
                        selectedCellY = y
                    },
                    onBeginEdit: {
                        undoMgr.recordState(level)
                    }
                )

                levelBottomBar
            }

            // RIGHT: Tilemaps + Parallax
            rightPanel
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
        }
        .background(SNESTheme.bgEditor)
        .onReceive(NotificationCenter.default.publisher(for: .editorUndo)) { _ in
            if let prev = undoMgr.undo(current: level) { level = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorRedo)) { _ in
            if let next = undoMgr.redo(current: level) { level = next }
        }
        .onChange(of: level) {
            syncToStore()
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil, userInfo: ["debounce": true])
        }
        .onAppear {
            syncFromStore()
        }
        .onDisappear {
            syncToStore()
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
    }

    // MARK: - Sync from/to WorldScreen

    private func syncFromStore() {
        guard let screenIdx = state.assetStore.worldScreens.firstIndex(where: { $0.id == screenID }),
              let zone = state.assetStore.worldZones.first(where: { $0.id == state.assetStore.worldScreens[screenIdx].zoneID })
        else { return }

        let screen = state.assetStore.worldScreens[screenIdx]
        level = SNESLevel.fromScreen(screen, zone: zone)

        tiles = state.assetStore.tiles
        palettes = state.assetStore.palettes
        tilemaps = state.assetStore.tilemaps.isEmpty ? [.empty()] : state.assetStore.tilemaps
        if activeLayerIndex >= level.layers.count {
            activeLayerIndex = max(level.layers.count - 1, 0)
        }
        if selectedTilemapIndex >= tilemaps.count {
            selectedTilemapIndex = 0
        }
    }

    private func syncToStore() {
        guard let screenIdx = state.assetStore.worldScreens.firstIndex(where: { $0.id == screenID }) else { return }
        state.assetStore.worldScreens[screenIdx].layers = level.layers
    }

    // MARK: - Right Panel (Tilemaps + Parallax)

    private var rightPanel: some View {
        VStack(spacing: 0) {
            // Layer size header
            layerSizeHeader

            // Tilemaps section (scrollable, takes remaining space)
            sectionHeader("TILEMAPS (\(tilemaps.count))")

            if tilemaps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 24))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Text("Aucune tilemap")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Text("Creez des tilemaps dans\nl'editeur Tilemaps")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SNESTheme.bgEditor)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(tilemaps.indices, id: \.self) { idx in
                            tilemapCard(index: idx)
                        }
                    }
                    .padding(8)
                }
                .background(SNESTheme.bgEditor)
            }

            // Parallax section (fixed at bottom)
            sectionHeader("PARALLAXE")
            parallaxSection
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    private var layerSizeHeader: some View {
        HStack(spacing: 6) {
            if activeLayerIndex < level.layers.count {
                Text("Taille")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Stepper("\(level.layers[activeLayerIndex].tilemap.width)",
                        onIncrement: { resizeLayer(dw: 32, dh: 0) },
                        onDecrement: { resizeLayer(dw: -32, dh: 0) })
                    .font(.system(size: 10, design: .monospaced))
                Text("\u{00D7}")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
                Stepper("\(level.layers[activeLayerIndex].tilemap.height)",
                        onIncrement: { resizeLayer(dw: 0, dh: 4) },
                        onDecrement: { resizeLayer(dw: 0, dh: -4) })
                    .font(.system(size: 10, design: .monospaced))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    private var parallaxSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if activeLayerIndex < level.layers.count {
                let layerBinding = Binding(
                    get: { level.layers[activeLayerIndex] },
                    set: { level.layers[activeLayerIndex] = $0 }
                )

                // Scroll ratios
                HStack {
                    Text("Scroll X")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .frame(width: 46, alignment: .leading)
                    Slider(value: layerBinding.scrollRatioX, in: 0.0...1.0, step: 0.05)
                    Text("\(layerBinding.scrollRatioX.wrappedValue, specifier: "%.2f")")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .frame(width: 30)
                }

                HStack {
                    Text("Scroll Y")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .frame(width: 46, alignment: .leading)
                    Slider(value: layerBinding.scrollRatioY, in: 0.0...1.0, step: 0.05)
                    Text("\(layerBinding.scrollRatioY.wrappedValue, specifier: "%.2f")")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .frame(width: 30)
                }

                // Repeat toggles
                HStack(spacing: 12) {
                    Toggle("Repeat X", isOn: layerBinding.repeatX)
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Toggle("Repeat Y", isOn: layerBinding.repeatY)
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
            } else {
                Text("Aucune couche")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SNESTheme.bgEditor)
    }

    private func resizeLayer(dw: Int, dh: Int) {
        guard activeLayerIndex < level.layers.count else { return }
        let tm = level.layers[activeLayerIndex].tilemap
        let newW = max(32, tm.width + dw)
        let newH = max(4, tm.height + dh)
        undoMgr.recordState(level)
        level.layers[activeLayerIndex].tilemap.resize(newWidth: newW, newHeight: newH)
    }

    private func tilemapCard(index: Int) -> some View {
        let tm = tilemaps[index]
        let isSelected = index == selectedTilemapIndex

        return Button {
            selectedTilemapIndex = index
            if currentTool != .stamp { currentTool = .stamp }
        } label: {
            VStack(spacing: 4) {
                tilemapMiniPreview(tm)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                HStack {
                    Text(tm.name)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? SNESTheme.textPrimary : SNESTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(tm.width)\u{00D7}\(tm.height)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? SNESTheme.info.opacity(0.12) : SNESTheme.bgPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? SNESTheme.info : SNESTheme.border, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func tilemapMiniPreview(_ tm: SNESTilemap) -> some View {
        Group {
            if let img = renderTilemapPreview(tm) {
                Image(img, scale: 1, label: Text(""))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(SNESTheme.bgMain)
            }
        }
    }

    private func renderTilemapPreview(_ tm: SNESTilemap) -> CGImage? {
        let w = tm.width
        let h = tm.height
        guard w > 0, h > 0 else { return nil }
        var pixelData = [UInt8](repeating: 0, count: w * h * 4)

        for cy in 0..<h {
            for cx in 0..<w {
                let entry = tm.entry(x: cx, y: cy)
                let offset = (cy * w + cx) * 4
                if entry.tileIndex > 0, entry.tileIndex < tiles.count {
                    let tile = tiles[entry.tileIndex]
                    let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]
                    let colorIdx = Int(tile.pixel(x: 3, y: 3))
                    let c = pal[colorIdx]
                    pixelData[offset]     = UInt8(c.red * 255 / 31)
                    pixelData[offset + 1] = UInt8(c.green * 255 / 31)
                    pixelData[offset + 2] = UInt8(c.blue * 255 / 31)
                    pixelData[offset + 3] = 255
                } else {
                    pixelData[offset + 3] = 0
                }
            }
        }

        return pixelData.withUnsafeMutableBytes { ptr -> CGImage? in
            guard let base = ptr.baseAddress else { return nil }
            guard let ctx = CGContext(
                data: base,
                width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
    }

    // MARK: - Toolbar (top)

    private var levelToolbar: some View {
        HStack(spacing: 8) {
            // Tools
            toolButton("square.grid.2x2", tool: .stamp, tooltip: "Placer tilemap")
            toolButton("eraser", tool: .eraser, tooltip: "Effacer bloc")

            Divider().frame(height: 16)

            // Screen name
            if let screenIdx = state.assetStore.worldScreens.firstIndex(where: { $0.id == screenID }) {
                TextField("Nom", text: Binding(
                    get: { state.assetStore.worldScreens[screenIdx].name },
                    set: { newName in
                        state.assetStore.worldScreens[screenIdx].name = newName
                        if let tabIdx = state.tabManager.tabs.firstIndex(where: { $0.id == "screen_\(screenID.uuidString)" }) {
                            state.tabManager.tabs[tabIdx] = EditorTab(
                                id: state.tabManager.tabs[tabIdx].id,
                                title: newName,
                                icon: state.tabManager.tabs[tabIdx].icon,
                                level: state.tabManager.tabs[tabIdx].level
                            )
                        }
                        NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 140)
            }

            Divider().frame(height: 16)

            // Layer dropdown
            Picker("", selection: $activeLayerIndex) {
                ForEach(level.layers.indices, id: \.self) { idx in
                    Text(level.layers[idx].name).tag(idx)
                }
            }
            .frame(width: 180)

            // Visibility toggle for active layer
            if activeLayerIndex < level.layers.count {
                Button {
                    level.layers[activeLayerIndex].visible.toggle()
                } label: {
                    Image(systemName: level.layers[activeLayerIndex].visible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(level.layers[activeLayerIndex].visible ? SNESTheme.textSecondary : SNESTheme.textDisabled)
                }
                .buttonStyle(.plain)
                .help(level.layers[activeLayerIndex].visible ? "Masquer la couche" : "Afficher la couche")
            }

            Spacer()

            // Preview popover
            Button {
                showPreviewPopover.toggle()
            } label: {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 11))
                    .foregroundStyle(showPreviewPopover ? SNESTheme.info : SNESTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Preview parallaxe")
            .popover(isPresented: $showPreviewPopover, arrowEdge: .bottom) {
                ParallaxPreviewView(
                    level: level,
                    tiles: tiles,
                    palettes: palettes
                )
                .frame(width: 280, height: 200)
                .padding(8)
            }

            Divider().frame(height: 16)

            // Mode info
            if let screenIdx = state.assetStore.worldScreens.firstIndex(where: { $0.id == screenID }),
               let zone = state.assetStore.worldZones.first(where: { $0.id == state.assetStore.worldScreens[screenIdx].zoneID }) {
                Text("Mode \(zone.bgMode)")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Bottom bar (zoom, grid, info)

    private var levelBottomBar: some View {
        HStack(spacing: 10) {
            Button {
                showGrid.toggle()
            } label: {
                Image(systemName: showGrid ? "grid" : "grid.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(showGrid ? SNESTheme.info : SNESTheme.textDisabled)
            }
            .buttonStyle(.plain)
            .help(showGrid ? "Masquer grille" : "Afficher grille")

            SNESTheme.border.frame(width: 1, height: 12)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(SNESTheme.textDisabled)
            Picker("", selection: $zoom) {
                Text("1x").tag(CGFloat(1))
                Text("2x").tag(CGFloat(2))
                Text("3x").tag(CGFloat(3))
                Text("4x").tag(CGFloat(4))
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            SNESTheme.border.frame(width: 1, height: 12)

            Text("(\(selectedCellX), \(selectedCellY))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)

            Spacer()

            if activeLayerIndex < level.layers.count {
                let tm = level.layers[activeLayerIndex].tilemap
                Text("\(tm.width)\u{00D7}\(tm.height)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .top) {
            SNESTheme.border.frame(height: 1)
        }
    }

    private func toolButton(_ icon: String, tool: TilemapTool, tooltip: String) -> some View {
        Button {
            currentTool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
                .background(
                    currentTool == tool
                        ? SNESTheme.info.opacity(0.25)
                        : Color.clear
                )
                .foregroundStyle(
                    currentTool == tool
                        ? SNESTheme.info
                        : SNESTheme.textSecondary
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
