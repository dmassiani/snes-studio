import SwiftUI

struct RightPanelView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Content — mode controlled by toolbar Aide/IA buttons
            switch state.rightPanelMode {
            case .aide:
                ScrollView {
                    switch state.activeLevel {
                    case .logique:
                        LogiquePanel()
                    case .orchestre:
                        OrchestrePanel()
                    case .atelier:
                        AtelierPanel()
                    case .hardware:
                        HardwarePanel()
                    }
                }
            case .chat:
                ChatView(state: state)
            }
        }
        .background(SNESTheme.bgPanel)
        .animation(.easeInOut(duration: 0.15), value: state.activeLevel)
    }
}

// MARK: - Logique Panel (Code - Blue)

private struct LogiquePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "QUICK REF", accent: PyramidLevel.logique.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    QuickRefRow(opcode: "LDA", desc: "Load Accumulator", cycles: "2-5", bytes: "2-3")
                    QuickRefRow(opcode: "STA", desc: "Store Accumulator", cycles: "3-5", bytes: "2-3")
                    QuickRefRow(opcode: "JSR", desc: "Jump to Subroutine", cycles: "6", bytes: "3")
                    QuickRefRow(opcode: "RTS", desc: "Return from Sub", cycles: "6", bytes: "1")
                }
            }

            PanelSection(title: "SYMBOLES", accent: PyramidLevel.logique.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    SymbolRow(name: "Main", address: "$8000")
                    SymbolRow(name: "VBlank", address: "$8100")
                    SymbolRow(name: "ReadInput", address: "$8200")
                    SymbolRow(name: "UpdatePlayer", address: "$8400")
                }
            }

            PanelSection(title: "FICHIERS OUVERTS", accent: PyramidLevel.logique.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("main.asm — modifie")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Text("player.asm — sauve")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textDisabled)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Orchestre Panel (Orchestration - Violet)

private struct OrchestrePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "BUDGET VRAM", accent: PyramidLevel.orchestre.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    BudgetRow(label: "BG1 Tiles", value: "24Ko", pct: 0.37)
                    BudgetRow(label: "BG2 Tiles", value: "8Ko", pct: 0.12)
                    BudgetRow(label: "Sprites", value: "12Ko", pct: 0.19)
                    BudgetRow(label: "Tilemaps", value: "4Ko", pct: 0.06)
                    BudgetRow(label: "Libre", value: "16Ko", pct: 0.25)
                }
            }

            PanelSection(title: "ECRAN ACTIF", accent: PyramidLevel.orchestre.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    InfoRow(label: "Nom", value: "Foret-01")
                    InfoRow(label: "Tiles requis", value: "124")
                    InfoRow(label: "Palettes", value: "3")
                    InfoRow(label: "Entites", value: "8")
                    InfoRow(label: "Sorties", value: "2")
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Atelier Panel (Resources - Orange)

private struct AtelierPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "PALETTE ACTIVE", accent: PyramidLevel.atelier.accent) {
                // 4x4 color grid placeholder
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 4), spacing: 4) {
                    ForEach(0..<16, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hue: Double(i) / 16.0, saturation: 0.7, brightness: 0.8))
                            .frame(height: 32)
                    }
                }
                Text("BGR555: $7C1F")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }

            PanelSection(title: "TILE INFO", accent: PyramidLevel.atelier.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    InfoRow(label: "Index", value: "#042")
                    InfoRow(label: "Format", value: "4bpp")
                    InfoRow(label: "Taille", value: "32 bytes")
                    InfoRow(label: "Palette", value: "Palette 2")
                    InfoRow(label: "Utilise", value: "7 fois")
                }
            }

            PanelSection(title: "PROPRIETES", accent: PyramidLevel.atelier.accent) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Flip H", isOn: .constant(false))
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Toggle("Flip V", isOn: .constant(false))
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    HStack {
                        Text("Priorite")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Spacer()
                        Text("2")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SNESTheme.textPrimary)
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Hardware Panel (Green)

private struct HardwarePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "REGISTRE SELECT.", accent: PyramidLevel.hardware.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    InfoRow(label: "Registre", value: "$2100")
                    InfoRow(label: "Nom", value: "INIDISP")
                    InfoRow(label: "Valeur", value: "$0F")
                    InfoRow(label: "Binaire", value: "0000 1111")

                    SNESTheme.border.frame(height: 1)
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bit 7: Force blank (0=off)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SNESTheme.textDisabled)
                        Text("Bit 3-0: Brightness (15=max)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SNESTheme.success)
                    }
                }
            }

            PanelSection(title: "ACCES DANS CODE", accent: PyramidLevel.hardware.accent) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("main.asm:42  STA $2100")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SNESTheme.info)
                    Text("init.asm:12  LDA #$0F")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SNESTheme.info)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Reusable Panel Components

private struct PanelSection<Content: View>: View {
    let title: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(accent)

            content
        }
    }
}

private struct QuickRefRow: View {
    let opcode: String
    let desc: String
    let cycles: String
    let bytes: String

    var body: some View {
        HStack {
            Text(opcode)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(SNESTheme.info)
                .frame(width: 32, alignment: .leading)
            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(SNESTheme.textSecondary)
            Spacer()
            Text("\(cycles)c")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
        }
    }
}

private struct SymbolRow: View {
    let name: String
    let address: String

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textSecondary)
            Spacer()
            Text(address)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
        }
    }
}

private struct BudgetRow: View {
    let label: String
    let value: String
    let pct: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(PyramidLevel.orchestre.accent.opacity(0.4))
                    .frame(width: geo.size.width * pct, height: 6)
            }
            .frame(height: 6)

            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textDisabled)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
        }
    }
}
