import SwiftUI

struct SpriteDrawingNSView: NSViewRepresentable {
    @Binding var pixels: [UInt8]
    var canvasWidth: Int
    var canvasHeight: Int
    var palette: SNESPalette
    var selectedColorIndex: UInt8
    var currentTool: TileEditorTool
    var zoom: CGFloat
    var brushSize: Int
    var fillShapes: Bool
    var showTileGrid: Bool
    var bgImage: CGImage?
    var showBG: Bool
    var bgOffsetX: Int
    var bgOffsetY: Int
    // Light table
    var ghostPrevPixels: [UInt8]?
    var ghostNextPixels: [UInt8]?
    var showLightTable: Bool
    // Callbacks
    var onBeginEdit: (() -> Void)?
    var onColorPicked: ((UInt8) -> Void)?
    var onCursorMoved: ((Int, Int) -> Void)?
    var onPrevFrame: (() -> Void)?
    var onNextFrame: (() -> Void)?
    var onTogglePlayback: (() -> Void)?

    func makeNSView(context: Context) -> SpriteDrawingCanvas {
        let canvas = SpriteDrawingCanvas()
        configureCanvas(canvas)
        return canvas
    }

    func updateNSView(_ canvas: SpriteDrawingCanvas, context: Context) {
        configureCanvas(canvas)
    }

    private func configureCanvas(_ canvas: SpriteDrawingCanvas) {
        canvas.pixels = pixels
        canvas.canvasWidth = canvasWidth
        canvas.canvasHeight = canvasHeight
        canvas.palette = palette
        canvas.selectedColorIndex = selectedColorIndex
        canvas.currentTool = currentTool
        canvas.zoom = zoom
        canvas.brushSize = brushSize
        canvas.fillShapes = fillShapes
        canvas.showTileGrid = showTileGrid
        canvas.bgImage = bgImage
        canvas.showBG = showBG
        canvas.bgOffsetX = bgOffsetX
        canvas.bgOffsetY = bgOffsetY
        canvas.ghostPrevPixels = ghostPrevPixels
        canvas.ghostNextPixels = ghostNextPixels
        canvas.showLightTable = showLightTable
        canvas.onPixelsChanged = { newPixels in self.pixels = newPixels }
        canvas.onBeginEdit = onBeginEdit
        canvas.onColorPicked = onColorPicked
        canvas.onCursorMoved = onCursorMoved
        canvas.onPrevFrame = onPrevFrame
        canvas.onNextFrame = onNextFrame
        canvas.onTogglePlayback = onTogglePlayback
    }
}
