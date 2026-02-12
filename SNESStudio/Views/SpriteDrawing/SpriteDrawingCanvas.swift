import AppKit

final class SpriteDrawingCanvas: NSView {
    // MARK: - Properties

    var pixels: [UInt8] = [] {
        didSet { if pixels != oldValue { needsDisplay = true } }
    }
    var canvasWidth: Int = 32 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var canvasHeight: Int = 32 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var palette: SNESPalette = SNESPalette.defaultPalettes()[0] {
        didSet { if palette != oldValue { needsDisplay = true } }
    }
    var selectedColorIndex: UInt8 = 1
    var currentTool: TileEditorTool = .pencil
    var zoom: CGFloat = 16 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var brushSize: Int = 1
    var fillShapes: Bool = false
    var showTileGrid: Bool = true {
        didSet { needsDisplay = true }
    }
    var bgImage: CGImage? {
        didSet { needsDisplay = true }
    }
    var showBG: Bool = false {
        didSet { needsDisplay = true }
    }
    var bgOffsetX: Int = 0
    var bgOffsetY: Int = 0

    // Light table (onion skinning)
    var ghostPrevPixels: [UInt8]? {
        didSet { needsDisplay = true }
    }
    var ghostNextPixels: [UInt8]? {
        didSet { needsDisplay = true }
    }
    var showLightTable: Bool = false {
        didSet { needsDisplay = true }
    }

    // Callbacks
    var onPixelsChanged: (([UInt8]) -> Void)?
    var onBeginEdit: (() -> Void)?
    var onColorPicked: ((UInt8) -> Void)?
    var onCursorMoved: ((Int, Int) -> Void)?
    var onPrevFrame: (() -> Void)?
    var onNextFrame: (() -> Void)?
    var onTogglePlayback: (() -> Void)?

    // Drag state for shape tools
    private var dragOrigin: (x: Int, y: Int)?
    private var snapshotPixels: [UInt8]?

    // Stroke interpolation
    private var lastMousePoint: (x: Int, y: Int)?

    // Selection state
    private var selectionStart: (x: Int, y: Int)?
    private(set) var selectionRect: (x: Int, y: Int, w: Int, h: Int)?
    private var isMovingSelection: Bool = false
    private var selectionMoveAnchor: (x: Int, y: Int)?
    private var floatingPixels: [UInt8]?

