import Foundation

struct ParallaxLayer: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var bgLayer: Int          // 0-3 (BG1-BG4)
    var scrollRatioX: Double  // 1.0 = full speed, 0.5 = half
    var scrollRatioY: Double
    var repeatX: Bool         // wrap horizontal
    var repeatY: Bool         // wrap vertical
    var visible: Bool = true
    var tilemap: SNESTilemap
}

struct SNESLevel: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var bgMode: Int           // 0-7
    var layers: [ParallaxLayer]

    /// Creates layers for a given BG mode and dimensions
    static func createLayers(bgMode: Int, widthTiles: Int, heightTiles: Int) -> [ParallaxLayer] {
        let modeInfo = BGModeInfo.allModes[min(bgMode, 7)]
        let active = modeInfo.activeLayers

        var layers: [ParallaxLayer] = []
        for (i, info) in active.enumerated() {
            let ratio: Double
            let layerWidth: Int
            let repeats: Bool
            let layerName: String

            switch i {
            case 0:
                ratio = 1.0
                layerWidth = widthTiles
                repeats = false
                layerName = "BG\(info.layer + 1) - Foreground"
            case 1:
                ratio = 0.5
                layerWidth = max(widthTiles / 2, 32)
                repeats = true
                layerName = "BG\(info.layer + 1) - Middle"
            default:
                ratio = 0.25
                layerWidth = max(widthTiles / 4, 32)
                repeats = true
                layerName = "BG\(info.layer + 1) - Background"
            }

            let tilemap = SNESTilemap(name: layerName, width: layerWidth, height: heightTiles)
            layers.append(ParallaxLayer(
                name: layerName,
                bgLayer: info.layer,
                scrollRatioX: ratio,
                scrollRatioY: ratio,
                repeatX: repeats,
                repeatY: false,
                tilemap: tilemap
            ))
        }

        return layers
    }

    static func create(name: String, bgMode: Int, widthTiles: Int, heightTiles: Int) -> SNESLevel {
        let layers = createLayers(bgMode: bgMode, widthTiles: widthTiles, heightTiles: heightTiles)
        return SNESLevel(name: name, bgMode: bgMode, layers: layers)
    }

    /// Build a view-model SNESLevel from a WorldScreen + its parent zone
    static func fromScreen(_ screen: WorldScreen, zone: WorldZone) -> SNESLevel {
        SNESLevel(
            id: screen.id,
            name: screen.name,
            bgMode: zone.bgMode,
            layers: screen.layers
        )
    }
}
