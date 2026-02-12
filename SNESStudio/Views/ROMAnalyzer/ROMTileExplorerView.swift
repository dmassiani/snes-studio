import SwiftUI

struct ROMTileExplorerView: View {
    @Bindable var state: AppState
    @State private var explorerOffset: Int = 0
    @State private var explorerDepth: TileDepth = .bpp4
    @State private var selectedPaletteIndex: Int = 0
    @State private var tileCount: Int = 256

    private var tileBlocks: [ROMTileBlock] {
        state.romAnalyzer.result?.tileBlocks ?? []
    }

    private var displayTiles: [SNESTile] {
        guard let result = state.romAnalyzer.result,
              let romURL = romDataURL else { return tileBlocks.first?.tiles ?? [] }

        if let data = try? Data(contentsOf: romURL) {
            let romData: Data = result.hasSMCHeader ? data.dropFirst(512) : data
            return state.romAnalyzer.extractTilesAtOffset(
                data: romData, offset: explorerOffset, depth: explorerDepth, count: tileCount)
        }
        return tileBlocks.first?.tiles ?? []
    }

    private var romDataURL: URL? { nil }  // ROM data is loaded from analyzer

    var body: some View {
        VStack(spacing: 0) {
            explorerToolbar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !tileBlocks.isEmpty {
                        Text("\(tileBlocks.first?.tiles.count ?? 0) tiles extraites")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .padding(.horizontal)

                        tileGrid(tiles: tileBlocks.first?.tiles ?? [])

                        // Import button
                        HStack {
                            Spacer()
                            Button("Importer \(tileBlocks.first?.tiles.count ?? 0) tiles") {
                                importTiles()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Spacer()
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "square.grid.3x3")
                                .font(.system(size: 32))
                                .foregroundStyle(SNESTheme.textDisabled)
                            Text("Aucune tile extraite")
                                .font(.system(size: 12))
                                .foregroundStyle(SNESTheme.textDisabled)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(12)
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var explorerToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Offset:")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
                TextField("0", value: $explorerOffset, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .font(.system(size: 11, design: .monospaced))
            }

            Picker("Depth", selection: $explorerDepth) {
                ForEach(TileDepth.allCases, id: \.self) { d in
                    Text(d.label).tag(d)
                }
            }
            .frame(width: 80)

            Picker("Palette", selection: $selectedPaletteIndex) {
                ForEach(0..<state.assetStore.palettes.count, id: \.self) { i in
                    Text("Pal \(i)").tag(i)
                }
            }
            .frame(width: 80)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Tile Grid

    private func tileGrid(tiles: [SNESTile]) -> some View {
        let tileSize: CGFloat = 16
        let columns = Array(repeating: GridItem(.fixed(tileSize), spacing: 1), count: 16)

        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                Canvas { context, size in
                    let palette = state.assetStore.palettes[min(selectedPaletteIndex, state.assetStore.palettes.count - 1)]
                    let pixelSize = size.width / 8.0

                    for y in 0..<8 {
                        for x in 0..<8 {
                            let colorIndex = Int(tile.pixel(x: x, y: y))
                            let snesColor = colorIndex < palette.colors.count ? palette.colors[colorIndex] : .black
                            let rect = CGRect(x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize,
                                              width: pixelSize, height: pixelSize)
                            context.fill(Path(rect), with: .color(snesColor.color))
                        }
                    }
                }
                .frame(width: tileSize, height: tileSize)
                .help("Tile \(index) @ offset \(explorerOffset + index * VRAMBudgetCalculator.tileSizeBytes(depth: explorerDepth))")
            }
        }
    }

    // MARK: - Import

    private func importTiles() {
        guard let tiles = tileBlocks.first?.tiles, !tiles.isEmpty else { return }
        state.assetStore.tiles.append(contentsOf: tiles)
        state.appendConsole("Importe \(tiles.count) tiles depuis ROM", type: .success)
    }
}
