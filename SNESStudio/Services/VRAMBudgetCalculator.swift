import Foundation

enum VRAMBudgetCalculator {

    static func tileSizeBytes(depth: TileDepth) -> Int {
        switch depth {
        case .bpp2: return 16
        case .bpp4: return 32
        case .bpp8: return 64
        }
    }

    static func tilemapSizeBytes(width: Int, height: Int) -> Int {
        // Each tilemap entry is 2 bytes
        width * height * 2
    }

    static func budgetForScreen(screen: WorldScreen, zone: WorldZone, tiles: [SNESTile]) -> VRAMBudget {
        let modeInfo = BGModeInfo.allModes[min(zone.bgMode, 7)]
        var blocks: [VRAMBlock] = []
        var currentAddress = 0

        // Tile data for each layer in the screen
        for (layerIdx, layer) in screen.layers.enumerated() {
            // Find the matching BG mode layer info for depth
            let bgLayerInfo = modeInfo.activeLayers.first { $0.layer == layer.bgLayer }
            guard let depth = bgLayerInfo?.depth else { continue }
            let tileBytes = tileSizeBytes(depth: depth)

            // Count unique tile indices used in this layer's tilemap
            var usedTileIndices = Set<Int>()
            let tm = layer.tilemap
            for cy in 0..<tm.height {
                for cx in 0..<tm.width {
                    let entry = tm.entry(x: cx, y: cy)
                    if entry.tileIndex > 0 {
                        usedTileIndices.insert(entry.tileIndex)
                    }
                }
            }
            let uniqueCount = min(usedTileIndices.count, tiles.count)
            let sizeBytes = uniqueCount * tileBytes

            let category: VRAMCategory
            switch layer.bgLayer {
            case 0: category = .bg1Tiles
            case 1: category = .bg2Tiles
            case 2: category = .bg3Tiles
            default: continue
            }

            blocks.append(VRAMBlock(
                label: "BG\(layer.bgLayer + 1) Tiles (\(depth.label))",
                address: currentAddress,
                sizeBytes: sizeBytes,
                category: category
            ))
            currentAddress += sizeBytes
        }

        // Sprite tiles
        let spriteTileBytes = 128 * tileSizeBytes(depth: .bpp4) // Default 128 sprite tiles
        blocks.append(VRAMBlock(
            label: "Sprites (4bpp)",
            address: currentAddress,
            sizeBytes: spriteTileBytes,
            category: .spriteTiles
        ))
        currentAddress += spriteTileBytes

        // Tilemaps for each layer
        for layer in screen.layers {
            let bgLayerInfo = modeInfo.activeLayers.first { $0.layer == layer.bgLayer }
            guard bgLayerInfo?.depth != nil else { continue }
            let mapBytes = tilemapSizeBytes(width: 32, height: 32)

            let category: VRAMCategory
            switch layer.bgLayer {
            case 0: category = .bg1Map
            case 1: category = .bg2Map
            case 2: category = .bg3Map
            default: continue
            }

            blocks.append(VRAMBlock(
                label: "BG\(layer.bgLayer + 1) Map",
                address: currentAddress,
                sizeBytes: mapBytes,
                category: category
            ))
            currentAddress += mapBytes
        }

        // Remaining free space
        if currentAddress < 65536 {
            blocks.append(VRAMBlock(
                label: "Free",
                address: currentAddress,
                sizeBytes: 65536 - currentAddress,
                category: .free
            ))
        }

        return VRAMBudget(blocks: blocks)
    }

    static func transitionCost(from: WorldScreen, to: WorldScreen, tiles: [SNESTile]) -> TransitionCost {
        // Collect all unique tile indices used across all layers
        func collectTileIndices(_ screen: WorldScreen) -> Set<Int> {
            var indices = Set<Int>()
            for layer in screen.layers {
                let tm = layer.tilemap
                for cy in 0..<tm.height {
                    for cx in 0..<tm.width {
                        let entry = tm.entry(x: cx, y: cy)
                        if entry.tileIndex > 0 {
                            indices.insert(entry.tileIndex)
                        }
                    }
                }
            }
            return indices
        }

        let fromSet = collectTileIndices(from)
        let toSet = collectTileIndices(to)

        let tilesToRemove = fromSet.subtracting(toSet).count
        let tilesToLoad = toSet.subtracting(fromSet).count

        // Assume 4bpp tiles by default
        let bytesPerTile = tileSizeBytes(depth: .bpp4)
        let bytesToTransfer = tilesToLoad * bytesPerTile

        // ~7KB per VBlank via DMA
        let bytesPerVBlank = 7168
        let framesNeeded = bytesToTransfer > 0 ? max(1, (bytesToTransfer + bytesPerVBlank - 1) / bytesPerVBlank) : 0

        return TransitionCost(
            tilesToRemove: tilesToRemove,
            tilesToLoad: tilesToLoad,
            bytesToTransfer: bytesToTransfer,
            framesNeeded: framesNeeded
        )
    }
}
