import Foundation

struct SpriteDecompositionResult {
    var tiles: [SNESTile]
    var entries: [OAMEntry]
    var warnings: [String]
}

enum SpriteDecomposer {
    /// Decompose a flat pixel buffer into 8x8 tiles + OAM entries.
    /// Deduplicates tiles (including flip variants) against existing tileset.
    static func decompose(
        pixels: [UInt8],
        width: Int,
        height: Int,
        depth: TileDepth,
        paletteIndex: Int,
        existingTiles: [SNESTile]
    ) -> SpriteDecompositionResult {
        var warnings: [String] = []
        var newTiles = existingTiles
        var entries: [OAMEntry] = []

        let tilesX = width / 8
        let tilesY = height / 8

        for tileRow in 0..<tilesY {
            for tileCol in 0..<tilesX {
                // Extract 8x8 block
                var tilePixels = [UInt8](repeating: 0, count: 64)
                var allTransparent = true

                for py in 0..<8 {
                    for px in 0..<8 {
                        let canvasX = tileCol * 8 + px
                        let canvasY = tileRow * 8 + py
                        let idx = canvasY * width + canvasX
                        let val = idx < pixels.count ? pixels[idx] : 0
                        tilePixels[py * 8 + px] = val
                        if val != 0 { allTransparent = false }
                    }
                }

                // Skip fully transparent tiles
                if allTransparent { continue }

                let candidate = SNESTile(pixels: tilePixels, depth: depth)

                // Try to match against existing tiles (with flip variants)
                let match = findMatch(candidate: candidate, in: newTiles)

                let tileIndex: Int
                let flipH: Bool
                let flipV: Bool

                if let m = match {
                    tileIndex = m.index
                    flipH = m.flipH
                    flipV = m.flipV
                } else {
                    // Add as new tile
                    tileIndex = newTiles.count
                    newTiles.append(candidate)
                    flipH = false
                    flipV = false
                }

                let entry = OAMEntry(
                    x: tileCol * 8,
                    y: tileRow * 8,
                    tileIndex: tileIndex,
                    paletteIndex: paletteIndex,
                    priority: 2,
                    flipH: flipH,
                    flipV: flipV,
                    size: .small8x8
                )
                entries.append(entry)
            }
        }

        if entries.count > 128 {
            warnings.append("OAM count (\(entries.count)) exceeds hardware limit of 128")
        }

        return SpriteDecompositionResult(
            tiles: newTiles,
            entries: entries,
            warnings: warnings
        )
    }

    // MARK: - Tile matching

    private struct TileMatch {
        let index: Int
        let flipH: Bool
        let flipV: Bool
    }

    private static func findMatch(candidate: SNESTile, in tiles: [SNESTile]) -> TileMatch? {
        let flipH = candidate.flippedHorizontally()
        let flipV = candidate.flippedVertically()
        let flipHV = flipH.flippedVertically()

        for (idx, existing) in tiles.enumerated() {
            if existing.pixels == candidate.pixels {
                return TileMatch(index: idx, flipH: false, flipV: false)
            }
            if existing.pixels == flipH.pixels {
                return TileMatch(index: idx, flipH: true, flipV: false)
            }
            if existing.pixels == flipV.pixels {
                return TileMatch(index: idx, flipH: false, flipV: true)
            }
            if existing.pixels == flipHV.pixels {
                return TileMatch(index: idx, flipH: true, flipV: true)
            }
        }
        return nil
    }
}
