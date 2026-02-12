import SwiftUI

// MARK: - Controller body shape

struct ControllerBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width
            let h = rect.height
            let r: CGFloat = 20

            // Rounded rectangle with grips
            p.move(to: CGPoint(x: r, y: 0))
            p.addLine(to: CGPoint(x: w - r, y: 0))
            p.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: w, y: h * 0.6))
            // Right grip
            p.addQuadCurve(to: CGPoint(x: w - 20, y: h), control: CGPoint(x: w + 10, y: h * 0.85))
            p.addLine(to: CGPoint(x: 20, y: h))
            // Left grip
            p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.6), control: CGPoint(x: -10, y: h * 0.85))
            p.addLine(to: CGPoint(x: 0, y: r))
            p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
        }
    }
}

// MARK: - DPad shape

struct DPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let armW = w / 3

        return Path { p in
            // Horizontal bar
            p.addRoundedRect(in: CGRect(x: 0, y: h / 3, width: w, height: armW), cornerSize: CGSize(width: 2, height: 2))
            // Vertical bar
            p.addRoundedRect(in: CGRect(x: w / 3, y: 0, width: armW, height: h), cornerSize: CGSize(width: 2, height: 2))
        }
    }
}

// MARK: - SNES Colors

enum SNESControllerColors {
    static let body = Color(hex: "C8C4BE")      // Classic gray
    static let bodyDark = Color(hex: "A8A4A0")   // Darker gray for depth
    static let dpad = Color(hex: "2C2C2C")        // Dark/black DPad
    static let buttonA = Color(hex: "9B3B5B")     // Reddish-purple
    static let buttonB = Color(hex: "C4B645")     // Yellow-green
    static let buttonX = Color(hex: "4B6FA5")     // Blue
    static let buttonY = Color(hex: "4A8C4A")     // Green
    static let bumper = Color(hex: "6B6B6B")      // Gray bumpers
    static let startSelect = Color(hex: "4A4A4A") // Dark gray
}
