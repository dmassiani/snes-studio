import Foundation

/// Result of loading assets from disk — reports what was loaded, missing, or errored.
struct AssetLoadResult {
    var loaded: [String] = []
    var missing: [String] = []
    var errors: [(String, String)] = []
    var directoryExists: Bool = true
}

/// Manages persistence of visual editor assets (palettes, tiles, tilemaps, sprites, controller mapping).
/// Assets are stored as separate JSON files in the project's `assets/` directory.
@Observable
final class AssetStore {
    var palettes: [SNESPalette] = SNESPalette.defaultPalettes()
    var tiles: [SNESTile] = [.empty()]
    var tilemaps: [SNESTilemap] = [.empty()]
    var spriteEntries: [OAMEntry] = []
    var metaSprites: [MetaSprite] = []
    var controllerMapping: ControllerMapping = ControllerMapping()
    var worldZones: [WorldZone] = []
    var worldScreens: [WorldScreen] = []
    var worldTransitions: [WorldTransition] = []
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Load

    @discardableResult
    func load(from assetsDir: URL) -> AssetLoadResult {
        var result = AssetLoadResult()
        let fm = FileManager.default

        guard fm.fileExists(atPath: assetsDir.path) else {
            result.directoryExists = false
            return result
        }

        palettes = loadFileLogged("palettes.json", from: assetsDir, result: &result) ?? SNESPalette.defaultPalettes()
        tiles = loadFileLogged("tiles.json", from: assetsDir, result: &result) ?? [.empty()]
        tilemaps = loadFileLogged("tilemaps.json", from: assetsDir, result: &result) ?? [.empty()]
        spriteEntries = loadFileLogged("sprites.json", from: assetsDir, result: &result) ?? []

        // Load metasprites.json, with fallback migration from animations.json
        if let loaded: [MetaSprite] = loadFileLogged("metasprites.json", from: assetsDir, result: &result) {
            metaSprites = loaded
        } else {
            // Try migrating from legacy animations.json
            let legacyAnims: [SpriteAnimation]? = loadFileLogged("animations.json", from: assetsDir, result: &result)
            if let anims = legacyAnims, !anims.isEmpty {
                metaSprites = anims.map { anim in
                    MetaSprite(name: anim.name, animations: [anim])
                }
            } else {
                metaSprites = []
            }
        }
        controllerMapping = loadFileLogged("controller.json", from: assetsDir, result: &result) ?? ControllerMapping()
        worldZones = loadFileLogged("world_zones.json", from: assetsDir, result: &result) ?? []
        worldScreens = loadFileLogged("world_screens.json", from: assetsDir, result: &result) ?? []
        worldTransitions = loadFileLogged("world_transitions.json", from: assetsDir, result: &result) ?? []

        return result
    }

    // MARK: - Save

    func save(to assetsDir: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: assetsDir.path) {
            try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        }

        try saveFile(palettes, to: assetsDir.appendingPathComponent("palettes.json"))
        try saveFile(tiles, to: assetsDir.appendingPathComponent("tiles.json"))
        try saveFile(tilemaps, to: assetsDir.appendingPathComponent("tilemaps.json"))
        try saveFile(spriteEntries, to: assetsDir.appendingPathComponent("sprites.json"))
        try saveFile(metaSprites, to: assetsDir.appendingPathComponent("metasprites.json"))
        try saveFile(controllerMapping, to: assetsDir.appendingPathComponent("controller.json"))
        try saveFile(worldZones, to: assetsDir.appendingPathComponent("world_zones.json"))
        try saveFile(worldScreens, to: assetsDir.appendingPathComponent("world_screens.json"))
        try saveFile(worldTransitions, to: assetsDir.appendingPathComponent("world_transitions.json"))
    }

    // MARK: - Reset

    func reset() {
        palettes = SNESPalette.defaultPalettes()
        tiles = [.empty()]
        tilemaps = [.empty()]
        spriteEntries = []
        metaSprites = []
        controllerMapping = ControllerMapping()
        worldZones = []
        worldScreens = []
        worldTransitions = []
    }

    // MARK: - Private helpers

    private func loadFileLogged<T: Decodable>(_ filename: String, from dir: URL, result: inout AssetLoadResult) -> T? {
        let url = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            result.missing.append(filename)
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let value = try decoder.decode(T.self, from: data)
            result.loaded.append(filename)
            return value
        } catch {
            result.errors.append((filename, error.localizedDescription))
            return nil
        }
    }

    private func saveFile<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
