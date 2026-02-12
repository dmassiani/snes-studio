import AppKit
import CoreGraphics

// MARK: - Configuration & Result

struct SpriteSheetImportConfig {
    var frameWidth: Int
    var frameHeight: Int
    var tileDepth: TileDepth = .bpp4
    var animName: String = "Imported"
    var frameDuration: Int = 4  // VBlanks
    var tileCategory: String = "Sprite"
}

struct SpriteSheetImportResult {
    var palette: SNESPalette
    var tiles: [SNESTile]
    var frames: [SpriteFrame]
    var animation: SpriteAnimation
    var stats: ImportStats
}

struct ImportStats {
    var totalFrames: Int
    var rawTileCount: Int
    var uniqueTileCount: Int
    var dedupRatio: Double
    var colorsFound: Int
    var oamPerFrame: Int
    var warnings: [String]
}

// MARK: - Internal types

private struct TileRef {
    var index: Int
    var flipH: Bool
    var flipV: Bool
}

private struct RGBPixel: Hashable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

private struct WeightedColor {
    var color: RGBPixel
    var count: Int
}

private struct Bucket {
    var colors: [WeightedColor]

    var totalCount: Int { colors.reduce(0) { $0 + $1.count } }

    var rangeR: Int {
        guard let lo = colors.min(by: { $0.color.r < $1.color.r }),
              let hi = colors.max(by: { $0.color.r < $1.color.r }) else { return 0 }
        return Int(hi.color.r) - Int(lo.color.r)
    }
    var rangeG: Int {
        guard let lo = colors.min(by: { $0.color.g < $1.color.g }),
              let hi = colors.max(by: { $0.color.g < $1.color.g }) else { return 0 }
        return Int(hi.color.g) - Int(lo.color.g)
    }
    var rangeB: Int {
        guard let lo = colors.min(by: { $0.color.b < $1.color.b }),
              let hi = colors.max(by: { $0.color.b < $1.color.b }) else { return 0 }
        return Int(hi.color.b) - Int(lo.color.b)
    }

    var maxRange: Int { max(rangeR, max(rangeG, rangeB)) }

    var dominantChannel: Int {
        let r = rangeR, g = rangeG, b = rangeB
        if r >= g && r >= b { return 0 }
        if g >= r && g >= b { return 1 }
        return 2
    }

    /// Frequency-weighted centroid
    var centroid: RGBPixel {
        guard !colors.isEmpty else { return RGBPixel(r: 0, g: 0, b: 0) }
        let total = totalCount
        guard total > 0 else { return colors[0].color }
        let sumR = colors.reduce(0) { $0 + Int($1.color.r) * $1.count }
        let sumG = colors.reduce(0) { $0 + Int($1.color.g) * $1.count }
        let sumB = colors.reduce(0) { $0 + Int($1.color.b) * $1.count }
        return RGBPixel(r: UInt8(sumR / total), g: UInt8(sumG / total), b: UInt8(sumB / total))
    }

    /// Split at the median of weighted pixel count
    func split() -> (Bucket, Bucket) {
        var sorted = colors
        switch dominantChannel {
        case 0: sorted.sort { $0.color.r < $1.color.r }
        case 1: sorted.sort { $0.color.g < $1.color.g }
        default: sorted.sort { $0.color.b < $1.color.b }
        }
        // Split at the median pixel count (not median color count)
        let halfCount = totalCount / 2
        var running = 0
        var splitIdx = sorted.count / 2
        for (i, wc) in sorted.enumerated() {
            running += wc.count
            if running >= halfCount {
                splitIdx = max(1, i + 1)
                break
            }
        }
        splitIdx = min(splitIdx, sorted.count - 1)
        return (Bucket(colors: Array(sorted[..<splitIdx])), Bucket(colors: Array(sorted[splitIdx...])))
    }
}

// MARK: - Importer

enum SpriteSheetImporter {

    // MARK: - Public API

