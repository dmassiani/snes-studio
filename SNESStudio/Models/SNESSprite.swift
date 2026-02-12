import Foundation

enum SpriteSize: String, CaseIterable, Codable {
    case small8x8
    case large16x16
    case large32x32
    case large64x64

    var label: String {
        switch self {
        case .small8x8:   return "8x8"
        case .large16x16: return "16x16"
        case .large32x32: return "32x32"
        case .large64x64: return "64x64"
        }
    }

    var pixelSize: Int {
        switch self {
        case .small8x8:   return 8
        case .large16x16: return 16
        case .large32x32: return 32
        case .large64x64: return 64
        }
    }
}

struct OAMEntry: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var x: Int = 0
    var y: Int = 0
    var tileIndex: Int = 0
    var paletteIndex: Int = 0
    var priority: Int = 0  // 0-3
    var flipH: Bool = false
    var flipV: Bool = false
    var size: SpriteSize = .small8x8
}

struct SpriteFrame: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var entries: [OAMEntry] = []
    var duration: Int = 4  // in VBlanks
}

struct SpriteAnimation: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var frames: [SpriteFrame] = []
    var loop: Bool = true
}

struct MetaSprite: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var animations: [SpriteAnimation] = []
}
