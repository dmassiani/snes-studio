import AppKit

final class LevelCanvas: NSView {
    var level: SNESLevel = .create(name: "Empty", bgMode: 1, widthTiles: 64, heightTiles: 28) {
        didSet { if level != oldValue { needsDisplay = true } }
    }
    var tiles: [SNESTile] = [] {
        didSet { if tiles != oldValue { needsDisplay = true } }
    }
    var palettes: [SNESPalette] = SNESPalette.defaultPalettes() {
        didSet { if palettes != oldValue { needsDisplay = true } }
    }
    var activeLayerIndex: Int = 0 {
        didSet { if activeLayerIndex != oldValue { needsDisplay = true } }
    }
    var showGrid: Bool = true {
        didSet { if showGrid != oldValue { needsDisplay = true } }
    }
    var zoom: CGFloat = 2 {
        didSet { if zoom != oldValue { invalidateIntrinsicContentSize(); needsDisplay = true } }
    }
    var cameraX: CGFloat = 0 {
        didSet { if cameraX != oldValue { needsDisplay = true } }
    }
    var currentTool: TilemapTool = .stamp

    // Tilemap block stamping
    var stampTilemap: SNESTilemap? = nil

    var onLevelChanged: ((SNESLevel) -> Void)?
    var onCellSelected: ((Int, Int) -> Void)?
    var onBeginEdit: (() -> Void)?

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        guard let activeLayer = activeLayerSafe else {
            return NSSize(width: 256, height: 224)
        }
        let cellSize = 8 * zoom
        return NSSize(
            width: CGFloat(activeLayer.tilemap.width) * cellSize,
            height: CGFloat(activeLayer.tilemap.height) * cellSize
        )
    }

    private var activeLayerSafe: ParallaxLayer? {
        guard activeLayerIndex >= 0, activeLayerIndex < level.layers.count else { return nil }
        return level.layers[activeLayerIndex]
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cellSize = 8 * zoom
        let pixSize = zoom

        // Draw layers back to front
        for layerIdx in stride(from: level.layers.count - 1, through: 0, by: -1) {
            let layer = level.layers[layerIdx]
            guard layer.visible else { continue }

            let isActive = layerIdx == activeLayerIndex
            let alpha: CGFloat = isActive ? 1.0 : 0.3
            ctx.setAlpha(alpha)

            let tm = layer.tilemap
            for cy in 0..<tm.height {
                for cx in 0..<tm.width {
                    let entry = tm.entry(x: cx, y: cy)
                    let baseX = CGFloat(cx) * cellSize
                    let baseY = CGFloat(cy) * cellSize

                    let cellRect = CGRect(x: baseX, y: baseY, width: cellSize, height: cellSize)
                    guard cellRect.intersects(dirtyRect) else { continue }

                    if entry.tileIndex < tiles.count && entry.tileIndex > 0 {
                        let tile = tiles[entry.tileIndex]
                        let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]
                        for py in 0..<8 {
                            for px in 0..<8 {
                                let tx = entry.flipH ? (7 - px) : px
                                let ty = entry.flipV ? (7 - py) : py
                                let colorIdx = Int(tile.pixel(x: tx, y: ty))
                                if colorIdx == 0 { continue }
                                let snesColor = pal[colorIdx]
                                ctx.setFillColor(snesColor.nsColor.cgColor)
                                ctx.fill(CGRect(
                                    x: baseX + CGFloat(px) * pixSize,
                                    y: baseY + CGFloat(py) * pixSize,
                                    width: pixSize, height: pixSize
                                ))
                            }
                        }
                    } else if entry.tileIndex > 0 {
                        let isEven = (cx + cy) % 2 == 0
                        ctx.setFillColor(NSColor(white: isEven ? 0.15 : 0.12, alpha: 1).cgColor)
                        ctx.fill(cellRect)
                    }
                }
            }

            ctx.setAlpha(1.0)
        }

        // Grid on active layer only
        if showGrid, let active = activeLayerSafe {
            ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(0.5)
            let tm = active.tilemap
            for i in 0...tm.width {
                let x = CGFloat(i) * cellSize
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: CGFloat(tm.height) * cellSize))
            }
            for j in 0...tm.height {
                let y = CGFloat(j) * cellSize
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: CGFloat(tm.width) * cellSize, y: y))
            }

            // Tilemap-sized grid (heavier lines) if stamp tilemap exists
            if let stm = stampTilemap {
                ctx.strokePath()
                ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
                ctx.setLineWidth(1.0)
                let stepX = CGFloat(stm.width) * cellSize
                let stepY = CGFloat(stm.height) * cellSize
                if stepX > 0 {
                    var x: CGFloat = 0
                    while x <= CGFloat(tm.width) * cellSize {
                        ctx.move(to: CGPoint(x: x, y: 0))
                        ctx.addLine(to: CGPoint(x: x, y: CGFloat(tm.height) * cellSize))
                        x += stepX
                    }
                }
                if stepY > 0 {
                    var y: CGFloat = 0
                    while y <= CGFloat(tm.height) * cellSize {
                        ctx.move(to: CGPoint(x: 0, y: y))
                        ctx.addLine(to: CGPoint(x: CGFloat(tm.width) * cellSize, y: y))
                        y += stepY
                    }
                }
            }
            ctx.strokePath()
        }

        // Viewport indicator: 32x28 tiles (256x224 px) at cameraX
        let vpW = 32.0 * cellSize
        let vpH = 28.0 * cellSize
        let vpX = cameraX * cellSize
        let vpRect = CGRect(x: vpX, y: 0, width: vpW, height: vpH)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [6, 4])
        ctx.stroke(vpRect)
        ctx.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Mouse events

    private var editStarted = false

    override func mouseDown(with event: NSEvent) {
        guard let _ = activeLayerSafe else { return }
        let (cx, cy) = cellAt(event)
        let tm = level.layers[activeLayerIndex].tilemap
        guard cx >= 0, cx < tm.width, cy >= 0, cy < tm.height else { return }

        onCellSelected?(cx, cy)

        switch currentTool {
        case .stamp:
            if !editStarted { onBeginEdit?(); editStarted = true }
            placeStamp(cx: cx, cy: cy)
        case .eraser:
            if !editStarted { onBeginEdit?(); editStarted = true }
            eraseBlock(cx: cx, cy: cy)
        case .fill, .eyedropper:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        // No drag for tilemap-block stamping
    }

    override func mouseUp(with event: NSEvent) {
        editStarted = false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Helpers

    private func cellAt(_ event: NSEvent) -> (Int, Int) {
        let loc = convert(event.locationInWindow, from: nil)
        let cellSize = 8 * zoom
        return (Int(loc.x / cellSize), Int(loc.y / cellSize))
    }

    /// Stamp the selected tilemap block at the given cell, snapping to tilemap-sized grid
    private func placeStamp(cx: Int, cy: Int) {
        guard let stm = stampTilemap else { return }
        let layerTm = level.layers[activeLayerIndex].tilemap

        // Snap to tilemap grid
        let snapX = (cx / max(stm.width, 1)) * stm.width
        let snapY = (cy / max(stm.height, 1)) * stm.height

        for sy in 0..<stm.height {
            for sx in 0..<stm.width {
                let destX = snapX + sx
                let destY = snapY + sy
                guard destX >= 0, destX < layerTm.width, destY >= 0, destY < layerTm.height else { continue }
                let entry = stm.entry(x: sx, y: sy)
                level.layers[activeLayerIndex].tilemap.setEntry(x: destX, y: destY, entry: entry)
            }
        }
        needsDisplay = true
        onLevelChanged?(level)
    }

    /// Erase a tilemap-sized block at the given cell
    private func eraseBlock(cx: Int, cy: Int) {
        let blockW: Int
        let blockH: Int
        if let stm = stampTilemap {
            blockW = stm.width
            blockH = stm.height
        } else {
            blockW = 1
            blockH = 1
        }

        let layerTm = level.layers[activeLayerIndex].tilemap
        let snapX = (cx / max(blockW, 1)) * blockW
        let snapY = (cy / max(blockH, 1)) * blockH
        let empty = TilemapEntry()

        for sy in 0..<blockH {
            for sx in 0..<blockW {
                let destX = snapX + sx
                let destY = snapY + sy
                guard destX >= 0, destX < layerTm.width, destY >= 0, destY < layerTm.height else { continue }
                level.layers[activeLayerIndex].tilemap.setEntry(x: destX, y: destY, entry: empty)
            }
        }
        needsDisplay = true
        onLevelChanged?(level)
    }
}
