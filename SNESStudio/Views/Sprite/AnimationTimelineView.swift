import SwiftUI

struct AnimationTimelineView: View {
    @Binding var animations: [SpriteAnimation]
    @Binding var selectedIndex: Int
    var tiles: [SNESTile]
    var palettes: [SNESPalette]
    var onFrameSelected: ((Int) -> Void)?
    var onAnimationChanged: ((Int) -> Void)?

    @State private var isPlaying: Bool = false
    @State private var currentFrame: Int = 0
    @State private var playTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            SNESTheme.border.frame(height: 1)

            HStack(spacing: 0) {
                // Controls
                HStack(spacing: 8) {
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(SNESTheme.info)
                    }
                    .buttonStyle(.plain)

                    if hasAnimation {
                        Toggle("Loop", isOn: $animations[selectedIndex].loop)
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(width: 120)

                SNESTheme.border.frame(width: 1)

                // Timeline
                if hasAnimation {
                    ScrollView(.horizontal) {
                        HStack(spacing: 2) {
                            ForEach(animations[selectedIndex].frames.indices, id: \.self) { idx in
                                frameCell(index: idx)
                            }

                            // Add frame button
                            Button {
                                animations[selectedIndex].frames.append(SpriteFrame())
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                    .foregroundStyle(SNESTheme.textDisabled)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(SNESTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                } else {
                    Spacer()
                    Text("No animation selected")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SNESTheme.bgPanel)
        }
        .onDisappear { stopPlayback() }
        .onChange(of: selectedIndex) {
            let wasPlaying = isPlaying
            stopPlayback()
            currentFrame = 0
            onAnimationChanged?(selectedIndex)
            if wasPlaying {
                startPlayback()
            }
        }
    }

    private var hasAnimation: Bool {
        !animations.isEmpty && selectedIndex < animations.count
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard hasAnimation else { return }
        let anim = animations[selectedIndex]
        guard !anim.frames.isEmpty else { return }
        isPlaying = true
        scheduleNextFrame()
    }

    private func stopPlayback() {
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
    }

    private func scheduleNextFrame() {
        playTimer?.invalidate()
        guard isPlaying, hasAnimation else { return }
        let anim = animations[selectedIndex]
        guard !anim.frames.isEmpty else { stopPlayback(); return }

        let safeFrame = min(currentFrame, anim.frames.count - 1)
        let duration = anim.frames[safeFrame].duration
        // SNES VBlank = ~16.67ms (60fps)
        let interval = Double(max(duration, 1)) / 60.0

        playTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            DispatchQueue.main.async {
                advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        guard isPlaying, hasAnimation else { stopPlayback(); return }
        let anim = animations[selectedIndex]
        guard !anim.frames.isEmpty else { stopPlayback(); return }

        let nextFrame = currentFrame + 1
        if nextFrame >= anim.frames.count {
            if anim.loop {
                selectFrame(0)
            } else {
                stopPlayback()
                return
            }
        } else {
            selectFrame(nextFrame)
        }
        scheduleNextFrame()
    }

    private func selectFrame(_ index: Int) {
        currentFrame = index
        onFrameSelected?(index)
    }

    // MARK: - Frame cell

    private func frameCell(index: Int) -> some View {
        let frame = animations[selectedIndex].frames[index]
        let isSelected = currentFrame == index

        return Button {
            stopPlayback()
            selectFrame(index)
        } label: {
            VStack(spacing: 2) {
                // Sprite thumbnail
                Canvas { ctx, size in
                    drawCheckerboard(ctx: ctx, size: size)
                    drawFrameSprites(ctx: ctx, size: size, frame: frame)
                }
                .frame(width: 56, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 2))

                Text("\(frame.duration)f")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? SNESTheme.info : SNESTheme.border, lineWidth: isSelected ? 2 : 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? SNESTheme.info.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drawing helpers

    private func drawCheckerboard(ctx: GraphicsContext, size: CGSize) {
        let cs: CGFloat = 4
        for row in 0..<Int(size.height / cs) + 1 {
            for col in 0..<Int(size.width / cs) + 1 {
                let light = (row + col) % 2 == 0
                ctx.fill(Path(CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs, width: cs, height: cs)),
                         with: .color(light ? Color(white: 0.15) : Color(white: 0.11)))
            }
        }
    }

    private func drawFrameSprites(ctx: GraphicsContext, size: CGSize, frame: SpriteFrame) {
        guard !frame.entries.isEmpty else { return }

        // Compute bounding box of all OAM entries
        var minX = Int.max, minY = Int.max
        var maxX = Int.min, maxY = Int.min
        for entry in frame.entries {
            let s = entry.size.pixelSize
            minX = min(minX, entry.x)
            minY = min(minY, entry.y)
            maxX = max(maxX, entry.x + s)
            maxY = max(maxY, entry.y + s)
        }
        let bboxW = CGFloat(max(maxX - minX, 1))
        let bboxH = CGFloat(max(maxY - minY, 1))
        let fitScale = min(size.width / bboxW, size.height / bboxH) * 0.85
        let offX = (size.width - bboxW * fitScale) / 2 - CGFloat(minX) * fitScale
        let offY = (size.height - bboxH * fitScale) / 2 - CGFloat(minY) * fitScale

        for entry in frame.entries {
            guard entry.tileIndex < tiles.count else { continue }
            let tile = tiles[entry.tileIndex]
            let pal = palettes[min(entry.paletteIndex, palettes.count - 1)]
            let px = CGFloat(entry.x) * fitScale + offX
            let py = CGFloat(entry.y) * fitScale + offY

            for ty in 0..<8 {
                for tx in 0..<8 {
                    let srcX = entry.flipH ? (7 - tx) : tx
                    let srcY = entry.flipV ? (7 - ty) : ty
                    let colorIdx = Int(tile.pixel(x: srcX, y: srcY))
                    if colorIdx == 0 { continue }
                    let snesColor = pal[colorIdx]
                    let rect = CGRect(
                        x: px + CGFloat(tx) * fitScale,
                        y: py + CGFloat(ty) * fitScale,
                        width: max(fitScale, 1),
                        height: max(fitScale, 1)
                    )
                    ctx.fill(Path(rect), with: .color(snesColor.color))
                }
            }
        }
    }
}
