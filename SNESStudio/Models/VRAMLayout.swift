import Foundation

enum VRAMCategory: String, CaseIterable, Identifiable, Codable {
    case bg1Tiles   = "BG1 Tiles"
    case bg2Tiles   = "BG2 Tiles"
    case bg3Tiles   = "BG3 Tiles"
    case spriteTiles = "Sprite Tiles"
    case bg1Map     = "BG1 Map"
    case bg2Map     = "BG2 Map"
    case bg3Map     = "BG3 Map"
    case free       = "Free"

    var id: String { rawValue }

    var colorHex: String {
        switch self {
        case .bg1Tiles:    return "4A9EFF"
        case .bg2Tiles:    return "9B6DFF"
        case .bg3Tiles:    return "FF8A4A"
        case .spriteTiles: return "FF4A6A"
        case .bg1Map:      return "4AFF9B"
        case .bg2Map:      return "A0FF4A"
        case .bg3Map:      return "FFD04A"
        case .free:        return "2A2E36"
        }
    }
}

struct VRAMBlock: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var label: String
    var address: Int      // word address (0-32767)
    var sizeBytes: Int
    var category: VRAMCategory
}

struct VRAMBudget: Equatable {
    var blocks: [VRAMBlock]
    let totalBytes: Int = 65536  // 64 KB

    var usedBytes: Int {
        blocks.filter { $0.category != .free }.reduce(0) { $0 + $1.sizeBytes }
    }

    var freeBytes: Int {
        totalBytes - usedBytes
    }

    var percentage: Double {
        Double(usedBytes) / Double(totalBytes) * 100.0
    }

    var isOverBudget: Bool {
        usedBytes > totalBytes
    }

    static func empty() -> VRAMBudget {
        VRAMBudget(blocks: [
            VRAMBlock(label: "Free", address: 0, sizeBytes: 65536, category: .free)
        ])
    }
}

struct TransitionCost: Equatable {
    let tilesToRemove: Int
    let tilesToLoad: Int
    let bytesToTransfer: Int
    let framesNeeded: Int

    var isFeasible: Bool {
        // Can transfer ~7KB per VBlank via DMA
        framesNeeded <= 4
    }
}
