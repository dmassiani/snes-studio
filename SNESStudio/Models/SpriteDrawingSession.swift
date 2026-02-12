import Foundation
import CoreGraphics

@Observable
final class SpriteDrawingSession {
    // MARK: - Input context
    var metaSpriteIndex: Int = 0
    var animationIndex: Int = 0
    var paletteIndex: Int = 0
    var tileDepth: TileDepth = .bpp4

    // MARK: - Canvas
    var canvasWidth: Int = 32
    var canvasHeight: Int = 32
    var canvasPixels: [UInt8] = []

    // MARK: - Animation frames
    var animationName: String = ""
    var allFramePixels: [[UInt8]] = []
    var currentFrameIndex: Int = 0
    var originalFrames: [SpriteFrame] = []

    var frameCount: Int { allFramePixels.count }
    var hasAnimation: Bool { allFramePixels.count > 1 }

    // MARK: - BG preview
    var bgSnapshot: CGImage?
    var spriteScreenX: Int = 128
    var spriteScreenY: Int = 112

    // MARK: - Lifecycle
    var isActive: Bool = false
    var onSaveAllFrames: (([SNESTile], [SpriteFrame]) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Init canvas

    func initCanvas(width: Int, height: Int) {
        canvasWidth = width
        canvasHeight = height
        canvasPixels = Array(repeating: 0, count: width * height)
        allFramePixels = [canvasPixels]
        currentFrameIndex = 0
        originalFrames = [SpriteFrame()]
    }

    // MARK: - Pixel access

    func pixel(x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < canvasWidth, y >= 0, y < canvasHeight else { return 0 }
        return canvasPixels[y * canvasWidth + x]
    }

    func setPixel(x: Int, y: Int, value: UInt8) {
        guard x >= 0, x < canvasWidth, y >= 0, y < canvasHeight else { return }
        let clamped = min(value, UInt8(tileDepth.maxColorIndex))
        canvasPixels[y * canvasWidth + x] = clamped
    }

    // MARK: - Load animation

    /// Load all frames of an animation, rendering each frame's OAM entries into pixel buffers.
    func loadAnimation(animation: SpriteAnimation, tiles: [SNESTile]) {
        animationName = animation.name
        originalFrames = animation.frames

        guard !animation.frames.isEmpty else {
            initCanvas(width: 32, height: 32)
            return
        }

        // Compute bounding box across ALL frames for consistent canvas size
        var globalMinX = Int.max, globalMinY = Int.max
        var globalMaxX = Int.min, globalMaxY = Int.min

        for frame in animation.frames {
            for entry in frame.entries {
                let s = entry.size.pixelSize
                globalMinX = min(globalMinX, entry.x)
                globalMinY = min(globalMinY, entry.y)
                globalMaxX = max(globalMaxX, entry.x + s)
                globalMaxY = max(globalMaxY, entry.y + s)
            }
        }

        // Handle empty animation (no entries in any frame)
        if globalMinX == Int.max {
            initCanvas(width: 32, height: 32)
            allFramePixels = animation.frames.map { _ in
                Array(repeating: UInt8(0), count: 32 * 32)
            }
            currentFrameIndex = 0
            return
        }

        // Snap to 8-pixel grid, minimum 8x8
        let w = max(((globalMaxX - globalMinX + 7) / 8) * 8, 8)
        let h = max(((globalMaxY - globalMinY + 7) / 8) * 8, 8)
        canvasWidth = w
        canvasHeight = h

        // Render each frame into its own pixel buffer
        allFramePixels = animation.frames.map { frame in
            renderFrameToPixels(frame: frame, tiles: tiles, offsetX: globalMinX, offsetY: globalMinY)
        }

        currentFrameIndex = 0
        canvasPixels = allFramePixels[0]
    }

    /// Render a single frame's OAM entries into a flat pixel buffer.
    private func renderFrameToPixels(frame: SpriteFrame, tiles: [SNESTile], offsetX: Int, offsetY: Int) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)

