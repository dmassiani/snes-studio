import Foundation

struct TilemapEntry: Equatable, Codable {
    var tileIndex: Int = 0
    var paletteIndex: Int = 0
    var flipH: Bool = false
    var flipV: Bool = false
    var priority: Bool = false
}

struct SNESTilemap: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var width: Int   // in tiles
    var height: Int  // in tiles
    var entries: [TilemapEntry]

    init(name: String, width: Int, height: Int, entries: [TilemapEntry]? = nil) {
        self.name = name
        self.width = width
        self.height = height
        self.entries = entries ?? Array(repeating: TilemapEntry(), count: width * height)
    }

    func entry(x: Int, y: Int) -> TilemapEntry {
        guard x >= 0, x < width, y >= 0, y < height else { return TilemapEntry() }
        return entries[y * width + x]
    }

    mutating func setEntry(x: Int, y: Int, entry: TilemapEntry) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        entries[y * width + x] = entry
    }

    /// Resize preserving existing tile data
    mutating func resize(newWidth: Int, newHeight: Int) {
        guard newWidth > 0, newHeight > 0, (newWidth != width || newHeight != height) else { return }
        var newEntries = Array(repeating: TilemapEntry(), count: newWidth * newHeight)
        let copyW = min(width, newWidth)
        let copyH = min(height, newHeight)
        for y in 0..<copyH {
            for x in 0..<copyW {
                newEntries[y * newWidth + x] = entries[y * width + x]
            }
        }
        width = newWidth
        height = newHeight
        entries = newEntries
    }

    static func empty(width: Int = 32, height: Int = 32) -> SNESTilemap {
        SNESTilemap(name: "Tilemap", width: width, height: height)
    }
}
