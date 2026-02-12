import SwiftUI

struct ROMPaletteExplorerView: View {
    @Bindable var state: AppState

    private var paletteBlocks: [ROMPaletteBlock] {
        state.romAnalyzer.result?.paletteBlocks ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(paletteBlocks.count) palettes detectees")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(SNESTheme.bgPanel)

            Divider()

            if paletteBlocks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 32))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Text("Aucune palette detectee")
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textDisabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(paletteBlocks) { block in
                            paletteRow(block)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(SNESTheme.bgEditor)
    }

    private func paletteRow(_ block: ROMPaletteBlock) -> some View {
        HStack(spacing: 8) {
            // Offset
            Text(String(format: "$%06X", block.offset))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
                .frame(width: 70)

            // Color preview
            HStack(spacing: 1) {
                ForEach(0..<16, id: \.self) { i in
                    Rectangle()
                        .fill(block.palette.colors[i].color)
                        .frame(width: 14, height: 14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))

            Spacer()

            // Import button
            Button("Importer") {
                importPalette(block)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(SNESTheme.bgPanel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func importPalette(_ block: ROMPaletteBlock) {
        // Find first empty palette slot or append
        if let emptyIndex = state.assetStore.palettes.firstIndex(where: {
            $0.colors.allSatisfy { $0 == .black }
        }) {
            state.assetStore.palettes[emptyIndex] = block.palette
        } else if state.assetStore.palettes.count < 16 {
            state.assetStore.palettes.append(block.palette)
        } else {
            // Replace last palette
            state.assetStore.palettes[15] = block.palette
        }
        state.appendConsole("Palette importee depuis offset \(String(format: "$%06X", block.offset))", type: .success)
    }
}
