import SwiftUI

struct BGR555ColorPicker: View {
    @Binding var color: SNESColor

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("COLOR PICKER")
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
                VStack(spacing: 16) {
                    // Color preview
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.color)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(SNESTheme.border, lineWidth: 1)
                        )

                    // Hex value
                    Text(color.hexString)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(SNESTheme.textPrimary)

                    // RGB sliders
                    VStack(spacing: 12) {
                        colorSlider(label: "R", value: color.red, tint: .red) { newVal in
                            color = SNESColor(r: newVal, g: color.green, b: color.blue)
                        }
                        colorSlider(label: "G", value: color.green, tint: .green) { newVal in
                            color = SNESColor(r: color.red, g: newVal, b: color.blue)
                        }
                        colorSlider(label: "B", value: color.blue, tint: .blue) { newVal in
                            color = SNESColor(r: color.red, g: color.green, b: newVal)
                        }
                    }

                    // Presets
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRESETS")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(SNESTheme.textDisabled)

                        HStack(spacing: 4) {
                            presetButton(.black, label: "Noir")
                            presetButton(.white, label: "Blanc")
                            presetButton(.red, label: "R")
                            presetButton(.green, label: "G")
                            presetButton(.blue, label: "B")
                        }
                    }
                }
                .padding(12)
            }
            .background(SNESTheme.bgEditor)
        }
    }

    private func colorSlider(label: String, value: Int, tint: Color, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 16)

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0)) }
                ),
                in: 0...31,
                step: 1
            )
            .tint(tint)

            Text("\(value)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private func presetButton(_ preset: SNESColor, label: String) -> some View {
        Button {
            color = preset
        } label: {
            VStack(spacing: 2) {
                preset.color
                    .frame(width: 28, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(SNESTheme.border, lineWidth: 1)
                    )
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
        .buttonStyle(.plain)
    }
}
