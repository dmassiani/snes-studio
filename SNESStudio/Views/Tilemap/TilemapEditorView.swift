import SwiftUI

struct TilemapEditorNSView: NSViewRepresentable {
    @Binding var tilemap: SNESTilemap
    var tiles: [SNESTile]
    var palettes: [SNESPalette]
    var showGrid: Bool
    var zoom: CGFloat
    var selectedTileIndex: Int
    var selectedPaletteIndex: Int
    var currentTool: TilemapTool
    var onCellSelected: ((Int, Int) -> Void)?
    var onBeginEdit: (() -> Void)?
    var onTilePicked: ((Int, Int) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.backgroundColor = NSColor(SNESTheme.bgEditor)

        let canvas = TilemapCanvas()
        configureCanvas(canvas)
        canvas.onEntryChanged = { x, y, entry in
            tilemap.setEntry(x: x, y: y, entry: entry)
        }
        canvas.frame.size = canvas.intrinsicContentSize
        scrollView.documentView = canvas

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let canvas = scrollView.documentView as? TilemapCanvas else { return }
        configureCanvas(canvas)
        canvas.onEntryChanged = { x, y, entry in
            tilemap.setEntry(x: x, y: y, entry: entry)
        }
        canvas.frame.size = canvas.intrinsicContentSize
    }

    private func configureCanvas(_ canvas: TilemapCanvas) {
        canvas.tilemap = tilemap
        canvas.tiles = tiles
        canvas.palettes = palettes
        canvas.showGrid = showGrid
        canvas.zoom = zoom
        canvas.selectedTileIndex = selectedTileIndex
        canvas.selectedPaletteIndex = selectedPaletteIndex
        canvas.currentTool = currentTool
        canvas.onCellSelected = onCellSelected
        canvas.onBeginEdit = onBeginEdit
        canvas.onTilePicked = onTilePicked
    }
}

// MARK: - Container

struct TilemapEditorContainerView: View {
    @Bindable var state: AppState

    @State private var tilemaps: [SNESTilemap] = [.empty()]
    @State private var selectedTilemapIndex: Int = 0
    @State private var tiles: [SNESTile] = [.empty()]
    @State private var palettes: [SNESPalette] = SNESPalette.defaultPalettes()
    @State private var showGrid: Bool = true
    @State private var zoom: CGFloat = 2
    @State private var selectedTileIndex: Int = 0
    @State private var selectedPaletteIndex: Int = 0
    @State private var selectedCellX: Int = 0
    @State private var selectedCellY: Int = 0
    @State private var currentTool: TilemapTool = .stamp
    @State private var undoMgr = EditorUndoManager<[SNESTilemap]>()
    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""

    private var safeIndex: Int {
        min(selectedTilemapIndex, max(tilemaps.count - 1, 0))
    }

    private var currentTilemap: Binding<SNESTilemap> {
        Binding(
            get: { tilemaps[safeIndex] },
            set: { tilemaps[safeIndex] = $0 }
        )
    }