    static func detectFrameSize(imageWidth: Int, imageHeight: Int) -> (width: Int, height: Int, count: Int)? {
        // Horizontal strip: width > height and divisible
        if imageWidth > imageHeight && imageWidth % imageHeight == 0 {
            let count = imageWidth / imageHeight
            return (imageHeight, imageHeight, count)
        }
        // Vertical strip: height > width and divisible
        if imageHeight > imageWidth && imageHeight % imageWidth == 0 {
            let count = imageHeight / imageWidth
            return (imageWidth, imageWidth, count)
        }
        // Single frame
        if imageWidth == imageHeight {
            return (imageWidth, imageHeight, 1)
        }
        return nil
    }

    static func processImage(_ cgImage: CGImage, config: SpriteSheetImportConfig) -> SpriteSheetImportResult {
        let (rgba, imgW, imgH) = extractPixels(from: cgImage)
        let rawFrames = cutFrames(rgba: rgba, imageWidth: imgW, imageHeight: imgH, frameWidth: config.frameWidth, frameHeight: config.frameHeight)
        let maxColors = min(config.tileDepth.maxColorIndex, 15) // index 0 = transparent
        let (palette, indexedFrames, colorsFound) = quantizeColors(frames: rawFrames, frameWidth: config.frameWidth, frameHeight: config.frameHeight, maxColors: maxColors)

        let paddedW = ((config.frameWidth + 7) / 8) * 8
        let paddedH = ((config.frameHeight + 7) / 8) * 8

        var allRawTiles: [[TileGridEntry]] = []
        var rawTileCount = 0

        for indexed in indexedFrames {
            let entries = decomposeIntoTiles(indexed: indexed, frameWidth: config.frameWidth, frameHeight: config.frameHeight, paddedWidth: paddedW, paddedHeight: paddedH, depth: config.tileDepth, category: config.tileCategory)
            rawTileCount += entries.count
            allRawTiles.append(entries)
        }

        // Deduplicate tiles across all frames
        var uniqueTiles: [SNESTile] = []
        var tileRefsByFrame: [[TileRef]] = []
        var lookup: [Data: (index: Int, flipH: Bool, flipV: Bool)] = [:]

        for frameEntries in allRawTiles {
            var refs: [TileRef] = []
            for entry in frameEntries {
                let ref = deduplicateTile(entry.tile, uniqueTiles: &uniqueTiles, lookup: &lookup)
                refs.append(TileRef(index: ref.index, flipH: ref.flipH != entry.flipH, flipV: ref.flipV != entry.flipV))
            }
            tileRefsByFrame.append(refs)
        }

        // Generate meta-sprite frames — center on SNES screen (256x224)
        var spriteFrames: [SpriteFrame] = []
        let screenCenterX = 128  // 256 / 2
        let screenCenterY = 112  // 224 / 2
        let centerX = paddedW / 2
        let centerY = paddedH / 2
        var maxOAM = 0
        var warnings: [String] = []

        for (frameIdx, refs) in tileRefsByFrame.enumerated() {
            var oamEntries: [OAMEntry] = []
            let frameGridEntries = allRawTiles[frameIdx]

            for (i, ref) in refs.enumerated() {
                let gridEntry = frameGridEntries[i]
                // Skip fully transparent tiles
                if isTransparentTile(uniqueTiles[ref.index]) { continue }

                let px = screenCenterX + (gridEntry.gridX * 8 - centerX)
                let py = screenCenterY + (gridEntry.gridY * 8 - centerY)

                oamEntries.append(OAMEntry(
                    x: px,
                    y: py,
                    tileIndex: ref.index,
                    paletteIndex: 0,  // Will be set during import
                    priority: 2,
                    flipH: ref.flipH,
                    flipV: ref.flipV,
                    size: .small8x8
                ))
            }

            maxOAM = max(maxOAM, oamEntries.count)
            spriteFrames.append(SpriteFrame(entries: oamEntries, duration: config.frameDuration))

            if oamEntries.count > 128 {
                warnings.append("Frame \(frameIdx): \(oamEntries.count) OAM entries (max 128)")
            }
            if oamEntries.count > 32 {
                warnings.append("Frame \(frameIdx): \(oamEntries.count) sprites may cause scanline overflow (32/line)")
            }
        }

        let dedupRatio = rawTileCount > 0 ? 1.0 - Double(uniqueTiles.count) / Double(rawTileCount) : 0

        let snPalette = SNESPalette(name: config.animName, colors: palette)
        let animation = SpriteAnimation(name: config.animName, frames: spriteFrames, loop: true)

        let stats = ImportStats(
            totalFrames: rawFrames.count,
            rawTileCount: rawTileCount,
            uniqueTileCount: uniqueTiles.count,
            dedupRatio: dedupRatio,
            colorsFound: colorsFound,
            oamPerFrame: maxOAM,
            warnings: warnings
        )

        return SpriteSheetImportResult(palette: snPalette, tiles: uniqueTiles, frames: spriteFrames, animation: animation, stats: stats)
    }

