import SwiftUI

struct TilesetBrowserView: View {
    @Binding var tiles: [SNESTile]
    @Binding var selectedIndex: Int
    var palette: SNESPalette
    @Binding var depth: TileDepth
    var gridCols: Int = 1
    var gridRows: Int = 1

    private let previewSize: CGFloat = 24
    private let columns = [GridItem](repeating: GridItem(.fixed(24), spacing: 2), count: 6)

    @State private var collapsedCategories: Set<String> = []

    /// Range of tile indices covered by the current grid selection
    private var selectedRange: Range<Int> {
        let start = min(selectedIndex, tiles.count - 1)
        let count = gridCols * gridRows
        let end = min(start + count, tiles.count)
        return start..<end
    }

    /// Group tiles by category, preserving original indices
    private var sections: [(category: String, indices: [Int])] {
        var groups: [(category: String, indices: [Int])] = []
        var currentCategory: String? = nil
        var currentIndices: [Int] = []

        for i in tiles.indices {
            let cat = tiles[i].category
            if cat != currentCategory {
                if let prev = currentCategory {
                    groups.append((category: prev, indices: currentIndices))
                }
                currentCategory = cat
                currentIndices = [i]
            } else {
                currentIndices.append(i)
            }
        }
        if let last = currentCategory {
            groups.append((category: last, indices: currentIndices))
        }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TILESET (\(tiles.count))")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(SNESTheme.textSecondary)

                Spacer()

                Button {
                    tiles.append(.empty(depth: depth))
                    selectedIndex = tiles.count - 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }

            // Grid grouped by category
            ScrollView {
                VStack(spacing: 0) {
                    let sects = sections
                    let hasCategories = sects.contains { !$0.category.isEmpty }

                    if hasCategories {
                        ForEach(Array(sects.enumerated()), id: \.offset) { _, section in
                            categorySection(section)
                        }
                    } else {
                        // No categories — flat grid (original behavior)
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(tiles.indices, id: \.self) { idx in
                                tilePreview(index: idx)
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .background(SNESTheme.bgEditor)
        }
    }

    // MARK: - Category Section

    private func categorySection(_ section: (category: String, indices: [Int])) -> some View {
        let displayName = section.category.isEmpty ? "General" : section.category
        let isCollapsed = collapsedCategories.contains(section.category)

        return VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isCollapsed {
                        collapsedCategories.remove(section.category)
                    } else {
                        collapsedCategories.insert(section.category)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .frame(width: 10)

                    Text(displayName.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(section.category.isEmpty ? SNESTheme.textDisabled : SNESTheme.info)

                    Text("\(section.indices.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(SNESTheme.bgPanel.opacity(0.5))
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(section.indices, id: \.self) { idx in
                        tilePreview(index: idx)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }

            SNESTheme.border.opacity(0.3).frame(height: 1)
        }
    }

    private func tilePreview(index: Int) -> some View {
        let isInGrid = selectedRange.contains(index)
        let isPrimary = index == selectedIndex

        return Button {
            selectedIndex = index
        } label: {
            TileMiniPreview(tile: tiles[index], palette: palette, size: previewSize)
                .border(isPrimary ? SNESTheme.info :
                        isInGrid ? SNESTheme.info.opacity(0.5) :
                        SNESTheme.border,
                        width: (isPrimary || isInGrid) ? 2 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini tile preview using CGImage (nearest-neighbor for crisp pixels)

struct TileMiniPreview: View {
    let tile: SNESTile
    let palette: SNESPalette
    let size: CGFloat

    var body: some View {
        Group {
            if let cgImage = makeCGImage() {
                // Checkerboard behind for transparency
                Image(cgImage, scale: 1, label: Text(""))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: size, height: size)
                    .background(checkerboard)
            } else {
                Color.black.frame(width: size, height: size)
            }
        }
    }

    private var checkerboard: some View {
        Canvas { ctx, sz in
            let checkSize = sz.width / 4
            for row in 0..<4 {
                for col in 0..<4 {
                    let color: Color = (row + col) % 2 == 0
                        ? Color(white: 0.18) : Color(white: 0.12)
                    ctx.fill(
                        Path(CGRect(
                            x: CGFloat(col) * checkSize,
                            y: CGFloat(row) * checkSize,
                            width: checkSize, height: checkSize
                        )),
                        with: .color(color)
                    )
                }
            }
        }
    }

    private func makeCGImage() -> CGImage? {
        var pixelData = [UInt8](repeating: 0, count: 8 * 8 * 4)
        for y in 0..<8 {
            for x in 0..<8 {
                let colorIdx = Int(tile.pixel(x: x, y: y))
                if colorIdx == 0 {
                    // Transparent pixel (alpha = 0)
                    let offset = (y * 8 + x) * 4
                    pixelData[offset] = 0
                    pixelData[offset + 1] = 0
                    pixelData[offset + 2] = 0
                    pixelData[offset + 3] = 0
                } else {
                    let c = palette[colorIdx]
                    let offset = (y * 8 + x) * 4
                    pixelData[offset]     = UInt8(c.red * 255 / 31)
                    pixelData[offset + 1] = UInt8(c.green * 255 / 31)
                    pixelData[offset + 2] = UInt8(c.blue * 255 / 31)
                    pixelData[offset + 3] = 255
                }
            }
        }

        return pixelData.withUnsafeMutableBytes { ptr -> CGImage? in
            guard let baseAddress = ptr.baseAddress else { return nil }
            guard let ctx = CGContext(
                data: baseAddress,
                width: 8, height: 8,
                bitsPerComponent: 8, bytesPerRow: 8 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
    }
}
