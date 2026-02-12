import CoreGraphics
import AppKit

enum BGSnapshotRenderer {
    /// Render BG layers into a 256x224 CGImage for use as sprite drawing backdrop.
    /// Uses tilemaps, tiles, and palettes from AssetStore.
    static func render(
        tilemaps: [SNESTilemap],
        tiles: [SNESTile],
        palettes: [SNESPalette]
    ) -> CGImage? {
        let width = 256
        let height = 224
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Render each tilemap layer back-to-front
        for tilemap in tilemaps {
            let mapW = tilemap.width
            let mapH = tilemap.height

            for mapY in 0..<min(mapH, height / 8) {
                for mapX in 0..<min(mapW, width / 8) {
                    let cellIndex = mapY * mapW + mapX
                    guard cellIndex < tilemap.entries.count else { continue }
                    let cell = tilemap.entries[cellIndex]
                    guard cell.tileIndex < tiles.count else { continue }
                    let tile = tiles[cell.tileIndex]
                    let palIdx = min(cell.paletteIndex, palettes.count - 1)
                    let pal = palettes[palIdx]

                    for py in 0..<8 {
                        for px in 0..<8 {
                            let srcX = cell.flipH ? (7 - px) : px
                            let srcY = cell.flipV ? (7 - py) : py
                            let colorIdx = Int(tile.pixel(x: srcX, y: srcY))
                            if colorIdx == 0 { continue }

                            let screenX = mapX * 8 + px
                            let screenY = mapY * 8 + py
                            guard screenX < width, screenY < height else { continue }

                            let snesColor = pal[colorIdx]
                            let offset = (screenY * width + screenX) * bytesPerPixel
                            buffer[offset]     = UInt8(snesColor.red * 255 / 31)
                            buffer[offset + 1] = UInt8(snesColor.green * 255 / 31)
                            buffer[offset + 2] = UInt8(snesColor.blue * 255 / 31)
                            buffer[offset + 3] = 255
                        }
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return context.makeImage()
    }
}
