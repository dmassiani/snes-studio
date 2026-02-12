import SwiftUI

enum PyramidLevel: Int, CaseIterable, Identifiable, Codable {
    case atelier = 1
    case orchestre = 2
    case logique = 3
    case hardware = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .hardware: "HARDWARE"
        case .atelier:  "ATELIER"
        case .orchestre: "ORCHESTRE"
        case .logique:  "LOGIQUE"
        }
    }

    var subtitle: String {
        switch self {
        case .hardware: "Contraintes"
        case .atelier:  "Ressources"
        case .orchestre: "Orchestration"
        case .logique:  "Code"
        }
    }

    var accent: Color {
        switch self {
        case .hardware: Color(hex: "4AFF9B")
        case .atelier:  Color(hex: "FF8A4A")
        case .orchestre: Color(hex: "9B6DFF")
        case .logique:  Color(hex: "4A9EFF")
        }
    }

    var accentBg: Color {
        switch self {
        case .hardware: Color(hex: "4AFF9B").opacity(0.08)
        case .atelier:  Color(hex: "FF8A4A").opacity(0.08)
        case .orchestre: Color(hex: "9B6DFF").opacity(0.08)
        case .logique:  Color(hex: "4A9EFF").opacity(0.08)
        }
    }

    /// Keyboard shortcut number (Cmd+1 = hardware, Cmd+4 = logique)
    var shortcutNumber: Int { rawValue }
}
