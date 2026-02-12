import Foundation

// MARK: - Enums

enum ZoneType: String, Codable, CaseIterable, Identifiable {
    case overworld   = "Overworld"
    case sidescroll  = "Sidescroll"
    case roomBased   = "Room-based"
    case fixed       = "Fixed Screen"

    var id: String { rawValue }
}

enum TransitionType: String, Codable, CaseIterable, Identifiable {
    case scrollH  = "Scroll H"
    case scrollV  = "Scroll V"
    case fadeBlack = "Fade Black"
    case fadeWhite = "Fade White"
    case irisOut  = "Iris Out"
    case irisIn   = "Iris In"
    case mosaic   = "Mosaic"
    case instant  = "Instant"
    case door     = "Door"

    var id: String { rawValue }

    var defaultDurationFrames: Int {
        switch self {
        case .scrollH, .scrollV: return 30
        case .fadeBlack, .fadeWhite: return 16
        case .irisOut, .irisIn: return 20
        case .mosaic: return 24
        case .instant: return 0
        case .door: return 12
        }
    }
}

// MARK: - World Zone

struct WorldZone: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: ZoneType
    var bgMode: Int  // 0-7
    var gridWidth: Int
    var gridHeight: Int
    var sharedTileIndices: [Int]
    var colorHex: String

    static func empty() -> WorldZone {
        WorldZone(name: "Zone 1", type: .overworld, bgMode: 1,
                  gridWidth: 4, gridHeight: 4, sharedTileIndices: [], colorHex: "9B6DFF")
    }
}

// MARK: - Screen Entity

struct ScreenEntity: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var typeName: String
    var x: Int
    var y: Int
    var properties: [String: String]
    var spriteIndex: Int?
}

// MARK: - Screen Exit

struct ScreenExit: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var targetScreenID: UUID?
    var transitionType: TransitionType
}

// MARK: - World Screen

struct WorldScreen: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var zoneID: UUID
    var gridX: Int
    var gridY: Int
    var layers: [ParallaxLayer]
    var entities: [ScreenEntity]
    var exits: [ScreenExit]

    init(id: UUID = UUID(), name: String, zoneID: UUID, gridX: Int, gridY: Int,
         layers: [ParallaxLayer], entities: [ScreenEntity], exits: [ScreenExit]) {
        self.id = id
        self.name = name
        self.zoneID = zoneID
        self.gridX = gridX
        self.gridY = gridY
        self.layers = layers
        self.entities = entities
        self.exits = exits
    }

    static func empty(zoneID: UUID, gridX: Int = 0, gridY: Int = 0, bgMode: Int = 1,
                       widthTiles: Int = 128, heightTiles: Int = 28) -> WorldScreen {
        let layers = SNESLevel.createLayers(bgMode: bgMode, widthTiles: widthTiles, heightTiles: heightTiles)
        return WorldScreen(name: "Screen", zoneID: zoneID, gridX: gridX, gridY: gridY,
                           layers: layers, entities: [], exits: [])
    }

    // MARK: - Migration from old format (tilemapID-based)

    enum CodingKeys: String, CodingKey {
        case id, name, zoneID, gridX, gridY, layers, entities, exits
        case tilemapID // legacy key for migration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        zoneID = try container.decode(UUID.self, forKey: .zoneID)
        gridX = try container.decode(Int.self, forKey: .gridX)
        gridY = try container.decode(Int.self, forKey: .gridY)
        entities = try container.decode([ScreenEntity].self, forKey: .entities)
        exits = try container.decode([ScreenExit].self, forKey: .exits)

        if let existingLayers = try? container.decode([ParallaxLayer].self, forKey: .layers) {
            layers = existingLayers
        } else {
            // Legacy migration: create default layers
            layers = SNESLevel.createLayers(bgMode: 1, widthTiles: 128, heightTiles: 28)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(zoneID, forKey: .zoneID)
        try container.encode(gridX, forKey: .gridX)
        try container.encode(gridY, forKey: .gridY)
        try container.encode(layers, forKey: .layers)
        try container.encode(entities, forKey: .entities)
        try container.encode(exits, forKey: .exits)
    }
}

// MARK: - World Transition

struct WorldTransition: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: TransitionType
    var fromScreenID: UUID?
    var toScreenID: UUID?
    var durationFrames: Int
    var preloadTileIndices: [Int]

    static func empty() -> WorldTransition {
        WorldTransition(name: "Transition", type: .fadeBlack, durationFrames: 16, preloadTileIndices: [])
    }
}