    override var intrinsicContentSize: NSSize {
        NSSize(width: zoom * CGFloat(canvasWidth),
               height: zoom * CGFloat(canvasHeight))
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let cellSize = zoom
        let totalPixelW = CGFloat(canvasWidth) * cellSize
        let totalPixelH = CGFloat(canvasHeight) * cellSize

        // Draw transparency checkerboard background
        let checkSize = max(cellSize / 2, 4)
        let checkLight = NSColor(white: 0.18, alpha: 1).cgColor
        let checkDark = NSColor(white: 0.12, alpha: 1).cgColor
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

        // Draw BG snapshot behind sprite (reduced opacity)
        if showBG, let bg = bgImage {
            ctx.saveGState()
            ctx.setAlpha(0.3)
            // Map BG image region to canvas position
            let destRect = CGRect(x: 0, y: 0, width: totalPixelW, height: totalPixelH)
            // Compute source rect from bg based on sprite position
            let srcX = CGFloat(bgOffsetX)
            let srcY = CGFloat(bgOffsetY)
            let srcW = CGFloat(canvasWidth)
            let srcH = CGFloat(canvasHeight)
            let srcRect = CGRect(x: srcX, y: srcY, width: srcW, height: srcH)

            if let cropped = bg.cropping(to: srcRect) {
                ctx.draw(cropped, in: destRect)
            }
            ctx.restoreGState()
        }

        // Draw light table ghost frames (onion skinning)
        if showLightTable {
            // Previous frame in blue tint
            if let prevPx = ghostPrevPixels {
                drawGhostFrame(ctx: ctx, ghostPixels: prevPx, cellSize: cellSize,
                               tintR: 0.2, tintG: 0.5, tintB: 1.0, alpha: 0.25)
            }
            // Next frame in red tint
            if let nextPx = ghostNextPixels {
                drawGhostFrame(ctx: ctx, ghostPixels: nextPx, cellSize: cellSize,
                               tintR: 1.0, tintG: 0.3, tintB: 0.2, alpha: 0.25)
            }
        }

        // Draw pixels (skip colorIdx 0 = transparent)
        for py in 0..<canvasHeight {
            for px in 0..<canvasWidth {
                let idx = py * canvasWidth + px
                guard idx < pixels.count else { continue }
                let colorIdx = Int(pixels[idx])
                if colorIdx == 0 { continue }
                let snesColor = palette[colorIdx]
                ctx.setFillColor(snesColor.nsColor.cgColor)
                ctx.fill(CGRect(
                    x: CGFloat(px) * cellSize,
                    y: CGFloat(py) * cellSize,
                    width: cellSize,
                    height: cellSize
                ))
            }
        }

        // Draw floating selection pixels (being moved)
        if let floating = floatingPixels, let sel = selectionRect {
            for dy in 0..<sel.h {
                for dx in 0..<sel.w {
                    let colorIdx = Int(floating[dy * sel.w + dx])
                    if colorIdx == 0 { continue }
                    let px = sel.x + dx
                    let py = sel.y + dy
                    guard px >= 0, px < canvasWidth, py >= 0, py < canvasHeight else { continue }
                    let snesColor = palette[colorIdx]
                    ctx.setFillColor(snesColor.nsColor.cgColor)
                    ctx.fill(CGRect(
                        x: CGFloat(px) * cellSize,
                        y: CGFloat(py) * cellSize,
                        width: cellSize,
                        height: cellSize
                    ))
                }
            }
        }

        // Draw pixel grid lines (thin)
        ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(0.5)
        for i in 0...canvasWidth {
            let pos = CGFloat(i) * cellSize
            ctx.move(to: CGPoint(x: pos, y: 0))
            ctx.addLine(to: CGPoint(x: pos, y: totalPixelH))
        }
        for i in 0...canvasHeight {
            let pos = CGFloat(i) * cellSize
            ctx.move(to: CGPoint(x: 0, y: pos))
            ctx.addLine(to: CGPoint(x: totalPixelW, y: pos))
        }
        ctx.strokePath()

        // Draw 8x8 tile grid overlay (dashed white)
        if showTileGrid {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(1.0)
            ctx.setLineDash(phase: 0, lengths: [4, 4])
            let tilesX = canvasWidth / 8
            let tilesY = canvasHeight / 8
            for col in 1..<tilesX {
                let pos = CGFloat(col * 8) * cellSize
                ctx.move(to: CGPoint(x: pos, y: 0))
                ctx.addLine(to: CGPoint(x: pos, y: totalPixelH))
            }
            for row in 1..<tilesY {
                let pos = CGFloat(row * 8) * cellSize
                ctx.move(to: CGPoint(x: 0, y: pos))
                ctx.addLine(to: CGPoint(x: totalPixelW, y: pos))
            }
            ctx.strokePath()
            ctx.restoreGState()
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
        guard px >= 0, px < canvasWidth, py >= 0, py < canvasHeight else { return }

        onCursorMoved?(px, py)

        // Alt+click = eyedropper from any tool
        if event.modifierFlags.contains(.option) {
            let idx = py * canvasWidth + px
            if idx < pixels.count {
                onColorPicked?(pixels[idx])
            }
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
            snapshotPixels = pixels

        case .fill:
            onBeginEdit?()
            let target = getPixel(x: px, y: py)
            floodFill(startX: px, startY: py, target: target, replacement: selectedColorIndex)
            commitChanges()

        case .eyedropper:
            onColorPicked?(getPixel(x: px, y: py))

        case .selection:
            if let sel = selectionRect {
                // Click inside existing selection → start moving
                if px >= sel.x, px < sel.x + sel.w, py >= sel.y, py < sel.y + sel.h {
                    onBeginEdit?()
                    isMovingSelection = true
                    selectionMoveAnchor = (px, py)
                    // Lift pixels into floating buffer
                    if floatingPixels == nil {
                        var lifted = [UInt8](repeating: 0, count: sel.w * sel.h)
                        for dy in 0..<sel.h {
                            for dx in 0..<sel.w {
                                let sx = sel.x + dx
                                let sy = sel.y + dy
                                lifted[dy * sel.w + dx] = getPixel(x: sx, y: sy)
                                setPixel(x: sx, y: sy, value: 0)
                            }
                        }
                        floatingPixels = lifted
                    }
                } else {
                    // Click outside → commit floating pixels and cancel selection
                    commitFloatingPixels()
                    selectionRect = nil
                    floatingPixels = nil
                    needsDisplay = true
                }
            } else {
                // No selection → start creating one
                selectionStart = (px, py)
                selectionRect = (px, py, 1, 1)
                needsDisplay = true
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let cx = max(0, min(Int(loc.x / zoom), canvasWidth - 1))
        let cy = max(0, min(Int(loc.y / zoom), canvasHeight - 1))

        onCursorMoved?(cx, cy)

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
            if let origin = dragOrigin, let snapshot = snapshotPixels {
                pixels = snapshot
                drawShape(tool: currentTool, from: origin, to: (cx, cy))
                needsDisplay = true
                onPixelsChanged?(pixels)
            }

        case .selection:
            if isMovingSelection, let anchor = selectionMoveAnchor, let sel = selectionRect {
                let dx = cx - anchor.x
                let dy = cy - anchor.y
                selectionRect = (sel.x + dx, sel.y + dy, sel.w, sel.h)
                selectionMoveAnchor = (cx, cy)
                needsDisplay = true
            } else if let start = selectionStart {
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
            snapshotPixels = nil
        }
        if currentTool == .selection {
            selectionStart = nil
            if isMovingSelection {
                isMovingSelection = false
                selectionMoveAnchor = nil
                // Keep floating pixels — they'll be rendered in draw()
                // and committed on next click outside or Escape/Enter
                commitChanges()
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let px = Int(loc.x / zoom)
        let py = Int(loc.y / zoom)
        if px >= 0, px < canvasWidth, py >= 0, py < canvasHeight {
            onCursorMoved?(px, py)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    // MARK: - Key events

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            commitFloatingPixels()
            selectionRect = nil
            isMovingSelection = false
            selectionMoveAnchor = nil
            needsDisplay = true
            return
        }
        // Enter/Return (keyCode 36/76) — commit floating and deselect
        if event.keyCode == 36 || event.keyCode == 76 {
            commitFloatingPixels()
            selectionRect = nil
            needsDisplay = true
            return
        }
        // Left arrow (keyCode 123) → previous frame
        if event.keyCode == 123 {
            onPrevFrame?()
            return
        }
        // Right arrow (keyCode 124) → next frame
        if event.keyCode == 124 {
            onNextFrame?()
            return
        }
        // Spacebar (keyCode 49) → toggle playback
        if event.keyCode == 49 {
            onTogglePlayback?()
            return
        }
        if (event.keyCode == 51 || event.keyCode == 117), selectionRect != nil {
            onBeginEdit?()
            // If we have floating pixels, just discard them (they're already removed from canvas)
            if floatingPixels != nil {
                floatingPixels = nil
            } else if let sel = selectionRect {
                // Clear pixels in selection area
                for y in sel.y..<(sel.y + sel.h) {
                    for x in sel.x..<(sel.x + sel.w) {
                        setPixel(x: x, y: y, value: 0)
                    }
                }
            }
            selectionRect = nil
            isMovingSelection = false
            commitChanges()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Pixel access

    private func getPixel(x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < canvasWidth, y >= 0, y < canvasHeight else { return 0 }
        let idx = y * canvasWidth + x
        guard idx < pixels.count else { return 0 }
        return pixels[idx]
    }

    private func setPixel(x: Int, y: Int, value: UInt8) {
        guard x >= 0, x < canvasWidth, y >= 0, y < canvasHeight else { return }
        let idx = y * canvasWidth + x
        guard idx < pixels.count else { return }
        pixels[idx] = value
    }

    // MARK: - Brush

    private func applyBrush(cx: Int, cy: Int, value: UInt8) {
        let half = brushSize / 2
        for dy in 0..<brushSize {
            for dx in 0..<brushSize {
                setPixel(x: cx - half + dx, y: cy - half + dy, value: value)
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
                    setPixel(x: px, y: py, value: selectedColorIndex)
                } else {
                    setPixel(x: px, y: py, value: 0)
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
        onPixelsChanged?(pixels)
    }

    /// Stamp floating pixels back into the canvas at current selectionRect position.
    private func commitFloatingPixels() {
        guard let floating = floatingPixels, let sel = selectionRect else { return }
        for dy in 0..<sel.h {
            for dx in 0..<sel.w {
                let colorIdx = floating[dy * sel.w + dx]
                if colorIdx != 0 {
                    setPixel(x: sel.x + dx, y: sel.y + dy, value: colorIdx)
                }
            }
        }
        floatingPixels = nil
        commitChanges()
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

    private func drawLine(from start: (x: Int, y: Int), to end: (x: Int, y: Int), value: UInt8) {
        var x0 = start.x, y0 = start.y
        let x1 = end.x, y1 = end.y
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            setPixel(x: x0, y: y0, value: value)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }

    private func drawRect(from a: (x: Int, y: Int), to b: (x: Int, y: Int), value: UInt8, filled: Bool) {
        let minX = min(a.x, b.x), maxX = max(a.x, b.x)
        let minY = min(a.y, b.y), maxY = max(a.y, b.y)

        if filled {
            for y in minY...maxY {
                for x in minX...maxX {
                    setPixel(x: x, y: y, value: value)
                }
            }
        } else {
            for x in minX...maxX {
                setPixel(x: x, y: minY, value: value)
                setPixel(x: x, y: maxY, value: value)
            }
            for y in (minY + 1)..<maxY {
                setPixel(x: minX, y: y, value: value)
                setPixel(x: maxX, y: y, value: value)
            }
        }
    }

    private func drawEllipse(from a: (x: Int, y: Int), to b: (x: Int, y: Int), value: UInt8, filled: Bool) {
        let minX = min(a.x, b.x), maxX = max(a.x, b.x)
        let minY = min(a.y, b.y), maxY = max(a.y, b.y)
        let cx = Double(minX + maxX) / 2.0
        let cy = Double(minY + maxY) / 2.0
        let rx = Double(maxX - minX) / 2.0
        let ry = Double(maxY - minY) / 2.0

        guard rx > 0 || ry > 0 else {
            setPixel(x: minX, y: minY, value: value)
            return
        }

        if filled {
            for y in minY...maxY {
                for x in minX...maxX {
                    let dx = (Double(x) - cx) / max(rx, 0.5)
                    let dy = (Double(y) - cy) / max(ry, 0.5)
                    if dx * dx + dy * dy <= 1.0 {
                        setPixel(x: x, y: y, value: value)
                    }
                }
            }
        } else {
            let steps = max(Int(max(rx, ry)) * 8, 32)
            for i in 0...steps {
                let angle = Double(i) / Double(steps) * 2.0 * .pi
                let x = Int(round(cx + rx * cos(angle)))
                let y = Int(round(cy + ry * sin(angle)))
                setPixel(x: x, y: y, value: value)
            }
        }
    }

    // MARK: - Flood fill

    private func floodFill(startX: Int, startY: Int, target: UInt8, replacement: UInt8) {
        guard target != replacement else { return }

        var stack = [(startX, startY)]
        var visited = Set<Int>()

        while let (cx, cy) = stack.popLast() {
            guard cx >= 0, cx < canvasWidth, cy >= 0, cy < canvasHeight else { continue }
            let key = cy * canvasWidth + cx
            guard !visited.contains(key) else { continue }
            guard key < pixels.count, pixels[key] == target else { continue }

            visited.insert(key)
            pixels[key] = replacement

            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }
    }

    // MARK: - Ghost frame rendering (light table)

    private func drawGhostFrame(ctx: CGContext, ghostPixels: [UInt8], cellSize: CGFloat,
                                tintR: CGFloat, tintG: CGFloat, tintB: CGFloat, alpha: CGFloat) {
        for py in 0..<canvasHeight {
            for px in 0..<canvasWidth {
                let idx = py * canvasWidth + px
                guard idx < ghostPixels.count else { continue }
                let colorIdx = Int(ghostPixels[idx])
                if colorIdx == 0 { continue }
                // Blend original palette color with tint
                let snesColor = palette[colorIdx]
                let r = (CGFloat(snesColor.red) / 31.0 + tintR) / 2.0
                let g = (CGFloat(snesColor.green) / 31.0 + tintG) / 2.0
                let b = (CGFloat(snesColor.blue) / 31.0 + tintB) / 2.0
                ctx.setFillColor(NSColor(red: r, green: g, blue: b, alpha: alpha).cgColor)
                ctx.fill(CGRect(
                    x: CGFloat(px) * cellSize,
                    y: CGFloat(py) * cellSize,
                    width: cellSize,
                    height: cellSize
                ))
            }
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
