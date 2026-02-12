import SwiftUI

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - SNES Studio Theme

enum SNESTheme {
    // MARK: Backgrounds
    static let bgMain       = Color(hex: "0D0F12")
    static let bgPanel      = Color(hex: "13161B")
    static let bgEditor     = Color(hex: "1A1D23")
    static let bgConsole    = Color(hex: "0A0C0F")

    // MARK: Borders
    static let border       = Color(hex: "2A2E36")

    // MARK: Text
    static let textPrimary    = Color(hex: "E8ECF1")
    static let textSecondary  = Color(hex: "8B92A0")
    static let textDisabled   = Color(hex: "4A5060")

    // MARK: Feedback
    static let success = Color(hex: "4AFF9B")
    static let warning = Color(hex: "FFD04A")
    static let danger  = Color(hex: "FF4A6A")
    static let info    = Color(hex: "4A9EFF")

    // MARK: Fonts
    static let codeFontSize: CGFloat = 12
    static let codeFont = Font.system(size: codeFontSize, design: .monospaced)

    // MARK: Layout Constants
    static let sidebarDefaultWidth: CGFloat = 220
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarMaxWidth: CGFloat = 320
    static let sidebarCompactWidth: CGFloat = 48

    static let rightPanelDefaultWidth: CGFloat = 280
    static let rightPanelMinWidth: CGFloat = 200
    static let rightPanelMaxWidth: CGFloat = 400

    static let hardwareBarHeight: CGFloat = 80
    static let consoleDefaultHeight: CGFloat = 120
    static let tabBarHeight: CGFloat = 36
    static let toolbarHeight: CGFloat = 38

    static let windowMinWidth: CGFloat = 1024
    static let windowMinHeight: CGFloat = 700

    static let resizeHandleWidth: CGFloat = 3
    static let resizeHitArea: CGFloat = 6
}
