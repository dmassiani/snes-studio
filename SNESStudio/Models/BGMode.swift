import Foundation

struct BGLayerInfo: Equatable {
    let layer: Int        // 0-3 (BG1-BG4)
    let depth: TileDepth?
    let maxColors: Int
}

struct BGModeInfo: Identifiable, Equatable {
    let mode: Int
    let description: String
    let layers: [BGLayerInfo]
    let isMode7: Bool

    var id: Int { mode }
    var label: String { "Mode \(mode)" }

    var activeLayers: [BGLayerInfo] {
        layers.filter { $0.depth != nil }
    }
}

extension BGModeInfo {
    static let allModes: [BGModeInfo] = [
        BGModeInfo(
            mode: 0,
            description: "4 layers, 4 colors each (2bpp x4). Good for text-heavy or simple tile games.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp2, maxColors: 4),
                BGLayerInfo(layer: 1, depth: .bpp2, maxColors: 4),
                BGLayerInfo(layer: 2, depth: .bpp2, maxColors: 4),
                BGLayerInfo(layer: 3, depth: .bpp2, maxColors: 4),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 1,
            description: "3 layers: BG1/BG2 16 colors, BG3 4 colors. Most common SNES mode.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 1, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 2, depth: .bpp2, maxColors: 4),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 2,
            description: "2 layers, 16 colors each with per-tile offset. Used for parallax effects.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 1, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 2, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 3,
            description: "2 layers: BG1 256 colors, BG2 16 colors. Rich background + overlay.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp8, maxColors: 256),
                BGLayerInfo(layer: 1, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 2, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 4,
            description: "2 layers: BG1 256 colors, BG2 4 colors with per-tile offset.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp8, maxColors: 256),
                BGLayerInfo(layer: 1, depth: .bpp2, maxColors: 4),
                BGLayerInfo(layer: 2, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 5,
            description: "2 layers, hires (512px): BG1 16 colors, BG2 4 colors. Used for text.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 1, depth: .bpp2, maxColors: 4),
                BGLayerInfo(layer: 2, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 6,
            description: "1 layer, hires (512px): BG1 16 colors with per-tile offset.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp4, maxColors: 16),
                BGLayerInfo(layer: 1, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 2, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: false
        ),
        BGModeInfo(
            mode: 7,
            description: "1 layer, 256 colors with rotation/scaling. EXTBG adds a 2nd layer.",
            layers: [
                BGLayerInfo(layer: 0, depth: .bpp8, maxColors: 256),
                BGLayerInfo(layer: 1, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 2, depth: nil, maxColors: 0),
                BGLayerInfo(layer: 3, depth: nil, maxColors: 0),
            ],
            isMode7: true
        ),
    ]
}
