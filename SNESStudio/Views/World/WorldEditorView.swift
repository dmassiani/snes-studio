import SwiftUI

struct WorldEditorView: View {
    @Bindable var state: AppState
    @State private var selectedZoneID: UUID?
    @State private var selectedScreenID: UUID?
    @State private var zoom: CGFloat = 1.0
    @State private var undoManager = EditorUndoManager<[WorldScreen]>()

    private var selectedZone: WorldZone? {
        state.assetStore.worldZones.first { $0.id == selectedZoneID }
    }

    private var selectedScreenIndex: Int? {
        state.assetStore.worldScreens.firstIndex { $0.id == selectedScreenID }
    }

    var body: some View {
        HSplitView {
            // Zone list
            ZoneListView(zones: $state.assetStore.worldZones, selectedZoneID: $selectedZoneID)
                .frame(width: 200)

            // Center: toolbar + grid
            VStack(spacing: 0) {
                worldToolbar
                Divider()

                if let zone = selectedZone {
                    WorldGridCanvas(
                        zone: zone,
                        screens: state.assetStore.worldScreens.filter { $0.zoneID == zone.id },
                        selectedScreenID: selectedScreenID,
                        zoom: zoom,
                        onSelectScreen: { id in
                            selectedScreenID = id
                        },
                        onDoubleClickScreen: { id in
                            openScreenEditor(screenID: id)
                        }
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 32))
                            .foregroundStyle(SNESTheme.textDisabled)
                        Text("Select or create a zone")
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textDisabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)

            // Right: screen properties
            if let idx = selectedScreenIndex {
                ScreenPropertiesView(
                    screen: $state.assetStore.worldScreens[idx],
                    allScreens: state.assetStore.worldScreens
                )
                .frame(width: 260)
            }
        }
        .background(SNESTheme.bgEditor)
        .onChange(of: state.assetStore.worldZones) {
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onChange(of: state.assetStore.worldScreens) {
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onAppear { loadFromStore() }
        .onDisappear { syncToStore() }
        .toolbar {
            ToolbarItemGroup {
                Button(action: performUndo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!undoManager.canUndo)

                Button(action: performRedo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!undoManager.canRedo)
            }
        }
    }

    // MARK: - Toolbar

    private var worldToolbar: some View {
        HStack(spacing: 12) {
            Text("World Manager")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textPrimary)

            Spacer()

            if selectedZone != nil {
                Button(action: addScreen) {
                    Label("Screen", systemImage: "plus.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: removeSelectedScreen) {
                    Label("Delete", systemImage: "minus.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedScreenID == nil)

                Button(action: editSelectedScreen) {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedScreenID == nil)
            }

            Divider().frame(height: 16)

            HStack(spacing: 4) {
                Text("Zoom")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
                Slider(value: $zoom, in: 0.5...2.0, step: 0.25)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Actions

    private func addScreen() {
        guard let zone = selectedZone else { return }
        recordUndo()

        // Find first empty cell
        var gridX = 0, gridY = 0
        let occupied = Set(state.assetStore.worldScreens
            .filter { $0.zoneID == zone.id }
            .map { "\($0.gridX),\($0.gridY)" })

        outerLoop: for row in 0..<zone.gridHeight {
            for col in 0..<zone.gridWidth {
                if !occupied.contains("\(col),\(row)") {
                    gridX = col
                    gridY = row
                    break outerLoop
                }
            }
        }

        let screenCount = state.assetStore.worldScreens.filter { $0.zoneID == zone.id }.count
        var screen = WorldScreen.empty(zoneID: zone.id, gridX: gridX, gridY: gridY, bgMode: zone.bgMode)
        screen.name = "\(zone.name) \(screenCount + 1)"
        state.assetStore.worldScreens.append(screen)
        selectedScreenID = screen.id
    }

    private func editSelectedScreen() {
        guard let id = selectedScreenID else { return }
        openScreenEditor(screenID: id)
    }

    private func openScreenEditor(screenID: UUID) {
        guard let screen = state.assetStore.worldScreens.first(where: { $0.id == screenID }) else { return }
        state.openScreenTab(screenID: screenID, screenName: screen.name)
    }

    private func removeSelectedScreen() {
        guard let id = selectedScreenID else { return }
        recordUndo()
        state.assetStore.worldScreens.removeAll { $0.id == id }
        selectedScreenID = nil
    }

    // MARK: - Undo/Redo

    private func recordUndo() {
        undoManager.recordState(state.assetStore.worldScreens)
    }

    private func performUndo() {
        if let previous = undoManager.undo(current: state.assetStore.worldScreens) {
            state.assetStore.worldScreens = previous
        }
    }

    private func performRedo() {
        if let next = undoManager.redo(current: state.assetStore.worldScreens) {
            state.assetStore.worldScreens = next
        }
    }

    // MARK: - Sync

    private func loadFromStore() {
        if !state.assetStore.worldZones.isEmpty {
            selectedZoneID = state.assetStore.worldZones.first?.id
        }
    }

    private func syncToStore() {
        // Data is already bound directly to assetStore
    }
}
