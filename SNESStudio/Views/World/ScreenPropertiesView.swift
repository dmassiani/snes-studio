import SwiftUI

struct ScreenPropertiesView: View {
    @Binding var screen: WorldScreen
    let allScreens: [WorldScreen]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nom")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    TextField("Nom", text: $screen.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                // Grid position
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grid X")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textDisabled)
                        Stepper("\(screen.gridX)", value: $screen.gridX, in: 0...31)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grid Y")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textDisabled)
                        Stepper("\(screen.gridY)", value: $screen.gridY, in: 0...31)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }

                // Layers info (read-only)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Layers")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Text("\(screen.layers.count) couche(s)")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textPrimary)
                    ForEach(screen.layers) { layer in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(layer.visible ? SNESTheme.info : SNESTheme.textDisabled)
                                .frame(width: 6, height: 6)
                            Text(layer.name)
                                .font(.system(size: 10))
                                .foregroundStyle(SNESTheme.textSecondary)
                            Spacer()
                            Text("\(layer.tilemap.width)\u{00D7}\(layer.tilemap.height)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(SNESTheme.textDisabled)
                        }
                    }
                }

                Divider()

                // Entities
                entitiesSection

                Divider()

                // Exits
                exitsSection
            }
            .padding(12)
        }
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Entities

    private var entitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Entites (\(screen.entities.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
                Button(action: addEntity) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SNESTheme.textSecondary)
            }

            ForEach(Array(screen.entities.enumerated()), id: \.element.id) { index, entity in
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                        .foregroundStyle(SNESTheme.warning)
                    Text(entity.typeName)
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textPrimary)
                    Text("(\(entity.x), \(entity.y))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Spacer()
                    Button(action: { removeEntity(at: index) }) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.danger.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Exits

    private var exitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sorties (\(screen.exits.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
                Button(action: addExit) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SNESTheme.textSecondary)
            }

            ForEach(Array(screen.exits.enumerated()), id: \.element.id) { index, exit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(PyramidLevel.orchestre.accent)
                        Text(exit.transitionType.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textPrimary)

                        Spacer()

                        Button(action: { removeExit(at: index) }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(SNESTheme.danger.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    if let targetID = exit.targetScreenID,
                       let target = allScreens.first(where: { $0.id == targetID }) {
                        Text("-> \(target.name)")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textDisabled)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addEntity() {
        let entity = ScreenEntity(typeName: "Entity", x: 128, y: 112, properties: [:])
        screen.entities.append(entity)
    }

    private func removeEntity(at index: Int) {
        guard index < screen.entities.count else { return }
        screen.entities.remove(at: index)
    }

    private func addExit() {
        let exit = ScreenExit(x: 0, y: 0, width: 16, height: 224, transitionType: .fadeBlack)
        screen.exits.append(exit)
    }

    private func removeExit(at index: Int) {
        guard index < screen.exits.count else { return }
        screen.exits.remove(at: index)
    }
}
