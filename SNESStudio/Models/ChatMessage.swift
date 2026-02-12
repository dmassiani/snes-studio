import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let role: Role
    var content: String
    var toolCalls: [ToolCall] = []

    enum Role {
        case user
        case assistant
        case system
        case toolResult
    }

    var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: timestamp)
    }
}

// MARK: - Tool Call

struct ToolCall: Identifiable {
    let id: String
    let name: String
    let input: [String: Any]
    var result: String?
    var isSuccess: Bool = true
}

// MARK: - Active Editor

enum ActiveEditor: String {
    case code
    case palette = "palettes"
    case tile = "tiles"
    case tilemap = "tilemaps"
    case sprite = "sprites"
    case controller = "controleur"
    case world = "monde"
    case registers = "registres"
    case memory = "memoire"
    case vram = "vram"
    case layers = "couches_bg"
    case romAnalyzer = "rom_analyzer"
    case cartridge = "cartouche"
    case none
}

// MARK: - Chat Context

struct ChatContext {
    var cartridgeConfig: CartridgeConfig?
    var activeFileName: String?
    var activeFileContent: String?
    var lastBuildErrors: [String]?
    var activeEditor: ActiveEditor = .none
    var editorSummary: String?
}
