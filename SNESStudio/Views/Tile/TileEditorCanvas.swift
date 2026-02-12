import AppKit

enum TileEditorTool: Equatable {
    case pencil
    case line
    case rectangle
    case circle
    case fill
    case dither
    case eraser
    case eyedropper
    case selection
}

final class TileEditorCanvas: NSView {
    var tiles: [SNESTile] = [.empty()] {
        didSet { if tiles != oldValue { needsDisplay = true } }
    }
    var gridCols: Int = 1 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var gridRows: Int = 1 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var palette: SNESPalette = SNESPalette.defaultPalettes()[0] {
        didSet { if palette != oldValue { needsDisplay = true } }
    }
    var selectedColorIndex: UInt8 = 1
    var currentTool: TileEditorTool = .pencil
    var zoom: CGFloat = 24 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var brushSize: Int = 1
    var fillShapes: Bool = false
    var onTilesChanged: (([SNESTile]) -> Void)?
    var onBeginEdit: (() -> Void)?
    var onColorPicked: ((UInt8) -> Void)?

    // Drag state for shape tools
    private var dragOrigin: (x: Int, y: Int)?
    private var snapshotTiles: [SNESTile]?

    // Stroke interpolation
    private var lastMousePoint: (x: Int, y: Int)?

    // Selection state
    private var selectionStart: (x: Int, y: Int)?
    private(set) var selectionRect: (x: Int, y: Int, w: Int, h: Int)?

    override var intrinsicContentSize: NSSize {
        NSSize(width: zoom * 8 * CGFloat(gridCols),
               height: zoom * 8 * CGFloat(gridRows))
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let cellSize = zoom
        let totalW = 8 * gridCols
        let totalH = 8 * gridRows

        // Draw transparency checkerboard background
        let checkSize = max(cellSize / 2, 4)
        let checkLight = NSColor(white: 0.18, alpha: 1).cgColor
        let checkDark = NSColor(white: 0.12, alpha: 1).cgColor
        let totalPixelW = CGFloat(totalW) * cellSize
        let totalPixelH = CGFloat(totalH) * cellSize
        let checksX = Int(ceil(totalPixelW / checkSize))
        let checksY = Int(ceil(totalPixelH / checkSize))
        for cy in 0..<checksY {
            for cx in 0..<checksX {
                ctx.setFillColor((cx + cy) % 2 == 0 ? checkLight : checkDark)
                ctx.fill(CGRect(
                    x: CGFloat(cx) * checkSize,
                    y: CGFloat(cy) * checkSize,
                    width: checkSize, height: checkSize
                ))
            }
        }

        // Draw pixels for each tile in the grid (skip colorIdx 0 = transparent)
        for tileRow in 0..<gridRows {
            for tileCol in 0..<gridCols {
                let tileIdx = tileRow * gridCols + tileCol
                guard tileIdx < tiles.count else { continue }
                let tile = tiles[tileIdx]
                let offsetX = CGFloat(tileCol * 8)
                let offsetY = CGFloat(tileRow * 8)

                for py in 0..<8 {
                    for px in 0..<8 {
                        let colorIdx = Int(tile.pixel(x: px, y: py))
                        if colorIdx == 0 { continue } // Transparent
                        let snesColor = palette[colorIdx]
                        ctx.setFillColor(snesColor.nsColor.cgColor)
                        ctx.fill(CGRect(
                            x: (offsetX + CGFloat(px)) * cellSize,
                            y: (offsetY + CGFloat(py)) * cellSize,
                            width: cellSize,
                            height: cellSize
                        ))
                    }
                }
            }
        }

        // Draw pixel grid lines (thin)
        ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(0.5)
        for i in 0...totalW {
            let pos = CGFloat(i) * cellSize
            ctx.move(to: CGPoint(x: pos, y: 0))
            ctx.addLine(to: CGPoint(x: pos, y: CGFloat(totalH) * cellSize))
        }
        for i in 0...totalH {
            let pos = CGFloat(i) * cellSize
            ctx.move(to: CGPoint(x: 0, y: pos))
            ctx.addLine(to: CGPoint(x: CGFloat(totalW) * cellSize, y: pos))
        }
        ctx.strokePath()

        // Draw tile boundary lines (thicker) if multi-tile
        if gridCols > 1 || gridRows > 1 {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(2.0)
            for col in 1..<gridCols {
                let pos = CGFloat(col * 8) * cellSize
                ctx.move(to: CGPoint(x: pos, y: 0))
                ctx.addLine(to: CGPoint(x: pos, y: CGFloat(totalH) * cellSize))
            }
            for row in 1..<gridRows {
                let pos = CGFloat(row * 8) * cellSize
                ctx.move(to: CGPoint(x: 0, y: pos))
                ctx.addLine(to: CGPoint(x: CGFloat(totalW) * cellSize, y: pos))
            }
            ctx.strokePath()
        }

        // Draw selection rectangle overlay
        if let sel = selectionRect {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1.0)
            ctx.setLineDash(phase: 0, lengths: [4, 4])
            ctx.stroke(CGRect(
                x: CGFloat(sel.x) * cellSize,
                y: CGFloat(sel.y) * cellSize,
                width: CGFloat(sel.w) * cellSize,
                height: CGFloat(sel.h) * cellSize
            ))
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineDash(phase: 4, lengths: [4, 4])
            ctx.stroke(CGRect(
                x: CGFloat(sel.x) * cellSize,
                y: CGFloat(sel.y) * cellSize,
                width: CGFloat(sel.w) * cellSize,
                height: CGFloat(sel.h) * cellSize
            ))
            ctx.restoreGState()
        }
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let loc = convert(event.locationInWindow, from: nil)
        let px = Int(loc.x / zoom)
        let py = Int(loc.y / zoom)
        let totalW = 8 * gridCols
        let totalH = 8 * gridRows
        guard px >= 0, px < totalW, py >= 0, py < totalH else { return }

