import SwiftUI

struct FileReference {
    let file: String
    let line: Int
    let column: Int
}

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: MessageType
    let text: String
    var fileRef: FileReference? = nil

    enum MessageType {
        case info
        case success
        case error
        case warning
        case command

        var prefix: String {
            switch self {
            case .info:    return ">"
            case .success: return "OK"
            case .error:   return "ERR"
            case .warning: return "WARN"
            case .command: return "$"
            }
        }

        var color: Color {
            switch self {
            case .info:    return SNESTheme.textSecondary
            case .success: return SNESTheme.success
            case .error:   return SNESTheme.danger
            case .warning: return SNESTheme.warning
            case .command: return SNESTheme.info
            }
        }
    }

    var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}
