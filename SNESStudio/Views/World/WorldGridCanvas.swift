import SwiftUI
import AppKit

// MARK: - NSView Canvas

final class WorldGridNSView: NSView {
    var zone: WorldZone = .empty()
    var screens: [WorldScreen] = []
    var selectedScreenID: UUID?
    var onSelectScreen: ((UUID?) -> Void)?
    var onDoubleClickScreen: ((UUID) -> Void)?
    var zoomScale: CGFloat = 1.0

    private let cellSize: CGFloat = 80
    private let padding: CGFloat = 20

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let scale = zoomScale
        let cSize = cellSize * scale

        // Background
        NSColor(SNESTheme.bgEditor).setFill()
        ctx.fill(bounds)

        // Draw grid
        for row in 0..<zone.gridHeight {
            for col in 0..<zone.gridWidth {
                let rect = CGRect(
                    x: padding + CGFloat(col) * cSize,
                    y: padding + CGFloat(row) * cSize,
                    width: cSize - 2,
                    height: cSize - 2
                )

                let screen = screens.first { $0.zoneID == zone.id && $0.gridX == col && $0.gridY == row }

                if let screen = screen {
                    // Filled cell
                    let isSelected = screen.id == selectedScreenID
                    let bgColor = isSelected
                        ? NSColor(Color(hex: zone.colorHex)).withAlphaComponent(0.4)
                        : NSColor(Color(hex: zone.colorHex)).withAlphaComponent(0.15)
                    bgColor.setFill()
                    let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
                    path.fill()

                    // Border
                    let borderColor = isSelected
                        ? NSColor(Color(hex: zone.colorHex))
                        : NSColor(SNESTheme.border)
                    borderColor.setStroke()
                    path.lineWidth = isSelected ? 2 : 1
                    path.stroke()

                    // Screen name
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 9 * scale, weight: .medium),
                        .foregroundColor: NSColor(SNESTheme.textPrimary),
                    ]
                    let name = screen.name as NSString
                    let textSize = name.size(withAttributes: attrs)
                    let textPoint = CGPoint(
                        x: rect.midX - textSize.width / 2,
                        y: rect.midY - textSize.height / 2
                    )
                    name.draw(at: textPoint, withAttributes: attrs)
                } else {
                    // Empty cell — checkerboard
                    let checker1 = NSColor(SNESTheme.bgPanel)
                    let checker2 = NSColor(SNESTheme.bgEditor)

                    let half = cSize / 2 - 1
                    for cr in 0..<2 {
                        for cc in 0..<2 {
                            let c = (cr + cc) % 2 == 0 ? checker1 : checker2
                            c.setFill()
                            let r = CGRect(
                                x: rect.minX + CGFloat(cc) * half,
                                y: rect.minY + CGFloat(cr) * half,
                                width: half, height: half
                            )
                            ctx.fill(r)
                        }
                    }

                    // Dashed border
                    NSColor(SNESTheme.border).withAlphaComponent(0.3).setStroke()
                    let dashed = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
                    let pattern: [CGFloat] = [4, 4]
                    dashed.setLineDash(pattern, count: 2, phase: 0)
                    dashed.lineWidth = 1
                    dashed.stroke()
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let scale = zoomScale
        let cSize = cellSize * scale

        let col = Int((point.x - padding) / cSize)
        let row = Int((point.y - padding) / cSize)

        if col >= 0 && col < zone.gridWidth && row >= 0 && row < zone.gridHeight {
            if let screen = screens.first(where: { $0.zoneID == zone.id && $0.gridX == col && $0.gridY == row }) {
                onSelectScreen?(screen.id)
                if event.clickCount == 2 {
                    onDoubleClickScreen?(screen.id)
                }
            } else {
                onSelectScreen?(nil)
            }
        }
        needsDisplay = true
    }

    func updateContent(zone: WorldZone, screens: [WorldScreen], selectedScreenID: UUID?, zoom: CGFloat) {
        self.zone = zone
        self.screens = screens
        self.selectedScreenID = selectedScreenID
        self.zoomScale = zoom
        needsDisplay = true
    }
}

// MARK: - SwiftUI Wrapper

struct WorldGridCanvas: NSViewRepresentable {
    let zone: WorldZone
    let screens: [WorldScreen]
    let selectedScreenID: UUID?
    let zoom: CGFloat
    var onSelectScreen: (UUID?) -> Void
    var onDoubleClickScreen: ((UUID) -> Void)?

    func makeNSView(context: Context) -> WorldGridNSView {
        let view = WorldGridNSView()
        view.onSelectScreen = onSelectScreen
        view.onDoubleClickScreen = onDoubleClickScreen
        view.updateContent(zone: zone, screens: screens, selectedScreenID: selectedScreenID, zoom: zoom)
        return view
    }

    func updateNSView(_ nsView: WorldGridNSView, context: Context) {
        nsView.onSelectScreen = onSelectScreen
        nsView.onDoubleClickScreen = onDoubleClickScreen
        nsView.updateContent(zone: zone, screens: screens, selectedScreenID: selectedScreenID, zoom: zoom)
    }
}
