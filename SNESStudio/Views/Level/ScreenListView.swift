import SwiftUI

/// Hub view listing all screens across all zones, allowing quick access to the level editor.
struct ScreenListView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if state.assetStore.worldZones.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(state.assetStore.worldZones) { zone in
                            zoneSection(zone)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Ecrans")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textPrimary)
            Spacer()
            Text("\(state.assetStore.worldScreens.count) ecran(s)")
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textDisabled)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Zone section

    private func zoneSection(_ zone: WorldZone) -> some View {
        let screens = state.assetStore.worldScreens.filter { $0.zoneID == zone.id }

        return VStack(alignment: .leading, spacing: 8) {
            // Zone header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: zone.colorHex))
                    .frame(width: 10, height: 10)
                Text(zone.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SNESTheme.textPrimary)
                Text("Mode \(zone.bgMode)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
                Spacer()
                Text("\(screens.count) ecran(s)")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
            }

            if screens.isEmpty {
                HStack(spacing: 8) {
                    Text("Aucun ecran")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Button(action: { addScreen(to: zone) }) {
                        Label("Creer", systemImage: "plus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.leading, 18)
            } else {
                // Screen cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(screens) { screen in
                        screenCard(screen, zone: zone)
                    }

                    // Add screen button card
                    addScreenCard(zone: zone)
                }
            }
        }
    }

    // MARK: - Screen card

    private func screenCard(_ screen: WorldScreen, zone: WorldZone) -> some View {
        Button {
            state.openScreenTab(screenID: screen.id, screenName: screen.name)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: zone.colorHex))
                    Text(screen.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SNESTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Label("\(screen.layers.count) layers", systemImage: "square.3.layers.3d")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Label("\(screen.entities.count) entites", systemImage: "mappin")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)
                }

                // Grid position
                Text("Grille (\(screen.gridX), \(screen.gridY))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SNESTheme.bgPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SNESTheme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add screen card

    private func addScreenCard(zone: WorldZone) -> some View {
        Button {
            addScreen(to: zone)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 18))
                    .foregroundStyle(SNESTheme.textDisabled)
                Text("Nouveau")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SNESTheme.bgPanel.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SNESTheme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func addScreen(to zone: WorldZone) {
        let screens = state.assetStore.worldScreens.filter { $0.zoneID == zone.id }

        // Find first empty cell
        var gridX = 0, gridY = 0
        let occupied = Set(screens.map { "\($0.gridX),\($0.gridY)" })
        outerLoop: for row in 0..<zone.gridHeight {
            for col in 0..<zone.gridWidth {
                if !occupied.contains("\(col),\(row)") {
                    gridX = col
                    gridY = row
                    break outerLoop
                }
            }
        }

        var screen = WorldScreen.empty(zoneID: zone.id, gridX: gridX, gridY: gridY, bgMode: zone.bgMode)
        screen.name = "\(zone.name) \(screens.count + 1)"
        state.assetStore.worldScreens.append(screen)
        NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)

        // Open it immediately
        state.openScreenTab(screenID: screen.id, screenName: screen.name)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 32))
                .foregroundStyle(SNESTheme.textDisabled)
            Text("Aucune zone creee")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SNESTheme.textSecondary)
            Text("Creez des zones et ecrans dans le World Manager\npour les retrouver ici.")
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textDisabled)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
