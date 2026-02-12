import Foundation

struct SNESPalette: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var colors: [SNESColor]

    init(name: String, colors: [SNESColor]) {
        self.name = name
        // Ensure exactly 16 colors
        var c = colors
        while c.count < 16 { c.append(.black) }
        self.colors = Array(c.prefix(16))
    }

    subscript(index: Int) -> SNESColor {
        get { colors[index] }
        set { colors[index] = newValue }
    }

    static func defaultPalettes() -> [SNESPalette] {
        var palettes: [SNESPalette] = []
        // First palette uses SNES default colors
        palettes.append(SNESPalette(name: "Palette 0", colors: SNESColor.snesDefaultPalette))
        // Remaining 15 palettes are all black
        for i in 1..<16 {
            palettes.append(SNESPalette(
                name: "Palette \(i)",
                colors: Array(repeating: SNESColor.black, count: 16)
            ))
        }
        return palettes
    }
}
