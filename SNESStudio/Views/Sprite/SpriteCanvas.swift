import AppKit

final class SpriteCanvas: NSView {
    var entries: [OAMEntry] = [] {
        didSet { if entries != oldValue { needsDisplay = true } }
    }
    var tiles: [SNESTile] = [] {
        didSet { if tiles != oldValue { needsDisplay = true } }
    }
    var palettes: [SNESPalette] = SNESPalette.defaultPalettes() {
        didSet { if palettes != oldValue { needsDisplay = true } }
    }
    var selectedEntryIndex: Int? = nil {
        didSet { if selectedEntryIndex != oldValue { needsDisplay = true } }
    }
    var showGrid: Bool = false {
        didSet { if showGrid != oldValue { needsDisplay = true } }
    }
    var zoom: CGFloat = 2.0 {
        didSet { if zoom != oldValue { invalidateIntrinsicContentSize(); needsDisplay = true } }
    }
    var onEntrySelected: ((Int) -> Void)?
    var onEntryMoved: ((Int, Int, Int) -> Void)?
    var onBeginEdit: (() -> Void)?

    private var dragIndex: Int?
    private var editStarted = false
    private var dragOffset: NSPoint = .zero

    private let screenWidth: CGFloat = 256
    private let screenHeight: CGFloat = 224

    override var intrinsicContentSize: NSSize {
        NSSize(width: screenWidth * zoom, height: screenHeight * zoom)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let z = zoom

        // Background checkerboard (in zoomed space)
        let checkSize: CGFloat = 8 * z
        let totalW = screenWidth * z
        let totalH = screenHeight * z
        for cy in 0..<Int(ceil(totalH / checkSize)) {
            for cx in 0..<Int(ceil(totalW / checkSize)) {
                let isEven = (cx + cy) % 2 == 0
                ctx.setFillColor(NSColor(white: isEven ? 0.12 : 0.10, alpha: 1).cgColor)
                ctx.fill(CGRect(x: CGFloat(cx) * checkSize, y: CGFloat(cy) * checkSize, width: checkSize, height: checkSize))
            }
        }

        // Screen border
        ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: 0, y: 0, width: totalW, height: totalH))

        // Grid (8px SNES grid)
        if showGrid {
            ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(0.5)
            for i in stride(from: CGFloat(0), through: totalW, by: 8 * z) {
                ctx.move(to: CGPoint(x: i, y: 0))
                ctx.addLine(to: CGPoint(x: i, y: totalH))
            }
            for j in stride(from: CGFloat(0), through: totalH, by: 8 * z) {
                ctx.move(to: CGPoint(x: 0, y: j))
                ctx.addLine(to: CGPoint(x: totalW, y: j))
            }
            ctx.strokePath()
        }

        // Draw sprites
        for (idx, entry) in entries.enumerated() {
            let size = CGFloat(entry.size.pixelSize) * z
            let ex = CGFloat(entry.x) * z
            let ey = CGFloat(entry.y) * z
            let rect = CGRect(x: ex, y: ey, width: size, height: size)

            // Draw tile pixels if available
            if entry.tileIndex < tiles.count {
                let tile = tiles[entry.tileIndex]
                let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]
                let tilePixels = 8
                let pixScale = size / CGFloat(tilePixels)
                for py in 0..<tilePixels {
                    for px in 0..<tilePixels {
                        let tx = entry.flipH ? (tilePixels - 1 - px) : px
                        let ty = entry.flipV ? (tilePixels - 1 - py) : py
                        let colorIdx = Int(tile.pixel(x: tx, y: ty))
                        if colorIdx > 0 {
                            let snesColor = pal[colorIdx]
                            ctx.setFillColor(snesColor.nsColor.cgColor)
                            ctx.fill(CGRect(
                                x: ex + CGFloat(px) * pixScale,
                                y: ey + CGFloat(py) * pixScale,
                                width: pixScale, height: pixScale
                            ))
                        }
                    }
                }
            } else {
                let hue = CGFloat(idx % 8) / 8.0
                ctx.setFillColor(NSColor(hue: hue, saturation: 0.6, brightness: 0.7, alpha: 0.5).cgColor)
                ctx.fill(rect)
            }

            // Selection highlight
            if selectedEntryIndex == idx {
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(2)
                ctx.stroke(rect.insetBy(dx: -1, dy: -1))
            }
        }
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        if !editStarted {
            onBeginEdit?()
            editStarted = true
        }
        let raw = convert(event.locationInWindow, from: nil)
        let loc = NSPoint(x: raw.x / zoom, y: raw.y / zoom)

        // Find topmost sprite under cursor (reverse order = topmost)
        for idx in entries.indices.reversed() {
            let entry = entries[idx]
            let size = CGFloat(entry.size.pixelSize)
            let rect = CGRect(x: CGFloat(entry.x), y: CGFloat(entry.y), width: size, height: size)
            if rect.contains(loc) {
                dragIndex = idx
                dragOffset = NSPoint(x: loc.x - CGFloat(entry.x), y: loc.y - CGFloat(entry.y))
                onEntrySelected?(idx)
                needsDisplay = true
                return
            }
        }
        dragIndex = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let idx = dragIndex, idx < entries.count else { return }
        let raw = convert(event.locationInWindow, from: nil)
        let loc = NSPoint(x: raw.x / zoom, y: raw.y / zoom)
        let newX = max(-64, min(Int(loc.x - dragOffset.x), 255))
        let newY = max(-64, min(Int(loc.y - dragOffset.y), 223))
        onEntryMoved?(idx, newX, newY)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        editStarted = false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }
}
