import SwiftUI

struct LevelLayerPanel: View {
    @Binding var level: SNESLevel
    @Binding var activeLayerIndex: Int
    var tiles: [SNESTile]
    var palettes: [SNESPalette]

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Layers section
            sectionHeader("LAYERS")

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(level.layers.indices, id: \.self) { idx in
                        layerRow(index: idx)
                    }

                    Divider().padding(.vertical, 4)

                    // MARK: - Parallax section
                    if activeLayerIndex < level.layers.count {
                        parallaxSection
                    }

                    Divider().padding(.vertical, 4)

                    // MARK: - Preview section
                    sectionHeader("PREVIEW")
                        .padding(.top, 4)

                    ParallaxPreviewView(
                        level: level,
                        tiles: tiles,
                        palettes: palettes
                    )
                    .frame(height: 160)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .background(SNESTheme.bgEditor)
        }
    }

    // MARK: - Layer row

    private func layerRow(index: Int) -> some View {
        let layer = level.layers[index]
        let isActive = index == activeLayerIndex

        return HStack(spacing: 6) {
            // Visibility toggle
            Button {
                level.layers[index].visible.toggle()
            } label: {
                Image(systemName: layer.visible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 10))
                    .foregroundStyle(layer.visible ? SNESTheme.textSecondary : SNESTheme.textDisabled)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)

            // Layer name + ratio
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? SNESTheme.textPrimary : SNESTheme.textSecondary)
                    .lineLimit(1)

                Text("\(layer.scrollRatioX, specifier: "%.2f")x")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }

            Spacer()

            // Size indicator
            Text("\(layer.tilemap.width)\u{00D7}\(layer.tilemap.height)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? SNESTheme.info.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            activeLayerIndex = index
        }
    }

    // MARK: - Parallax controls

    private var parallaxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("PARALLAX")
                .padding(.bottom, 2)

            let layerBinding = Binding(
                get: { level.layers[activeLayerIndex] },
                set: { level.layers[activeLayerIndex] = $0 }
            )

            // Ratio X
            HStack {
                Text("Ratio X")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
                    .frame(width: 55, alignment: .leading)
                Slider(value: layerBinding.scrollRatioX, in: 0.0...1.0, step: 0.05)
                Text("\(layerBinding.scrollRatioX.wrappedValue, specifier: "%.2f")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
                    .frame(width: 32)
            }

            // Ratio Y
            HStack {
                Text("Ratio Y")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
                    .frame(width: 55, alignment: .leading)
                Slider(value: layerBinding.scrollRatioY, in: 0.0...1.0, step: 0.05)
                Text("\(layerBinding.scrollRatioY.wrappedValue, specifier: "%.2f")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
                    .frame(width: 32)
            }

            // Repeat toggles
            HStack(spacing: 16) {
                Toggle("Repeat X", isOn: layerBinding.repeatX)
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
                Toggle("Repeat Y", isOn: layerBinding.repeatY)
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
            }

            // Layer tilemap size
            HStack {
                Text("Size")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)
                    .frame(width: 55, alignment: .leading)
                let tm = level.layers[activeLayerIndex].tilemap
                Text("\(tm.width) \u{00D7} \(tm.height) tiles")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Helpers

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
}
