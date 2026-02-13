# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SNES Studio is a native macOS IDE for SNES game development. It provides visual editors for sprites, tiles, tilemaps, palettes, and world/screen design, plus an assembly code editor and build system integrating with the ca65/ld65 6502 assembler toolchain.

## Build & Development

### macOS App (Swift/SwiftUI)

The Xcode project is generated from `project.yml` using XcodeGen:

```bash
xcodegen generate          # Regenerate SNESStudio.xcodeproj from project.yml
xcodebuild -project SNESStudio.xcodeproj -scheme SNESStudio -configuration Debug build
```

- **Deployment target:** macOS 14.0
- **Swift version:** 5.9 with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- **Bundle ID:** `com.snesstudio.app`

### CodeMirror Editor Bundle

The code editor uses a custom CodeMirror 6 build bundled as JavaScript:

```bash
cd codemirror-build
npm install
npm run build              # Outputs to SNESStudio/Resources/CodeMirror/editor.js
```

Rebuild this after modifying any CodeMirror configuration in `codemirror-build/`.

## Architecture

### State Management

Central `AppState` class uses Swift 5.9 `@Observable` macro. It's a singleton holding all navigation, panel, and project state. Views bind via `@Bindable`. Cross-component events use `NotificationCenter`.

Key services owned by AppState:
- `ProjectManager` — project lifecycle (create/open/save)
- `BuildSystem` — ca65/ld65 assembly pipeline
- `AssetStore` — JSON-based persistence for all game assets
- `ChatManager` → `AnthropicService` — Claude AI assistant integration
- `ROMAnalyzer` — ROM reverse-engineering tools

### Pyramid Navigation (4 Levels)

The IDE uses a 4-level hierarchical navigation model (`PyramidLevel` enum). Each level has sub-tabs tracked in `AppState.activeSubTabID`. Keyboard shortcuts: Cmd+1 through Cmd+4.

| Level | Name | Purpose | Sub-tabs |
|-------|------|---------|----------|
| 1 | ATELIER | Resources | palettes, tiles, sprites, tilemaps |
| 2 | ORCHESTRE | Orchestration | world screens, levels, transitions, zones |
| 3 | LOGIQUE | Code | assembly source files |
| 4 | HARDWARE | Constraints | cartridge config, VRAM, registers, memory map |

### Views Organization

Views in `SNESStudio/Views/` are organized by domain, mirroring the pyramid levels:
- `Palette/`, `Tile/`, `Sprite/`, `SpriteDrawing/`, `Tilemap/` — Atelier editors
- `World/`, `Level/` — Orchestre editors
- `Editor/` — CodeMirror-based assembly code editor (CodeEditorView ↔ WKWebView)
- `Hardware/` — VRAM viewer, registers, memory map
- `Cartridge/`, `Controller/`, `ROMAnalyzer/` — config and analysis tools

### Asset Persistence

Game assets are stored as JSON files in the project's `assets/` directory (palettes.json, tiles.json, sprites.json, tilemaps.json, world_screens.json, etc.). `AssetStore` handles loading/saving with debounced auto-save (2s for continuous drawing, immediate for discrete changes).

### Project File Structure

```
ProjectName/
├── ProjectName.snesproj      # JSON project metadata
├── src/                       # Assembly source files (.asm, .inc)
├── assets/                    # Game data as JSON
├── build/                     # Compiler output (.o files, .sfc ROM)
└── linker.cfg                 # Generated from CartridgeConfig
```

### UI Layout

Resizable panel-based layout managed in `MainView`:
- Left: pyramid level navigation
- Center: active editor (context-dependent on pyramid level + sub-tab)
- Right panel: AI assistant / contextual help (toggleable, 200–400px)
- Bottom: hardware budget bar + console output
- Minimum window: 1024×700

### Theme

`SNESTheme` defines the design system (colors, typography, layout constants). Each pyramid level has a distinct accent color defined in `PyramidLevel.accent`.

## Conventions

- French naming for domain concepts: "atelier" (workshop), "orchestre" (orchestrator), "logique" (logic), "niveaux" (levels), "cartouche" (cartridge), "aide" (help)
- All UI state flows through `AppState` — avoid creating parallel state holders
- Console output goes through `AppState.consoleMessages`