        for entry in frame.entries {
            guard entry.tileIndex < tiles.count else { continue }
            let s = entry.size.pixelSize
            let tilesPerRow = s / 8

            for tileRow in 0..<tilesPerRow {
                for tileCol in 0..<tilesPerRow {
                    let tileIdx = entry.tileIndex + tileRow * 16 + tileCol
                    guard tileIdx < tiles.count else { continue }
                    let t = tiles[tileIdx]

                    for py in 0..<8 {
                        for px in 0..<8 {
                            let srcX = entry.flipH ? (7 - px) : px
                            let srcY = entry.flipV ? (7 - py) : py
                            let colorIdx = t.pixel(x: srcX, y: srcY)
                            if colorIdx == 0 { continue }

                            let canvasX = entry.x - offsetX + tileCol * 8 + px
                            let canvasY = entry.y - offsetY + tileRow * 8 + py
                            guard canvasX >= 0, canvasX < canvasWidth,
                                  canvasY >= 0, canvasY < canvasHeight else { continue }
                            buf[canvasY * canvasWidth + canvasX] = colorIdx
                        }
                    }
                }
            }
        }
        return buf
    }

    // MARK: - Populate from single entries (backward compat)

    func populateFromEntries(entries: [OAMEntry], tiles: [SNESTile]) {
        guard !entries.isEmpty else { return }

        var minX = Int.max, minY = Int.max
        var maxX = Int.min, maxY = Int.min
        for entry in entries {
            let s = entry.size.pixelSize
            minX = min(minX, entry.x)
            minY = min(minY, entry.y)
            maxX = max(maxX, entry.x + s)
            maxY = max(maxY, entry.y + s)
        }

        let w = max(((maxX - minX + 7) / 8) * 8, 8)
        let h = max(((maxY - minY + 7) / 8) * 8, 8)
        canvasWidth = w
        canvasHeight = h
        canvasPixels = Array(repeating: 0, count: w * h)

        let frame = SpriteFrame(entries: entries)
        canvasPixels = renderFrameToPixels(frame: frame, tiles: tiles, offsetX: minX, offsetY: minY)
        allFramePixels = [canvasPixels]
        originalFrames = [frame]
        currentFrameIndex = 0
    }

    // MARK: - Frame navigation

    /// Save current pixel state into allFramePixels before switching.
    func saveCurrentFrame(_ pixels: [UInt8]) {
        guard currentFrameIndex < allFramePixels.count else { return }
        allFramePixels[currentFrameIndex] = pixels
    }

    /// Navigate to a specific frame. Returns the new frame's pixel buffer.
    func goToFrame(_ index: Int, savingCurrent pixels: [UInt8]) -> [UInt8]? {
        guard index >= 0, index < allFramePixels.count, index != currentFrameIndex else { return nil }
        // Save current
        allFramePixels[currentFrameIndex] = pixels
        // Load new
        currentFrameIndex = index
        canvasPixels = allFramePixels[index]
        return allFramePixels[index]
    }

    /// Previous frame pixels for light table (nil if no previous)
    var prevFramePixels: [UInt8]? {
        let idx = currentFrameIndex - 1
        guard idx >= 0 else { return nil }
        return allFramePixels[idx]
    }

    /// Next frame pixels for light table (nil if no next)
    var nextFramePixels: [UInt8]? {
        let idx = currentFrameIndex + 1
        guard idx < allFramePixels.count else { return nil }
        return allFramePixels[idx]
    }

    // MARK: - Frame management

    /// Add a new empty frame after the current one. Returns the new frame's pixels.
    func addFrame(savingCurrent pixels: [UInt8]) -> [UInt8] {
        return insertEmptyFrame(after: currentFrameIndex, savingCurrent: pixels)
    }

    /// Insert an empty frame after a given index. Returns the new frame's pixels.
    func insertEmptyFrame(after index: Int, savingCurrent pixels: [UInt8]) -> [UInt8] {
        allFramePixels[currentFrameIndex] = pixels
        let emptyFrame = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        let insertAt = index + 1
        allFramePixels.insert(emptyFrame, at: insertAt)
        originalFrames.insert(SpriteFrame(entries: [], duration: 4), at: min(insertAt, originalFrames.count))
        currentFrameIndex = insertAt
        canvasPixels = emptyFrame
        return emptyFrame
    }

    /// Duplicate the current frame. Returns the duplicated frame's pixels.
    func duplicateFrame(savingCurrent pixels: [UInt8]) -> [UInt8] {
        return duplicateFrame(at: currentFrameIndex, savingCurrent: pixels)
    }

    /// Duplicate a specific frame. Returns the duplicated frame's pixels.
    func duplicateFrame(at index: Int, savingCurrent pixels: [UInt8]) -> [UInt8] {
        allFramePixels[currentFrameIndex] = pixels
        let source = allFramePixels[index]
        let insertAt = index + 1
        allFramePixels.insert(source, at: insertAt)
        let origFrame = index < originalFrames.count
            ? originalFrames[index]
            : SpriteFrame(entries: [], duration: 4)
        originalFrames.insert(origFrame, at: min(insertAt, originalFrames.count))
        currentFrameIndex = insertAt
        canvasPixels = source
        return source
    }

    /// Delete the current frame. Returns the new current frame's pixels, or nil if only 1 frame.
    func deleteFrame(savingCurrent pixels: [UInt8]) -> [UInt8]? {
        return deleteFrame(at: currentFrameIndex, savingCurrent: pixels)
    }

    /// Delete a specific frame. Returns the new current frame's pixels, or nil if only 1 frame.
    func deleteFrame(at index: Int, savingCurrent pixels: [UInt8]) -> [UInt8]? {
        guard allFramePixels.count > 1 else { return nil }
        allFramePixels[currentFrameIndex] = pixels
        allFramePixels.remove(at: index)
        if index < originalFrames.count {
            originalFrames.remove(at: index)
        }
        // Adjust currentFrameIndex
        if currentFrameIndex >= allFramePixels.count {
            currentFrameIndex = allFramePixels.count - 1
        } else if currentFrameIndex > index {
            currentFrameIndex -= 1
        } else if currentFrameIndex == index, currentFrameIndex >= allFramePixels.count {
            currentFrameIndex = allFramePixels.count - 1
        }
        canvasPixels = allFramePixels[currentFrameIndex]
        return canvasPixels
    }

    /// Swap frame at index with its neighbor. delta = -1 for left, +1 for right.
    func moveFrame(at index: Int, delta: Int, savingCurrent pixels: [UInt8]) {
        let target = index + delta
        guard target >= 0, target < allFramePixels.count else { return }
        allFramePixels[currentFrameIndex] = pixels
        allFramePixels.swapAt(index, target)
        if index < originalFrames.count, target < originalFrames.count {
            originalFrames.swapAt(index, target)
        }
        if currentFrameIndex == index {
            currentFrameIndex = target
        } else if currentFrameIndex == target {
            currentFrameIndex = index
        }
        canvasPixels = allFramePixels[currentFrameIndex]
    }

    /// Move a frame from one position to another (for drag & drop reorder).
    func reorderFrame(from source: Int, to destination: Int, savingCurrent pixels: [UInt8]) {
        guard source != destination,
              source >= 0, source < allFramePixels.count,
              destination >= 0, destination < allFramePixels.count else { return }
        allFramePixels[currentFrameIndex] = pixels

        let movedPixels = allFramePixels.remove(at: source)
        allFramePixels.insert(movedPixels, at: destination)

        if source < originalFrames.count {
            let movedFrame = originalFrames.remove(at: source)
            originalFrames.insert(movedFrame, at: min(destination, originalFrames.count))
        }

        // Track where the current frame ended up
        if currentFrameIndex == source {
            currentFrameIndex = destination
        } else if source < currentFrameIndex, destination >= currentFrameIndex {
            currentFrameIndex -= 1
        } else if source > currentFrameIndex, destination <= currentFrameIndex {
            currentFrameIndex += 1
        }
        canvasPixels = allFramePixels[currentFrameIndex]
    }

    // MARK: - Reset

    func reset() {
        isActive = false
        canvasPixels = []
        canvasWidth = 32
        canvasHeight = 32
        bgSnapshot = nil
        onSaveAllFrames = nil
        onCancel = nil
        allFramePixels = []
        originalFrames = []
        currentFrameIndex = 0
        animationName = ""
    }
}