    var body: some View {
        HSplitView {
            // LEFT: Tilemap list + Tile picker
            VStack(spacing: 0) {
                tilemapList
                tilePicker
            }
            .frame(minWidth: 160, idealWidth: 190, maxWidth: 240)

            // CENTER: Toolbar + Canvas + Bottom bar
            VStack(spacing: 0) {
                tilemapToolbar

                TilemapEditorNSView(
                    tilemap: currentTilemap,
                    tiles: tiles,
                    palettes: palettes,
                    showGrid: showGrid,
                    zoom: zoom,
                    selectedTileIndex: selectedTileIndex,
                    selectedPaletteIndex: selectedPaletteIndex,
                    currentTool: currentTool,
                    onCellSelected: { x, y in
                        selectedCellX = x
                        selectedCellY = y
                    },
                    onBeginEdit: {
                        undoMgr.recordState(tilemaps)
                    },
                    onTilePicked: { tileIdx, palIdx in
                        selectedTileIndex = tileIdx
                        selectedPaletteIndex = palIdx
                        currentTool = .stamp
                    }
                )

                tilemapBottomBar
            }

            // RIGHT: Properties panel
            TilemapPropertiesView(
                tilemap: currentTilemap,
                cellX: selectedCellX,
                cellY: selectedCellY,
                tiles: tiles,
                palettes: palettes
            )
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
        }
        .background(SNESTheme.bgEditor)
        .onReceive(NotificationCenter.default.publisher(for: .editorUndo)) { _ in
            if let prev = undoMgr.undo(current: tilemaps) { tilemaps = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorRedo)) { _ in
            if let next = undoMgr.redo(current: tilemaps) { tilemaps = next }
        }
        .onChange(of: tilemaps) {
            state.assetStore.tilemaps = tilemaps
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil, userInfo: ["debounce": true])
        }
        .onAppear {
            syncFromStore()
        }
        .onDisappear {
            state.assetStore.tilemaps = tilemaps
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .assetStoreDidChange)) { _ in
            syncFromStore()
        }
    }

    private func syncFromStore() {
        let stored = state.assetStore.tilemaps
        tilemaps = stored.isEmpty ? [.empty()] : stored
        tiles = state.assetStore.tiles
        palettes = state.assetStore.palettes
        if selectedTilemapIndex >= tilemaps.count {
            selectedTilemapIndex = max(tilemaps.count - 1, 0)
        }
    }

    // MARK: - Tilemap List (top-left)

    private var tilemapList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TILEMAPS (\(tilemaps.count))")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()

                Button { addTilemap() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("New tilemap")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }

            // List
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(tilemaps.indices, id: \.self) { idx in
                        tilemapRow(index: idx)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 140)
            .background(SNESTheme.bgEditor)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }
        }
    }

    private func tilemapRow(index: Int) -> some View {
        let tm = tilemaps[index]
        let isSelected = index == safeIndex

        return HStack(spacing: 6) {
            Image(systemName: "map")
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? SNESTheme.info : SNESTheme.textDisabled)
                .frame(width: 14)

            if isRenaming && isSelected {
                TextField("Name", text: $renameText, onCommit: {
                    tilemaps[index].name = renameText
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textPrimary)
            } else {
                Text(tm.name)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? SNESTheme.textPrimary : SNESTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(tm.width)\u{00D7}\(tm.height)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)

            if isSelected && tilemaps.count > 1 {
                Button { deleteTilemap(at: index) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(SNESTheme.danger.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSelected ? SNESTheme.info.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTilemapIndex = index
        }
        .onTapGesture(count: 2) {
            renameText = tilemaps[index].name
            isRenaming = true
        }
    }

    // MARK: - Actions

    private func addTilemap() {
        undoMgr.recordState(tilemaps)
        let newTilemap = SNESTilemap(name: "Tilemap \(tilemaps.count)", width: 32, height: 32)
        tilemaps.append(newTilemap)
        selectedTilemapIndex = tilemaps.count - 1
    }

    private func deleteTilemap(at index: Int) {
        guard tilemaps.count > 1 else { return }
        undoMgr.recordState(tilemaps)
        tilemaps.remove(at: index)
        if selectedTilemapIndex >= tilemaps.count {
            selectedTilemapIndex = tilemaps.count - 1
        }
    }

    // MARK: - Tile Picker (bottom-left)

    private var tilePicker: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TILES (\(tiles.count))")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem](repeating: GridItem(.fixed(24), spacing: 2), count: 6),
                    spacing: 2
                ) {
                    ForEach(tiles.indices, id: \.self) { idx in
                        Button {
                            selectedTileIndex = idx
                            if currentTool == .eyedropper { currentTool = .stamp }
                        } label: {
                            TileMiniPreview(
                                tile: tiles[idx],
                                palette: palettes.first ?? SNESPalette.defaultPalettes()[0],
                                size: 24
                            )
                            .border(
                                idx == selectedTileIndex ? SNESTheme.info : SNESTheme.border,
                                width: idx == selectedTileIndex ? 2 : 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
            }
            .background(SNESTheme.bgEditor)
        }
    }

    // MARK: - Toolbar (top — tools only)

    private var tilemapToolbar: some View {
        HStack(spacing: 8) {
            toolButton("pencil.tip", tool: .stamp, tooltip: "Stamp (S)")
            toolButton("eraser", tool: .eraser, tooltip: "Eraser (E)")
            toolButton("drop.fill", tool: .fill, tooltip: "Fill (F)")
            toolButton("eyedropper", tool: .eyedropper, tooltip: "Eyedropper (I)")

            Spacer()

            let tm = tilemaps[safeIndex]
            Text(tm.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SNESTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Bottom bar (zoom, grid, info)

    private var tilemapBottomBar: some View {
        HStack(spacing: 10) {
            // Grid toggle
            Button {
                showGrid.toggle()
            } label: {
                Image(systemName: showGrid ? "grid" : "grid.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(showGrid ? SNESTheme.info : SNESTheme.textDisabled)
            }
            .buttonStyle(.plain)
            .help(showGrid ? "Hide grid" : "Show grid")

            SNESTheme.border.frame(width: 1, height: 12)

            // Zoom
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

            // Cell info
            Text("(\(selectedCellX), \(selectedCellY))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)

            Spacer()

            // Tilemap size
            let tm = tilemaps[safeIndex]
            Text("\(tm.width)\u{00D7}\(tm.height)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
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
