import Foundation

// MARK: - Build Settings

struct BuildSettings: Codable, Equatable {
    var outputFormat: String = "sfc"
    var outputName: String = "game"
    var generateDebugSymbols: Bool = true
    var generateMapFile: Bool = false
    var fixChecksum: Bool = true
}

// MARK: - SNES Project

struct SNESProject: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var author: String = ""
    var version: String = "0.1.0"
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var cartridge: CartridgeConfig
    var buildSettings: BuildSettings = BuildSettings()
    var sourceFiles: [String] = []
    var assetFiles: [String] = []

    // Not serialized — set at load time
    var projectPath: URL? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, author, version, createdDate, modifiedDate
        case cartridge, buildSettings, sourceFiles, assetFiles
    }

    // MARK: - Computed paths

    var projectFileURL: URL? {
        projectPath?.appendingPathComponent("\(name).snesproj")
    }

    var buildDirectoryURL: URL? {
        projectPath?.appendingPathComponent("build")
    }

    var sourceDirectoryURL: URL? {
        projectPath?.appendingPathComponent("src")
    }

    var assetsDirectoryURL: URL? {
        projectPath?.appendingPathComponent("assets")
    }

    var linkerConfigURL: URL? {
        projectPath?.appendingPathComponent(cartridge.linkerConfigName)
    }
}
