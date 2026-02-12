import AppKit

enum TilemapTool {
    case stamp, eraser, fill, eyedropper
}

final class TilemapCanvas: NSView {
    var tilemap: SNESTilemap = .empty() {
        didSet { if tilemap != oldValue { needsDisplay = true } }
    }
    var tiles: [SNESTile] = [] {
        didSet { if tiles != oldValue { needsDisplay = true } }
    }
    var palettes: [SNESPalette] = SNESPalette.defaultPalettes() {
        didSet { if palettes != oldValue { needsDisplay = true } }
    }
    var showGrid: Bool = true {
        didSet { if showGrid != oldValue { needsDisplay = true } }
    }
    var zoom: CGFloat = 2 {
        didSet { if zoom != oldValue { invalidateIntrinsicContentSize(); needsDisplay = true } }
    }
    var selectedTileIndex: Int = 0
    var selectedPaletteIndex: Int = 0
    var currentTool: TilemapTool = .stamp
    var onEntryChanged: ((Int, Int, TilemapEntry) -> Void)?
    var onCellSelected: ((Int, Int) -> Void)?
    var onBeginEdit: (() -> Void)?
    var onTilePicked: ((Int, Int) -> Void)?

    override var intrinsicContentSize: NSSize {
        let cellSize = 8 * zoom
        return NSSize(
            width: CGFloat(tilemap.width) * cellSize,
            height: CGFloat(tilemap.height) * cellSize
        )
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cellSize = 8 * zoom
        let pixSize = zoom

        // Draw transparency checkerboard background
        let checkSize: CGFloat = max(zoom * 2, 4)
        let checkLight = NSColor(white: 0.18, alpha: 1).cgColor
        let checkDark = NSColor(white: 0.12, alpha: 1).cgColor
        let totalW = CGFloat(tilemap.width) * cellSize
        let totalH = CGFloat(tilemap.height) * cellSize
        let checksX = Int(ceil(totalW / checkSize))
        let checksY = Int(ceil(totalH / checkSize))
        for j in 0..<checksY {
            for i in 0..<checksX {
                ctx.setFillColor((i + j) % 2 == 0 ? checkLight : checkDark)
                ctx.fill(CGRect(
                    x: CGFloat(i) * checkSize,
                    y: CGFloat(j) * checkSize,
                    width: checkSize, height: checkSize
                ))
            }
        }

        // Draw tiles (skip colorIdx 0 = transparent)
        for cy in 0..<tilemap.height {
            for cx in 0..<tilemap.width {
                let entry = tilemap.entry(x: cx, y: cy)
                let baseX = CGFloat(cx) * cellSize
                let baseY = CGFloat(cy) * cellSize

                if entry.tileIndex < tiles.count {
                    let tile = tiles[entry.tileIndex]
                    let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]
                    for py in 0..<8 {
                        for px in 0..<8 {
                            let tx = entry.flipH ? (7 - px) : px
                            let ty = entry.flipV ? (7 - py) : py
                            let colorIdx = Int(tile.pixel(x: tx, y: ty))
                            if colorIdx == 0 { continue } // Transparent
                            let snesColor = pal[colorIdx]
                            ctx.setFillColor(snesColor.nsColor.cgColor)
                            ctx.fill(CGRect(
                                x: baseX + CGFloat(px) * pixSize,
                                y: baseY + CGFloat(py) * pixSize,
                                width: pixSize, height: pixSize
                            ))
                        }
                    }
                } else {
                    // Invalid tile index: red-ish indicator
                    ctx.setFillColor(NSColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 0.5).cgColor)
                    ctx.fill(CGRect(x: baseX, y: baseY, width: cellSize, height: cellSize))
                }
            }
        }

        if showGrid {
            ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(0.5)
            for i in 0...tilemap.width {
                let x = CGFloat(i) * cellSize
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: CGFloat(tilemap.height) * cellSize))
            }
            for j in 0...tilemap.height {
                let y = CGFloat(j) * cellSize
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: CGFloat(tilemap.width) * cellSize, y: y))
            }
            ctx.strokePath()
        }
    }

    // MARK: - Mouse events

    private var editStarted = false

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let cellSize = 8 * zoom
        let cx = Int(loc.x / cellSize)
        let cy = Int(loc.y / cellSize)
        guard cx >= 0, cx < tilemap.width, cy >= 0, cy < tilemap.height else { return }

        onCellSelected?(cx, cy)

        // Alt+click = eyedropper from any tool
        let activeTool = event.modifierFlags.contains(.option) ? TilemapTool.eyedropper : currentTool

        switch activeTool {
        case .stamp:
            if !editStarted { onBeginEdit?(); editStarted = true }
            placeStamp(cx: cx, cy: cy)
        case .eraser:
            if !editStarted { onBeginEdit?(); editStarted = true }
            eraseCell(cx: cx, cy: cy)
        case .fill:
            if !editStarted { onBeginEdit?(); editStarted = true }
            let targetIndex = tilemap.entry(x: cx, y: cy).tileIndex
            let replacement = TilemapEntry(
                tileIndex: selectedTileIndex,
                paletteIndex: selectedPaletteIndex,
                flipH: false, flipV: false, priority: false
            )
            floodFill(startX: cx, startY: cy, targetIndex: targetIndex, replacement: replacement)
            needsDisplay = true
        case .eyedropper:
            let entry = tilemap.entry(x: cx, y: cy)
            onTilePicked?(entry.tileIndex, entry.paletteIndex)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let cellSize = 8 * zoom
        let cx = Int(loc.x / cellSize)
        let cy = Int(loc.y / cellSize)
        guard cx >= 0, cx < tilemap.width, cy >= 0, cy < tilemap.height else { return }

        onCellSelected?(cx, cy)

        let activeTool = event.modifierFlags.contains(.option) ? TilemapTool.eyedropper : currentTool

        switch activeTool {
        case .stamp:
            placeStamp(cx: cx, cy: cy)
        case .eraser:
            eraseCell(cx: cx, cy: cy)
        case .fill, .eyedropper:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        editStarted = false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Tool actions

    private func placeStamp(cx: Int, cy: Int) {
        var entry = TilemapEntry()
        entry.tileIndex = selectedTileIndex
        entry.paletteIndex = selectedPaletteIndex
        tilemap.setEntry(x: cx, y: cy, entry: entry)
        needsDisplay = true
        onEntryChanged?(cx, cy, entry)
    }

    private func eraseCell(cx: Int, cy: Int) {
        let entry = TilemapEntry(tileIndex: 0, paletteIndex: 0, flipH: false, flipV: false, priority: false)
        tilemap.setEntry(x: cx, y: cy, entry: entry)
        needsDisplay = true
        onEntryChanged?(cx, cy, entry)
    }

    private func floodFill(startX: Int, startY: Int, targetIndex: Int, replacement: TilemapEntry) {
        guard targetIndex != replacement.tileIndex else { return }

        var stack = [(startX, startY)]
        var visited = Set<Int>()

        while let (x, y) = stack.popLast() {
            let key = y * tilemap.width + x
            guard x >= 0, x < tilemap.width, y >= 0, y < tilemap.height,
                  !visited.contains(key),
                  tilemap.entry(x: x, y: y).tileIndex == targetIndex else { continue }

            visited.insert(key)
            tilemap.setEntry(x: x, y: y, entry: replacement)
            onEntryChanged?(x, y, replacement)

            stack.append((x - 1, y))
            stack.append((x + 1, y))
            stack.append((x, y - 1))
            stack.append((x, y + 1))
        }
    }
}
