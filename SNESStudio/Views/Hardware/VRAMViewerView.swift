import SwiftUI

struct VRAMViewerView: View {
    @Bindable var state: AppState
    @State private var selectedDepth: TileDepth = .bpp4
    @State private var selectedPaletteIndex: Int = 0
    @State private var zoom: CGFloat = 2.0

    private var budget: VRAMBudget {
        guard !state.assetStore.worldZones.isEmpty,
              !state.assetStore.worldScreens.isEmpty else {
            return estimatedBudget
        }
        let zone = state.assetStore.worldZones[0]
        let screen = state.assetStore.worldScreens[0]
        return VRAMBudgetCalculator.budgetForScreen(screen: screen, zone: zone, tiles: state.assetStore.tiles)
    }

    private var estimatedBudget: VRAMBudget {
        var blocks: [VRAMBlock] = []
        let tileCount = state.assetStore.tiles.count
        let tileBytes = tileCount * VRAMBudgetCalculator.tileSizeBytes(depth: selectedDepth)

        blocks.append(VRAMBlock(label: "BG Tiles", address: 0, sizeBytes: tileBytes, category: .bg1Tiles))

        let mapBytes = 32 * 32 * 2
        blocks.append(VRAMBlock(label: "BG1 Map", address: tileBytes, sizeBytes: mapBytes, category: .bg1Map))

        let used = tileBytes + mapBytes
        if used < 65536 {
            blocks.append(VRAMBlock(label: "Free", address: used, sizeBytes: 65536 - used, category: .free))
        }
        return VRAMBudget(blocks: blocks)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    vramBlocksView
                    Divider().padding(.horizontal)
                    tileGridView
                }
                .padding(16)
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("VRAM Viewer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textPrimary)

            Spacer()

            Picker("Depth", selection: $selectedDepth) {
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

            HStack(spacing: 4) {
                Text("Zoom")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
                Slider(value: $zoom, in: 1...4, step: 0.5)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - VRAM Blocks

    private var vramBlocksView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VRAM Layout")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
                Text(String(format: "%.1f%% used (%d / 65536 bytes)",
                            budget.percentage, budget.usedBytes))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(budget.isOverBudget ? SNESTheme.danger : SNESTheme.textSecondary)
            }

            // Block bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(budget.blocks) { block in
                        let fraction = CGFloat(block.sizeBytes) / CGFloat(budget.totalBytes)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: block.category.colorHex))
                            .frame(width: max(2, geo.size.width * fraction))
                            .help("\(block.label): \(block.sizeBytes) bytes")
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Legend
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 4) {
                ForEach(budget.blocks.filter { $0.category != .free }) { block in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: block.category.colorHex))
                            .frame(width: 8, height: 8)
                        Text(block.label)
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Spacer()
                        Text(formatBytes(block.sizeBytes))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SNESTheme.textDisabled)
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
        return "\(bytes) B"
    }

    // MARK: - Tile Grid

    private var tileGridView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project tiles (\(state.assetStore.tiles.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            let tileSize = 8.0 * zoom
            let columns = Array(repeating: GridItem(.fixed(tileSize), spacing: 1), count: 16)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(state.assetStore.tiles.enumerated()), id: \.offset) { index, tile in
                    tileView(tile, index: index, size: tileSize)
                }
            }
        }
    }

    private func tileView(_ tile: SNESTile, index: Int, size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let palette = state.assetStore.palettes[safe: selectedPaletteIndex] ?? state.assetStore.palettes[0]
            let pixelSize = canvasSize.width / 8.0

            for y in 0..<8 {
                for x in 0..<8 {
                    let colorIndex = Int(tile.pixel(x: x, y: y))
                    let snesColor = palette.colors[safe: colorIndex] ?? .black
                    let rect = CGRect(x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize,
                                      width: pixelSize, height: pixelSize)
                    context.fill(Path(rect), with: .color(snesColor.color))
                }
            }
        }
        .frame(width: size, height: size)
        .help("Tile \(index)")
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
