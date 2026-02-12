import SwiftUI

struct ParallaxPreviewView: View {
    var level: SNESLevel
    var tiles: [SNESTile]
    var palettes: [SNESPalette]

    @State private var isPlaying: Bool = false
    @State private var cameraOffset: Double = 0

    // SNES screen: 256x224, scaled to fit ~200px wide
    private let screenW: Double = 256
    private let screenH: Double = 224
    private let displayScale: Double = 0.625 // 256 * 0.625 = 160

    var body: some View {
        VStack(spacing: 4) {
            // Play/pause button
            HStack {
                Button {
                    isPlaying.toggle()
                    if !isPlaying { cameraOffset = 0 }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.info)
                }
                .buttonStyle(.plain)

                Text(isPlaying ? "Playing" : "Paused")
                    .font(.system(size: 9))
                    .foregroundStyle(SNESTheme.textDisabled)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Animated canvas
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
                Canvas { ctx, size in
                    let scaleX = size.width / screenW
                    let scaleY = size.height / screenH

                    // Update camera
                    let cam = cameraOffset

                    // Draw layers back to front
                    for layerIdx in stride(from: level.layers.count - 1, through: 0, by: -1) {
                        let layer = level.layers[layerIdx]
                        guard layer.visible else { continue }

                        let scrollX = cam * layer.scrollRatioX
                        let tm = layer.tilemap
                        let tmWidthPx = Double(tm.width * 8)

                        // How many pixels of the viewport each tile covers
                        for cy in 0..<min(tm.height, 28) {
                            for cx in 0..<tm.width {
                                let entry = tm.entry(x: cx, y: cy)
                                guard entry.tileIndex > 0, entry.tileIndex < tiles.count else { continue }

                                var worldX = Double(cx * 8) - scrollX
                                if layer.repeatX && tmWidthPx > 0 {
                                    worldX = worldX.truncatingRemainder(dividingBy: tmWidthPx)
                                    if worldX < -8 { worldX += tmWidthPx }
                                }

                                // Skip tiles outside viewport
                                guard worldX > -8, worldX < screenW else { continue }

                                let tile = tiles[entry.tileIndex]
                                let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]

                                // Draw each pixel of the 8x8 tile
                                for py in 0..<8 {
                                    for px in 0..<8 {
                                        let tx = entry.flipH ? (7 - px) : px
                                        let ty = entry.flipV ? (7 - py) : py
                                        let colorIdx = Int(tile.pixel(x: tx, y: ty))
                                        guard colorIdx > 0 else { continue }
                                        let c = pal[colorIdx]
                                        let rect = CGRect(
                                            x: (worldX + Double(px)) * scaleX,
                                            y: Double(cy * 8 + py) * scaleY,
                                            width: scaleX + 0.5,
                                            height: scaleY + 0.5
                                        )
                                        ctx.fill(Path(rect), with: .color(c.color))
                                    }
                                }
                            }
                        }
                    }
                }
                .onChange(of: timeline.date) { _, _ in
                    if isPlaying {
                        cameraOffset += 0.8
                        // Reset when past the widest layer
                        let maxW = level.layers.first.map { Double($0.tilemap.width * 8) } ?? 1024
                        if cameraOffset > maxW { cameraOffset = 0 }
                    }
                }
            }
            .frame(height: displayScale * screenH)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(SNESTheme.border, lineWidth: 1)
            )
        }
    }
}