    // MARK: - Step 1: Extract pixels

    private static func extractPixels(from image: CGImage) -> (rgba: [UInt8], width: Int, height: Int) {
        let w = image.width
        let h = image.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Un-premultiply alpha
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let a = rgba[i + 3]
            if a > 0 && a < 255 {
                rgba[i]     = UInt8(min(255, Int(rgba[i]) * 255 / Int(a)))
                rgba[i + 1] = UInt8(min(255, Int(rgba[i + 1]) * 255 / Int(a)))
                rgba[i + 2] = UInt8(min(255, Int(rgba[i + 2]) * 255 / Int(a)))
            }
        }
        return (rgba, w, h)
    }

    // MARK: - Step 2: Cut frames

    private static func cutFrames(rgba: [UInt8], imageWidth: Int, imageHeight: Int, frameWidth: Int, frameHeight: Int) -> [[UInt8]] {
        let cols = imageWidth / frameWidth
        let rows = imageHeight / frameHeight
        var frames: [[UInt8]] = []

        for row in 0..<rows {
            for col in 0..<cols {
                var frame = [UInt8](repeating: 0, count: frameWidth * frameHeight * 4)
                for y in 0..<frameHeight {
                    let srcY = row * frameHeight + y
                    let srcOffset = (srcY * imageWidth + col * frameWidth) * 4
                    let dstOffset = y * frameWidth * 4
                    frame.replaceSubrange(dstOffset..<(dstOffset + frameWidth * 4), with: rgba[srcOffset..<(srcOffset + frameWidth * 4)])
                }
                frames.append(frame)
            }
        }
        return frames
    }

    // MARK: - Step 3: Quantize colors (Median Cut)

    private static func quantizeColors(frames: [[UInt8]], frameWidth: Int, frameHeight: Int, maxColors: Int) -> (palette: [SNESColor], indexedFrames: [[UInt8]], colorsFound: Int) {
        // Build histogram of 5-bit RGB colors (frequency-weighted)
        var histogram: [RGBPixel: Int] = [:]

        for frame in frames {
            for i in stride(from: 0, to: frame.count, by: 4) {
                let a = frame[i + 3]
                if a < 128 { continue }  // Transparent
                let p = RGBPixel(
                    r: UInt8(Int(frame[i]) >> 3),      // 8-bit → 5-bit
                    g: UInt8(Int(frame[i + 1]) >> 3),
                    b: UInt8(Int(frame[i + 2]) >> 3)
                )
                histogram[p, default: 0] += 1
            }
        }

        let colorsFound = histogram.count
        let weightedColors = histogram.map { WeightedColor(color: $0.key, count: $0.value) }

        // Median Cut with frequency weighting
        var buckets = [Bucket(colors: weightedColors)]
        while buckets.count < maxColors {
            let candidates = buckets.enumerated().filter { $0.element.colors.count > 1 }
            guard let idx = candidates.max(by: { $0.element.maxRange < $1.element.maxRange })?.offset else { break }
            let (a, b) = buckets[idx].split()
            if a.colors.isEmpty || b.colors.isEmpty { break }
            buckets.remove(at: idx)
            buckets.append(a)
            buckets.append(b)
        }

        // Build palette: index 0 = transparent (black)
        var palette: [SNESColor] = [SNESColor.black]  // Transparent slot
        var centroids: [RGBPixel] = []
        for bucket in buckets {
            let c = bucket.centroid
            centroids.append(c)
            palette.append(SNESColor(r: Int(c.r), g: Int(c.g), b: Int(c.b)))
        }
        // Pad to 16
        while palette.count < 16 { palette.append(.black) }
        palette = Array(palette.prefix(16))

        // Map each frame's pixels to palette indices
        var indexedFrames: [[UInt8]] = []
        for frame in frames {
            let pixelCount = frameWidth * frameHeight
            var indexed = [UInt8](repeating: 0, count: pixelCount)
            for p in 0..<pixelCount {
                let offset = p * 4
                let a = frame[offset + 3]
                if a < 128 {
                    indexed[p] = 0  // Transparent
                    continue
                }
                let pr = Int(frame[offset]) >> 3
                let pg = Int(frame[offset + 1]) >> 3
                let pb = Int(frame[offset + 2]) >> 3

                // Find closest centroid
                var bestIdx = 0
                var bestDist = Int.max
                for (ci, c) in centroids.enumerated() {
                    let dr = pr - Int(c.r)
                    let dg = pg - Int(c.g)
                    let db = pb - Int(c.b)
                    let dist = dr * dr + dg * dg + db * db
                    if dist < bestDist {
                        bestDist = dist
                        bestIdx = ci
                    }
                }
                indexed[p] = UInt8(bestIdx + 1)  // +1 because index 0 = transparent
            }
            indexedFrames.append(indexed)
        }

        return (palette, indexedFrames, colorsFound)
    }

    // MARK: - Step 4: Decompose into 8x8 tiles

    private struct TileGridEntry {
        var tile: SNESTile
        var gridX: Int
        var gridY: Int
        var flipH: Bool = false
        var flipV: Bool = false
    }

    private static func decomposeIntoTiles(indexed: [UInt8], frameWidth: Int, frameHeight: Int, paddedWidth: Int, paddedHeight: Int, depth: TileDepth, category: String = "") -> [TileGridEntry] {
        let tilesX = paddedWidth / 8
        let tilesY = paddedHeight / 8
        var entries: [TileGridEntry] = []

        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                var pixels = [UInt8](repeating: 0, count: 64)
                for py in 0..<8 {
                    for px in 0..<8 {
                        let srcX = tx * 8 + px
                        let srcY = ty * 8 + py
                        if srcX < frameWidth && srcY < frameHeight {
                            pixels[py * 8 + px] = indexed[srcY * frameWidth + srcX]
                        }
                    }
                }
                let tile = SNESTile(pixels: pixels, depth: depth, category: category)
                entries.append(TileGridEntry(tile: tile, gridX: tx, gridY: ty))
            }
        }
        return entries
    }

    // MARK: - Step 5: Deduplicate tiles

    private static func tilePixelData(_ tile: SNESTile) -> Data {
        Data(tile.pixels)
    }

    private static func deduplicateTile(_ tile: SNESTile, uniqueTiles: inout [SNESTile], lookup: inout [Data: (index: Int, flipH: Bool, flipV: Bool)]) -> (index: Int, flipH: Bool, flipV: Bool) {
        // Test 4 orientations: normal, flipH, flipV, flipHV
        let variants: [(SNESTile, Bool, Bool)] = [
            (tile, false, false),
            (tile.flippedHorizontally(), true, false),
            (tile.flippedVertically(), false, true),
            (tile.flippedHorizontally().flippedVertically(), true, true),
        ]

        for (variant, fh, fv) in variants {
            let data = tilePixelData(variant)
            if let existing = lookup[data] {
                // The variant matched, so the original tile needs these flips to recreate
                return (index: existing.index, flipH: fh, flipV: fv)
            }
        }

        // No match found — add as new unique tile
        let index = uniqueTiles.count
        let data = tilePixelData(tile)
        lookup[data] = (index: index, flipH: false, flipV: false)
        uniqueTiles.append(tile)
        return (index: index, flipH: false, flipV: false)
    }

    // MARK: - Helpers

    private static func isTransparentTile(_ tile: SNESTile) -> Bool {
        tile.pixels.allSatisfy { $0 == 0 }
    }
}
