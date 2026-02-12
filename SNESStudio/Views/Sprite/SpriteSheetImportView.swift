import SwiftUI
import AppKit

struct SpriteSheetImportView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    // Image state
    @State private var selectedImage: CGImage?
    @State private var imageWidth: Int = 0
    @State private var imageHeight: Int = 0
    @State private var imageName: String = ""

    // Config
    @State private var frameWidth: Int = 0
    @State private var frameHeight: Int = 0
    @State private var animName: String = "Imported"
    @State private var frameDuration: Int = 4
    @State private var tileDepth: TileDepth = .bpp4

    // Result preview
    @State private var result: SpriteSheetImportResult?
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(SNESTheme.info)
                Text("Import Sprite Sheet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SNESTheme.textPrimary)
                Spacer()
            }
            .padding(12)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) { SNESTheme.border.frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - File picker
                    imagePickerSection

                    if selectedImage != nil {
                        Divider().background(SNESTheme.border)
                        // MARK: - Settings
                        settingsSection

                        Divider().background(SNESTheme.border)
                        // MARK: - Preview
                        previewSection
                    }
                }
                .padding(16)
            }

            Divider().background(SNESTheme.border)

            // MARK: - Action buttons
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import") { performImport() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(result == nil)
            }
            .padding(12)
            .background(SNESTheme.bgPanel)
        }
        .frame(width: 520, height: 500)
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Image Picker Section

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sprite Sheet")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            HStack(spacing: 12) {
                Button {
                    chooseFile()
                } label: {
                    Label("Choose PNG...", systemImage: "photo")
                }

                if selectedImage != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(imageName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SNESTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(imageWidth) x \(imageHeight) px")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SNESTheme.textSecondary)
                        if frameWidth > 0 && frameHeight > 0 {
                            let cols = imageWidth / max(frameWidth, 1)
                            let rows = imageHeight / max(frameHeight, 1)
                            Text("\(cols * rows) frames (\(frameWidth)x\(frameHeight))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(SNESTheme.info)
                        }
                    }
                }

                Spacer()

                // Thumbnail
                if let img = selectedImage {
                    Image(decorative: img, scale: 1.0)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 160, maxHeight: 64)
                        .background {
                            // Checkerboard for transparency
                            Canvas { ctx, size in
                                let s: CGFloat = 4
                                for row in 0..<Int(size.height / s) + 1 {
                                    for col in 0..<Int(size.width / s) + 1 {
                                        let isLight = (row + col) % 2 == 0
                                        ctx.fill(Path(CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)),
                                                 with: .color(isLight ? Color(white: 0.2) : Color(white: 0.15)))
                                    }
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(SNESTheme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Frame size:")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .gridColumnAlignment(.trailing)
                    HStack(spacing: 4) {
                        TextField("W", value: $frameWidth, format: .number)
                            .frame(width: 56)
                            .textFieldStyle(.roundedBorder)
                        Text("x")
                            .foregroundStyle(SNESTheme.textDisabled)
                        TextField("H", value: $frameHeight, format: .number)
                            .frame(width: 56)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textDisabled)
                    }
                }

                GridRow {
                    Text("Animation:")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    TextField("Name", text: $animName)
                        .frame(width: 140)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Frame duration:")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    HStack(spacing: 4) {
                        TextField("VBlanks", value: $frameDuration, format: .number)
                            .frame(width: 56)
                            .textFieldStyle(.roundedBorder)
                        Text("VBlanks (~\(String(format: "%.0f", Double(frameDuration) / 60.0 * 1000)) ms)")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textDisabled)
                    }
                }

                GridRow {
                    Text("Depth:")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Picker("", selection: $tileDepth) {
                        ForEach(TileDepth.allCases, id: \.self) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }

            // Process button
            Button {
                processSheet()
            } label: {
                HStack(spacing: 4) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isProcessing ? "Processing..." : "Analyze")
                }
            }
            .disabled(selectedImage == nil || frameWidth <= 0 || frameHeight <= 0 || isProcessing)
        }
        .onChange(of: frameWidth) { processSheet() }
        .onChange(of: frameHeight) { processSheet() }
        .onChange(of: tileDepth) { processSheet() }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            if let result {
                // Palette preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Palette (\(result.stats.colorsFound) colors found, \(result.palette.colors.filter { $0.raw != 0 }.count) in palette)")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textSecondary)

                    HStack(spacing: 1) {
                        ForEach(0..<16, id: \.self) { i in
                            Rectangle()
                                .fill(result.palette.colors[i].color)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    if i == 0 {
                                        Text("T")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(SNESTheme.border, lineWidth: 1))
                }

                // Stats
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("Frames:")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Text("\(result.stats.totalFrames)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SNESTheme.textPrimary)
                    }
                    GridRow {
                        Text("Tiles:")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Text("\(result.stats.uniqueTileCount) unique / \(result.stats.rawTileCount) raw (\(Int(result.stats.dedupRatio * 100))% dedup)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SNESTheme.textPrimary)
                    }
                    GridRow {
                        Text("OAM/frame:")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Text("\(result.stats.oamPerFrame)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(result.stats.oamPerFrame > 128 ? SNESTheme.danger : SNESTheme.textPrimary)
                    }
                }

                // Warnings
                if !result.stats.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(result.stats.warnings, id: \.self) { w in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(SNESTheme.warning)
                                Text(w)
                                    .font(.system(size: 10))
                                    .foregroundStyle(SNESTheme.warning)
                            }
                        }
                    }
                }
            } else if selectedImage != nil && !isProcessing {
                Text("Adjust settings and click Analyze")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
    }

    // MARK: - Actions

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        panel.message = "Select a sprite sheet PNG"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            state.appendConsole("Failed to load image: \(url.lastPathComponent)", type: .error)
            return
        }

        selectedImage = cgImage
        imageWidth = cgImage.width
        imageHeight = cgImage.height
        imageName = url.lastPathComponent
        animName = url.deletingPathExtension().lastPathComponent

        // Auto-detect frame size
        if let detected = SpriteSheetImporter.detectFrameSize(imageWidth: imageWidth, imageHeight: imageHeight) {
            frameWidth = detected.width
            frameHeight = detected.height
        } else {
            frameWidth = imageWidth
            frameHeight = imageHeight
        }

        // Auto-process
        processSheet()
    }

    private func processSheet() {
        guard let image = selectedImage, frameWidth > 0, frameHeight > 0 else {
            result = nil
            return
        }
        guard frameWidth <= imageWidth && frameHeight <= imageHeight else {
            result = nil
            return
        }

        isProcessing = true
        let config = SpriteSheetImportConfig(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            tileDepth: tileDepth,
            animName: animName,
            frameDuration: frameDuration,
            tileCategory: "Sprite - \(animName)"
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let r = SpriteSheetImporter.processImage(image, config: config)
            DispatchQueue.main.async {
                result = r
                isProcessing = false
            }
        }
    }

    private func performImport() {
        guard let result else { return }

        // Try to find an existing palette that already contains all imported colors
        let (paletteIndex, colorRemap) = findMatchingPalette(for: result.palette)

        // Remap tile pixels if reusing an existing palette, otherwise use tiles as-is
        let importedTiles: [SNESTile]
        if let colorRemap {
            importedTiles = result.tiles.map { tile in
                var remapped = tile
                remapped.pixels = tile.pixels.map { colorRemap[Int($0)] }
                return remapped
            }
        } else {
            // New palette — assign it to the slot
            state.assetStore.palettes[paletteIndex] = result.palette
            importedTiles = result.tiles
        }

        // Deduplicate tiles against existing store tiles
        let (tileIndexMap, newTiles, deduped) = deduplicateTilesAgainstStore(importedTiles)

        // Append only truly new tiles
        state.assetStore.tiles.append(contentsOf: newTiles)

        // Remap tile indices in animation frames and set palette
        var remappedAnimation = result.animation
        for fi in 0..<remappedAnimation.frames.count {
            for ei in 0..<remappedAnimation.frames[fi].entries.count {
                let oldIdx = remappedAnimation.frames[fi].entries[ei].tileIndex
                remappedAnimation.frames[fi].entries[ei].tileIndex = tileIndexMap[oldIdx]
                remappedAnimation.frames[fi].entries[ei].paletteIndex = paletteIndex
            }
        }

        // Add animation to existing MetaSprite or create a new one
        let selectSpriteIndex: Int
        let selectAnimIndex: Int
        if state.assetStore.metaSprites.isEmpty {
            // No MetaSprites yet — create one
            let newSprite = MetaSprite(name: remappedAnimation.name, animations: [remappedAnimation])
            state.assetStore.metaSprites.append(newSprite)
            selectSpriteIndex = 0
            selectAnimIndex = 0
        } else {
            // Add to the first MetaSprite (user can reorganize later)
            selectSpriteIndex = 0
            selectAnimIndex = state.assetStore.metaSprites[0].animations.count
            state.assetStore.metaSprites[0].animations.append(remappedAnimation)
        }

        // Set sprite entries to first frame of the new animation
        if let firstFrame = remappedAnimation.frames.first {
            state.assetStore.spriteEntries = firstFrame.entries
        }

        // Notify with auto-select hint
        NotificationCenter.default.post(
            name: .assetStoreDidChange,
            object: nil,
            userInfo: ["selectSpriteIndex": selectSpriteIndex, "selectAnimIndex": selectAnimIndex]
        )

        let paletteReused = colorRemap != nil
        var details = "Imported \"\(result.animation.name)\": \(result.stats.totalFrames) frames, \(newTiles.count) new tiles"
        if deduped > 0 { details += " (\(deduped) reused)" }
        details += ", palette \(paletteIndex)"
        if paletteReused { details += " (reused)" }
        state.appendConsole(details, type: .success)

        dismiss()
    }

    /// Deduplicate imported tiles against tiles already in the asset store.
    /// Returns (indexMap, newTiles, dedupCount):
    ///  - indexMap: maps each imported tile index → final store index
    ///  - newTiles: only the tiles that don't already exist
    ///  - dedupCount: how many tiles were reused
    private func deduplicateTilesAgainstStore(_ importedTiles: [SNESTile]) -> ([Int], [SNESTile], Int) {
        let existingTiles = state.assetStore.tiles

        // Build lookup of existing tile pixel data → store index
        var existingLookup: [Data: Int] = [:]
        for (i, tile) in existingTiles.enumerated() {
            let key = Data(tile.pixels)
            existingLookup[key] = i
        }

        var indexMap = [Int](repeating: 0, count: importedTiles.count)
        var newTiles: [SNESTile] = []
        var dedupCount = 0
        let baseOffset = existingTiles.count

        for (i, tile) in importedTiles.enumerated() {
            let key = Data(tile.pixels)
            if let existingIdx = existingLookup[key] {
                // Tile already exists in store — reuse it
                indexMap[i] = existingIdx
                dedupCount += 1
            } else {
                // New tile — will be appended
                let newIdx = baseOffset + newTiles.count
                indexMap[i] = newIdx
                existingLookup[key] = newIdx
                newTiles.append(tile)
            }
        }

        return (indexMap, newTiles, dedupCount)
    }

    /// Find an existing palette whose colors are a superset of the imported palette's non-transparent colors.
    /// Returns (paletteIndex, colorRemap) where colorRemap maps old color indices to existing palette indices.
    /// If no match is found, returns the first empty slot index with nil remap.
    private func findMatchingPalette(for imported: SNESPalette) -> (Int, [UInt8]?) {
        // Collect non-transparent colors from the imported palette (skip index 0)
        var importedColors: [(index: Int, raw: UInt16)] = []
        for i in 1..<16 {
            if imported.colors[i].raw != 0 {
                importedColors.append((index: i, raw: imported.colors[i].raw))
            }
        }

        // Try each existing palette
        for (palIdx, existing) in state.assetStore.palettes.enumerated() {
            // Build a lookup: raw BGR555 value → index in existing palette
            var existingLookup: [UInt16: Int] = [:]
            for i in 1..<16 {
                if existing.colors[i].raw != 0 {
                    existingLookup[existing.colors[i].raw] = i
                }
            }

            // Check if all imported colors exist in this palette
            var remap = [UInt8](repeating: 0, count: 16) // index 0 stays 0 (transparent)
            var allFound = true
            for ic in importedColors {
                if let existingIdx = existingLookup[ic.raw] {
                    remap[ic.index] = UInt8(existingIdx)
                } else {
                    allFound = false
                    break
                }
            }

            if allFound && !importedColors.isEmpty {
                return (palIdx, remap)
            }
        }

        // No match — find first empty palette slot
        var emptySlot = 0
        for (i, pal) in state.assetStore.palettes.enumerated() {
            if i > 0 && pal.colors.allSatisfy({ $0.raw == 0 }) {
                emptySlot = i
                break
            }
        }
        return (emptySlot, nil)
    }
}
