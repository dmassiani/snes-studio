import Foundation

/// Executes AI tool calls by mutating AssetStore and posting notifications.
@MainActor
final class AIToolExecutor {
    let assetStore: AssetStore
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.assetStore = appState.assetStore
    }

    struct ToolResult {
        let toolID: String
        let content: String
        let isError: Bool
    }

    // MARK: - Execute a tool call

    func execute(name: String, id: String, input: [String: Any]) -> ToolResult {
        switch name {
        case "get_project_info":
            return getProjectInfo(id: id)
        case "get_palette":
            return getPalette(id: id, input: input)
        case "set_palette_color":
            return setPaletteColor(id: id, input: input)
        case "set_tile_pixel":
            return setTilePixel(id: id, input: input)
        case "set_tile_pixels_batch":
            return setTilePixelsBatch(id: id, input: input)
        case "set_tilemap_entry":
            return setTilemapEntry(id: id, input: input)
        case "add_sprite":
            return addSprite(id: id, input: input)
        case "move_sprite":
            return moveSprite(id: id, input: input)
        case "set_button_mapping":
            return setButtonMapping(id: id, input: input)
        case "insert_code":
            return insertCode(id: id, input: input)
        case "replace_code":
            return replaceCode(id: id, input: input)
        case "add_zone":
            return addZone(id: id, input: input)
        default:
            return ToolResult(toolID: id, content: "Unknown tool: \(name)", isError: true)
        }
    }

    // MARK: - General

    private func getProjectInfo(id: String) -> ToolResult {
        guard let project = appState.projectManager.currentProject else {
            return ToolResult(toolID: id, content: "No project open", isError: true)
        }
        var info: [String: Any] = [
            "name": project.name,
            "sourceFiles": project.sourceFiles,
            "paletteCount": assetStore.palettes.count,
            "tileCount": assetStore.tiles.count,
            "tilemapCount": assetStore.tilemaps.count,
            "spriteCount": assetStore.spriteEntries.count,
            "zoneCount": assetStore.worldZones.count,
        ]
        let config = project.cartridge
        info["cartridge"] = [
            "mapping": config.mapping.rawValue,
            "romSizeKB": config.romSizeKB,
            "sramSizeKB": config.sramSizeKB,
            "speed": config.speed.rawValue,
            "chip": config.chip.rawValue,
        ] as [String: Any]
        let jsonData = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
        let jsonStr = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return ToolResult(toolID: id, content: jsonStr, isError: false)
    }

    // MARK: - Palette

    private func getPalette(id: String, input: [String: Any]) -> ToolResult {
        guard let paletteIndex = input["palette_index"] as? Int,
              paletteIndex >= 0, paletteIndex < assetStore.palettes.count else {
            return ToolResult(toolID: id, content: "Invalid palette_index", isError: true)
        }
        let palette = assetStore.palettes[paletteIndex]
        let colors = palette.colors.enumerated().map { (i, c) in
            ["index": i, "r": c.red, "g": c.green, "b": c.blue, "raw": String(format: "$%04X", c.raw)] as [String: Any]
        }
        let jsonData = try? JSONSerialization.data(withJSONObject: ["name": palette.name, "colors": colors], options: .prettyPrinted)
        let jsonStr = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return ToolResult(toolID: id, content: jsonStr, isError: false)
    }

    private func setPaletteColor(id: String, input: [String: Any]) -> ToolResult {
        guard let pi = input["palette_index"] as? Int,
              let ci = input["color_index"] as? Int,
              let r = input["r"] as? Int,
              let g = input["g"] as? Int,
              let b = input["b"] as? Int else {
            return ToolResult(toolID: id, content: "Missing parameters: palette_index, color_index, r, g, b", isError: true)
        }
        guard pi >= 0, pi < assetStore.palettes.count else {
            return ToolResult(toolID: id, content: "palette_index out of bounds (0-\(assetStore.palettes.count - 1))", isError: true)
        }
        guard ci >= 0, ci < 16 else {
            return ToolResult(toolID: id, content: "color_index out of bounds (0-15)", isError: true)
        }
        let color = SNESColor(r: r, g: g, b: b)
        assetStore.palettes[pi][ci] = color
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Color \(ci) of palette \(pi) updated: R=\(color.red) G=\(color.green) B=\(color.blue)", isError: false)
    }

    // MARK: - Tile

    private func setTilePixel(id: String, input: [String: Any]) -> ToolResult {
        guard let ti = input["tile_index"] as? Int,
              let x = input["x"] as? Int,
              let y = input["y"] as? Int,
              let ci = input["color_index"] as? Int else {
            return ToolResult(toolID: id, content: "Missing parameters", isError: true)
        }
        guard ti >= 0, ti < assetStore.tiles.count else {
            return ToolResult(toolID: id, content: "tile_index out of bounds", isError: true)
        }
        guard x >= 0, x < 8, y >= 0, y < 8 else {
            return ToolResult(toolID: id, content: "x/y out of bounds (0-7)", isError: true)
        }
        assetStore.tiles[ti].setPixel(x: x, y: y, value: UInt8(ci))
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Pixel (\(x),\(y)) of tile \(ti) = color \(ci)", isError: false)
    }

    private func setTilePixelsBatch(id: String, input: [String: Any]) -> ToolResult {
        guard let ti = input["tile_index"] as? Int,
              let pixels = input["pixels"] as? [[String: Any]] else {
            return ToolResult(toolID: id, content: "Missing parameters: tile_index, pixels", isError: true)
        }
        guard ti >= 0, ti < assetStore.tiles.count else {
            return ToolResult(toolID: id, content: "tile_index out of bounds", isError: true)
        }
        var count = 0
        for px in pixels {
            guard let x = px["x"] as? Int,
                  let y = px["y"] as? Int,
                  let ci = px["color_index"] as? Int else { continue }
            assetStore.tiles[ti].setPixel(x: x, y: y, value: UInt8(ci))
            count += 1
        }
        notifyAssetChange()
        return ToolResult(toolID: id, content: "\(count) pixels modified in tile \(ti)", isError: false)
    }

    // MARK: - Tilemap

    private func setTilemapEntry(id: String, input: [String: Any]) -> ToolResult {
        guard let x = input["x"] as? Int,
              let y = input["y"] as? Int,
              let tileIndex = input["tile_index"] as? Int else {
            return ToolResult(toolID: id, content: "Missing parameters: x, y, tile_index", isError: true)
        }
        guard !assetStore.tilemaps.isEmpty else {
            return ToolResult(toolID: id, content: "No tilemap", isError: true)
        }
        let paletteIndex = input["palette_index"] as? Int ?? 0
        let flipH = input["flip_h"] as? Bool ?? false
        let flipV = input["flip_v"] as? Bool ?? false
        let priority = input["priority"] as? Bool ?? false
        let entry = TilemapEntry(tileIndex: tileIndex, paletteIndex: paletteIndex, flipH: flipH, flipV: flipV, priority: priority)
        assetStore.tilemaps[0].setEntry(x: x, y: y, entry: entry)
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Tilemap entry (\(x),\(y)) = tile \(tileIndex)", isError: false)
    }

    // MARK: - Sprite

    private func addSprite(id: String, input: [String: Any]) -> ToolResult {
        guard let x = input["x"] as? Int,
              let y = input["y"] as? Int,
              let tileIndex = input["tile_index"] as? Int else {
            return ToolResult(toolID: id, content: "Missing parameters: x, y, tile_index", isError: true)
        }
        let paletteIndex = input["palette_index"] as? Int ?? 0
        let sizeStr = input["size"] as? String ?? "small8x8"
        let size = SpriteSize(rawValue: sizeStr) ?? .small8x8
        let entry = OAMEntry(x: x, y: y, tileIndex: tileIndex, paletteIndex: paletteIndex, size: size)
        assetStore.spriteEntries.append(entry)
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Sprite added at (\(x),\(y)), tile \(tileIndex), size \(size.label)", isError: false)
    }

    private func moveSprite(id: String, input: [String: Any]) -> ToolResult {
        guard let si = input["sprite_index"] as? Int,
              let x = input["x"] as? Int,
              let y = input["y"] as? Int else {
            return ToolResult(toolID: id, content: "Missing parameters: sprite_index, x, y", isError: true)
        }
        guard si >= 0, si < assetStore.spriteEntries.count else {
            return ToolResult(toolID: id, content: "sprite_index out of bounds", isError: true)
        }
        assetStore.spriteEntries[si].x = x
        assetStore.spriteEntries[si].y = y
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Sprite \(si) moved to (\(x),\(y))", isError: false)
    }

    // MARK: - Controller

    private func setButtonMapping(id: String, input: [String: Any]) -> ToolResult {
        guard let buttonStr = input["button"] as? String,
              let label = input["label"] as? String,
              let routine = input["asm_routine"] as? String else {
            return ToolResult(toolID: id, content: "Missing parameters: button, label, asm_routine", isError: true)
        }
        guard let button = SNESButton(rawValue: buttonStr) else {
            return ToolResult(toolID: id, content: "Unknown button: \(buttonStr)", isError: true)
        }
        assetStore.controllerMapping[button] = ButtonAction(label: label, asmRoutine: routine)
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Button \(button.label) → \(label) (\(routine))", isError: false)
    }

    // MARK: - Code

    private func insertCode(id: String, input: [String: Any]) -> ToolResult {
        guard let line = input["line"] as? Int,
              let code = input["code"] as? String else {
            return ToolResult(toolID: id, content: "Missing parameters: line, code", isError: true)
        }
        guard let tab = appState.tabManager.activeTab,
              let project = appState.projectManager.currentProject,
              let srcDir = project.sourceDirectoryURL else {
            return ToolResult(toolID: id, content: "No active file", isError: true)
        }
        let fileURL = srcDir.appendingPathComponent(tab.title)
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ToolResult(toolID: id, content: "Unable to read file", isError: true)
        }
        var lines = content.components(separatedBy: "\n")
        let insertAt = max(0, min(line - 1, lines.count))
        let codeLines = code.components(separatedBy: "\n")
        lines.insert(contentsOf: codeLines, at: insertAt)
        content = lines.joined(separator: "\n")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: .codeFileDidChange, object: nil, userInfo: ["file": tab.title])
            return ToolResult(toolID: id, content: "\(codeLines.count) lines inserted at line \(line)", isError: false)
        } catch {
            return ToolResult(toolID: id, content: "Write error: \(error.localizedDescription)", isError: true)
        }
    }

    private func replaceCode(id: String, input: [String: Any]) -> ToolResult {
        guard let startLine = input["start_line"] as? Int,
              let endLine = input["end_line"] as? Int,
              let code = input["code"] as? String else {
            return ToolResult(toolID: id, content: "Missing parameters: start_line, end_line, code", isError: true)
        }
        guard let tab = appState.tabManager.activeTab,
              let project = appState.projectManager.currentProject,
              let srcDir = project.sourceDirectoryURL else {
            return ToolResult(toolID: id, content: "No active file", isError: true)
        }
        let fileURL = srcDir.appendingPathComponent(tab.title)
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ToolResult(toolID: id, content: "Unable to read file", isError: true)
        }
        var lines = content.components(separatedBy: "\n")
        let start = max(0, startLine - 1)
        let end = min(endLine, lines.count)
        guard start < end else {
            return ToolResult(toolID: id, content: "Invalid line range", isError: true)
        }
        let codeLines = code.components(separatedBy: "\n")
        lines.replaceSubrange(start..<end, with: codeLines)
        content = lines.joined(separator: "\n")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: .codeFileDidChange, object: nil, userInfo: ["file": tab.title])
            return ToolResult(toolID: id, content: "Lines \(startLine)-\(endLine) replaced with \(codeLines.count) lines", isError: false)
        } catch {
            return ToolResult(toolID: id, content: "Write error: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - World

    private func addZone(id: String, input: [String: Any]) -> ToolResult {
        guard let name = input["name"] as? String,
              let typeStr = input["type"] as? String,
              let bgMode = input["bg_mode"] as? Int,
              let gridW = input["grid_width"] as? Int,
              let gridH = input["grid_height"] as? Int else {
            return ToolResult(toolID: id, content: "Missing parameters", isError: true)
        }
        let zoneType = ZoneType(rawValue: typeStr) ?? .overworld
        let zone = WorldZone(name: name, type: zoneType, bgMode: bgMode,
                             gridWidth: gridW, gridHeight: gridH,
                             sharedTileIndices: [], colorHex: "9B6DFF")
        assetStore.worldZones.append(zone)
        notifyAssetChange()
        return ToolResult(toolID: id, content: "Zone '\(name)' added (\(zoneType.rawValue), mode \(bgMode), \(gridW)x\(gridH))", isError: false)
    }

    // MARK: - Notifications

    private func notifyAssetChange() {
        NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
    }
}
