import Foundation

enum TileDepth: Int, CaseIterable, Codable {
    case bpp2 = 2
    case bpp4 = 4
    case bpp8 = 8

    var label: String {
        switch self {
        case .bpp2: return "2bpp"
        case .bpp4: return "4bpp"
        case .bpp8: return "8bpp"
        }
    }

    var maxColorIndex: Int {
        (1 << rawValue) - 1
    }
}

struct SNESTile: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var pixels: [UInt8]  // 64 values (8x8), each is an index into the palette
    var depth: TileDepth
    var category: String = ""

    init(pixels: [UInt8], depth: TileDepth, category: String = "") {
        var p = pixels
        while p.count < 64 { p.append(0) }
        self.pixels = Array(p.prefix(64))
        self.depth = depth
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pixels = try container.decode([UInt8].self, forKey: .pixels)
        depth = try container.decode(TileDepth.self, forKey: .depth)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
    }

    func pixel(x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < 8, y >= 0, y < 8 else { return 0 }
        return pixels[y * 8 + x]
    }

    mutating func setPixel(x: Int, y: Int, value: UInt8) {
        guard x >= 0, x < 8, y >= 0, y < 8 else { return }
        let clamped = min(value, UInt8(depth.maxColorIndex))
        pixels[y * 8 + x] = clamped
    }

    static func empty(depth: TileDepth = .bpp4, category: String = "") -> SNESTile {
        SNESTile(pixels: Array(repeating: 0, count: 64), depth: depth, category: category)
    }

    // MARK: - Transforms

    func flippedHorizontally() -> SNESTile {
        var result = SNESTile(pixels: pixels, depth: depth)
        result.id = id
        for y in 0..<8 {
            for x in 0..<8 {
                result.pixels[y * 8 + (7 - x)] = pixels[y * 8 + x]
            }
        }
        return result
    }

    func flippedVertically() -> SNESTile {
        var result = SNESTile(pixels: pixels, depth: depth)
        result.id = id
        for y in 0..<8 {
            for x in 0..<8 {
                result.pixels[(7 - y) * 8 + x] = pixels[y * 8 + x]
            }
        }
        return result
    }

    func rotatedClockwise() -> SNESTile {
        var result = SNESTile(pixels: pixels, depth: depth)
        result.id = id
        for y in 0..<8 {
            for x in 0..<8 {
                result.pixels[x * 8 + (7 - y)] = pixels[y * 8 + x]
            }
        }
        return result
    }

    func shifted(dx: Int, dy: Int) -> SNESTile {
        var result = SNESTile(pixels: Array(repeating: 0, count: 64), depth: depth)
        result.id = id
        for y in 0..<8 {
            for x in 0..<8 {
                let srcX = ((x - dx) % 8 + 8) % 8
                let srcY = ((y - dy) % 8 + 8) % 8
                result.pixels[y * 8 + x] = pixels[srcY * 8 + srcX]
            }
        }
        return result
    }
}