        // Alt+click = eyedropper from any tool
        if event.modifierFlags.contains(.option) {
            onColorPicked?(getVirtualPixel(x: px, y: py))
            return
        }

        switch currentTool {
        case .pencil:
            onBeginEdit?()
            applyBrush(cx: px, cy: py, value: selectedColorIndex)
            lastMousePoint = (px, py)
            commitChanges()

        case .eraser:
            onBeginEdit?()
            applyBrush(cx: px, cy: py, value: 0)
            lastMousePoint = (px, py)
            commitChanges()

        case .dither:
            onBeginEdit?()
            applyDither(cx: px, cy: py)
            lastMousePoint = (px, py)
            commitChanges()

        case .line, .rectangle, .circle:
            onBeginEdit?()
            dragOrigin = (px, py)
            snapshotTiles = tiles

        case .fill:
            onBeginEdit?()
            let target = getVirtualPixel(x: px, y: py)
            floodFillCrossTile(startX: px, startY: py, target: target, replacement: selectedColorIndex)
            commitChanges()

        case .eyedropper:
            onColorPicked?(getVirtualPixel(x: px, y: py))

        case .selection:
            selectionStart = (px, py)
            selectionRect = (px, py, 1, 1)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let totalW = 8 * gridCols
        let totalH = 8 * gridRows
        let cx = max(0, min(Int(loc.x / zoom), totalW - 1))
        let cy = max(0, min(Int(loc.y / zoom), totalH - 1))

        switch currentTool {
        case .pencil:
            if let last = lastMousePoint {
                interpolate(from: last, to: (cx, cy)) { x, y in
                    self.applyBrush(cx: x, cy: y, value: self.selectedColorIndex)
                }
            } else {
                applyBrush(cx: cx, cy: cy, value: selectedColorIndex)
            }
            lastMousePoint = (cx, cy)
            commitChanges()

        case .eraser:
            if let last = lastMousePoint {
                interpolate(from: last, to: (cx, cy)) { x, y in
                    self.applyBrush(cx: x, cy: y, value: 0)
                }
            } else {
                applyBrush(cx: cx, cy: cy, value: 0)
            }
            lastMousePoint = (cx, cy)
            commitChanges()

        case .dither:
            if let last = lastMousePoint {
                interpolate(from: last, to: (cx, cy)) { x, y in
                    self.applyDither(cx: x, cy: y)
                }
            } else {
                applyDither(cx: cx, cy: cy)
            }
            lastMousePoint = (cx, cy)
            commitChanges()

        case .line, .rectangle, .circle:
            if let origin = dragOrigin, let snapshot = snapshotTiles {
                tiles = snapshot
                drawShape(tool: currentTool, from: origin, to: (cx, cy))
                needsDisplay = true
                onTilesChanged?(tiles)
            }

        case .selection:
            if let start = selectionStart {
                let minX = min(start.x, cx)
                let minY = min(start.y, cy)
                let maxX = max(start.x, cx)
                let maxY = max(start.y, cy)
                selectionRect = (minX, minY, maxX - minX + 1, maxY - minY + 1)
                needsDisplay = true
            }

        default: break
        }
    }

