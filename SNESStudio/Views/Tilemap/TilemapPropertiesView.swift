import SwiftUI

struct TilemapPropertiesView: View {
    @Binding var tilemap: SNESTilemap
    var cellX: Int
    var cellY: Int
    var tiles: [SNESTile]
    var palettes: [SNESPalette]

    private var entry: TilemapEntry {
        tilemap.entry(x: cellX, y: cellY)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CELLULE (\(cellX), \(cellY))")
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
                VStack(alignment: .leading, spacing: 16) {
                    // Explanation
                    Text("Chaque case de la tilemap reference une tile et une palette du projet.")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .fixedSize(horizontal: false, vertical: true)

                    // Preview of the cell
                    if entry.tileIndex < tiles.count && !palettes.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                TileMiniPreview(
                                    tile: tiles[entry.tileIndex],
                                    palette: palettes[min(entry.paletteIndex, palettes.count - 1)],
                                    size: 56
                                )
                                .border(SNESTheme.border, width: 1)

                                Text("Tile #\(entry.tileIndex) + Pal \(entry.paletteIndex)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(SNESTheme.textDisabled)
                            }
                            Spacer()
                        }
                    }

                    // MARK: - Tile
                    sectionLabel("TILE")

                    propertyRow("Index") {
                        TextField("", value: Binding(
                            get: { entry.tileIndex },
                            set: { newVal in
                                var e = entry
                                e.tileIndex = newVal
                                tilemap.setEntry(x: cellX, y: cellY, entry: e)
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    }

                    descriptionText("Quel motif 8\u{00D7}8 afficher (depuis le tileset)")

                    // MARK: - Palette
                    sectionLabel("PALETTE")

                    propertyRow("Index") {
                        Picker("", selection: Binding(
                            get: { entry.paletteIndex },
                            set: { newVal in
                                var e = entry
                                e.paletteIndex = newVal
                                tilemap.setEntry(x: cellX, y: cellY, entry: e)
                            }
                        )) {
                            ForEach(0..<min(palettes.count, 8), id: \.self) { i in
                                Text("Pal \(i)").tag(i)
                            }
                        }
                        .frame(width: 70)
                    }

                    // Mini palette preview
                    if entry.paletteIndex < palettes.count {
                        let pal = palettes[entry.paletteIndex]
                        HStack(spacing: 0) {
                            ForEach(0..<min(pal.colors.count, 16), id: \.self) { ci in
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
                                    .frame(width: 10, height: 12)
                                } else {
                                    pal[ci].color
                                        .frame(width: 10, height: 12)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(SNESTheme.border, lineWidth: 0.5)
                        )
                    }

                    descriptionText("Quelle palette de couleurs appliquer a cette tile")

                    // MARK: - Transformations
                    sectionLabel("TRANSFORMATION")

                    Toggle("Miroir horizontal", isOn: Binding(
                        get: { entry.flipH },
                        set: { newVal in
                            var e = entry
                            e.flipH = newVal
                            tilemap.setEntry(x: cellX, y: cellY, entry: e)
                        }
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textSecondary)

                    Toggle("Miroir vertical", isOn: Binding(
                        get: { entry.flipV },
                        set: { newVal in
                            var e = entry
                            e.flipV = newVal
                            tilemap.setEntry(x: cellX, y: cellY, entry: e)
                        }
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textSecondary)

                    descriptionText("Retourne la tile sans utiliser une tile supplementaire en VRAM")

                    // MARK: - Priority
                    sectionLabel("PRIORITE")

                    Toggle("Priorite haute", isOn: Binding(
                        get: { entry.priority },
                        set: { newVal in
                            var e = entry
                            e.priority = newVal
                            tilemap.setEntry(x: cellX, y: cellY, entry: e)
                        }
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textSecondary)

                    descriptionText("Afficher devant ou derriere les sprites")
                }
                .padding(12)
            }
            .background(SNESTheme.bgEditor)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(SNESTheme.textDisabled)
            .padding(.top, 4)
    }

    private func descriptionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(SNESTheme.textDisabled.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func propertyRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 50, alignment: .leading)
            content()
        }
    }
}
