import SwiftUI

/// SNES BGR555 color: 0BBBBBGGGGGRRRRR (15-bit, stored in UInt16)
struct SNESColor: Equatable, Codable, Hashable {
    var raw: UInt16

    init(raw: UInt16) {
        self.raw = raw & 0x7FFF
    }

    init(r: Int, g: Int, b: Int) {
        let rc = UInt16(min(max(r, 0), 31))
        let gc = UInt16(min(max(g, 0), 31))
        let bc = UInt16(min(max(b, 0), 31))
        self.raw = rc | (gc << 5) | (bc << 10)
    }

    var red: Int   { Int(raw & 0x1F) }
    var green: Int { Int((raw >> 5) & 0x1F) }
    var blue: Int  { Int((raw >> 10) & 0x1F) }

    var color: Color {
        Color(
            red: Double(red) / 31.0,
            green: Double(green) / 31.0,
            blue: Double(blue) / 31.0
        )
    }

    var nsColor: NSColor {
        NSColor(
            red: CGFloat(red) / 31.0,
            green: CGFloat(green) / 31.0,
            blue: CGFloat(blue) / 31.0,
            alpha: 1.0
        )
    }

    var hexString: String {
        String(format: "$%04X", raw)
    }

    // MARK: - Presets
    static let black = SNESColor(r: 0, g: 0, b: 0)
    static let white = SNESColor(r: 31, g: 31, b: 31)
    static let red = SNESColor(r: 31, g: 0, b: 0)
    static let green = SNESColor(r: 0, g: 31, b: 0)
    static let blue = SNESColor(r: 0, g: 0, b: 31)

    static let snesDefaultPalette: [SNESColor] = [
        SNESColor(r: 0,  g: 0,  b: 0),   // 0 - Black (transparent)
        SNESColor(r: 31, g: 31, b: 31),  // 1 - White
        SNESColor(r: 31, g: 0,  b: 0),   // 2 - Red
        SNESColor(r: 0,  g: 31, b: 0),   // 3 - Green
        SNESColor(r: 0,  g: 0,  b: 31),  // 4 - Blue
        SNESColor(r: 31, g: 31, b: 0),   // 5 - Yellow
        SNESColor(r: 0,  g: 31, b: 31),  // 6 - Cyan
        SNESColor(r: 31, g: 0,  b: 31),  // 7 - Magenta
        SNESColor(r: 16, g: 16, b: 16),  // 8 - Gray
        SNESColor(r: 20, g: 10, b: 5),   // 9 - Brown
        SNESColor(r: 31, g: 16, b: 0),   // 10 - Orange
        SNESColor(r: 16, g: 31, b: 16),  // 11 - Light green
        SNESColor(r: 16, g: 16, b: 31),  // 12 - Light blue
        SNESColor(r: 24, g: 16, b: 24),  // 13 - Light purple
        SNESColor(r: 24, g: 24, b: 16),  // 14 - Cream
        SNESColor(r: 8,  g: 8,  b: 8),   // 15 - Dark gray
    ]
}