    override func mouseUp(with event: NSEvent) {
        lastMousePoint = nil
        if dragOrigin != nil {
            dragOrigin = nil
            snapshotTiles = nil
        }
        if currentTool == .selection {
            selectionStart = nil
        }
    }

    // MARK: - Key events

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            selectionRect = nil
            needsDisplay = true
            return
        }
        if (event.keyCode == 51 || event.keyCode == 117), let sel = selectionRect {
            onBeginEdit?()
            for y in sel.y..<(sel.y + sel.h) {
                for x in sel.x..<(sel.x + sel.w) {
                    setVirtualPixel(x: x, y: y, value: 0)
                }
            }
            selectionRect = nil
            commitChanges()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Virtual pixel access

    private func getVirtualPixel(x: Int, y: Int) -> UInt8 {
        let totalW = 8 * gridCols
        let totalH = 8 * gridRows
        guard x >= 0, x < totalW, y >= 0, y < totalH else { return 0 }
        let tileIdx = (y / 8) * gridCols + (x / 8)
        guard tileIdx < tiles.count else { return 0 }
        return tiles[tileIdx].pixel(x: x % 8, y: y % 8)
    }

    private func setVirtualPixel(x: Int, y: Int, value: UInt8) {
        let totalW = 8 * gridCols
        let totalH = 8 * gridRows
        guard x >= 0, x < totalW, y >= 0, y < totalH else { return }
        let tileIdx = (y / 8) * gridCols + (x / 8)
        guard tileIdx < tiles.count else { return }
        tiles[tileIdx].setPixel(x: x % 8, y: y % 8, value: value)
    }

    // MARK: - Brush

    private func applyBrush(cx: Int, cy: Int, value: UInt8) {
        let half = brushSize / 2
        for dy in 0..<brushSize {
            for dx in 0..<brushSize {
                setVirtualPixel(x: cx - half + dx, y: cy - half + dy, value: value)
            }
        }
    }

    private func applyDither(cx: Int, cy: Int) {
        let half = brushSize / 2
        for dy in 0..<brushSize {
            for dx in 0..<brushSize {
                let px = cx - half + dx
                let py = cy - half + dy
                if (px + py) % 2 == 0 {
                    setVirtualPixel(x: px, y: py, value: selectedColorIndex)
                } else {
                    setVirtualPixel(x: px, y: py, value: 0)
                }
            }
        }
    }

    // Bresenham interpolation for smooth strokes
    private func interpolate(from a: (Int, Int), to b: (Int, Int), apply: (Int, Int) -> Void) {
        var x0 = a.0, y0 = a.1
        let x1 = b.0, y1 = b.1
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            apply(x0, y0)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }

    private func commitChanges() {
        needsDisplay = true
        onTilesChanged?(tiles)
    }

    // MARK: - Shape drawing

    private func drawShape(tool: TileEditorTool, from a: (x: Int, y: Int), to b: (x: Int, y: Int)) {
        let value = selectedColorIndex
        switch tool {
        case .line:
            drawLine(from: a, to: b, value: value)
        case .rectangle:
            drawRect(from: a, to: b, value: value, filled: fillShapes)
        case .circle:
            drawEllipse(from: a, to: b, value: value, filled: fillShapes)
        default: break
        }
    }

    // Bresenham line
    private func drawLine(from start: (x: Int, y: Int), to end: (x: Int, y: Int), value: UInt8) {
        var x0 = start.x, y0 = start.y
        let x1 = end.x, y1 = end.y
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            setVirtualPixel(x: x0, y: y0, value: value)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }

    // Rectangle
    private func drawRect(from a: (x: Int, y: Int), to b: (x: Int, y: Int), value: UInt8, filled: Bool) {
        let minX = min(a.x, b.x), maxX = max(a.x, b.x)
        let minY = min(a.y, b.y), maxY = max(a.y, b.y)

        if filled {
            for y in minY...maxY {
                for x in minX...maxX {
                    setVirtualPixel(x: x, y: y, value: value)
                }
            }
        } else {
            for x in minX...maxX {
                setVirtualPixel(x: x, y: minY, value: value)
                setVirtualPixel(x: x, y: maxY, value: value)
            }
            for y in (minY + 1)..<maxY {
                setVirtualPixel(x: minX, y: y, value: value)
                setVirtualPixel(x: maxX, y: y, value: value)
            }
        }
    }

    // Ellipse inscribed in bounding rect
    private func drawEllipse(from a: (x: Int, y: Int), to b: (x: Int, y: Int), value: UInt8, filled: Bool) {
        let minX = min(a.x, b.x), maxX = max(a.x, b.x)
        let minY = min(a.y, b.y), maxY = max(a.y, b.y)
        let cx = Double(minX + maxX) / 2.0
        let cy = Double(minY + maxY) / 2.0
        let rx = Double(maxX - minX) / 2.0
        let ry = Double(maxY - minY) / 2.0

        guard rx > 0 || ry > 0 else {
            setVirtualPixel(x: minX, y: minY, value: value)
            return
        }

        if filled {
            for y in minY...maxY {
                for x in minX...maxX {
                    let dx = (Double(x) - cx) / max(rx, 0.5)
                    let dy = (Double(y) - cy) / max(ry, 0.5)
                    if dx * dx + dy * dy <= 1.0 {
                        setVirtualPixel(x: x, y: y, value: value)
                    }
                }
            }
        } else {
            let steps = max(Int(max(rx, ry)) * 8, 32)
            for i in 0...steps {
                let angle = Double(i) / Double(steps) * 2.0 * .pi
                let x = Int(round(cx + rx * cos(angle)))
                let y = Int(round(cy + ry * sin(angle)))
                setVirtualPixel(x: x, y: y, value: value)
            }
        }
    }

    // MARK: - Cross-tile flood fill

    private func floodFillCrossTile(startX: Int, startY: Int, target: UInt8, replacement: UInt8) {
        guard target != replacement else { return }
        let totalW = 8 * gridCols
        let totalH = 8 * gridRows

        var stack = [(startX, startY)]
        var visited = Set<Int>()

        while let (cx, cy) = stack.popLast() {
            guard cx >= 0, cx < totalW, cy >= 0, cy < totalH else { continue }
            let key = cy * totalW + cx
            guard !visited.contains(key) else { continue }

            let tileCol = cx / 8
            let tileRow = cy / 8
            let tileIdx = tileRow * gridCols + tileCol
            guard tileIdx < tiles.count else { continue }

            let lx = cx % 8
            let ly = cy % 8
            guard tiles[tileIdx].pixel(x: lx, y: ly) == target else { continue }

            visited.insert(key)
            tiles[tileIdx].setPixel(x: lx, y: ly, value: replacement)

            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
