import SwiftUI

struct CenterEditorView: View {
    @Bindable var state: AppState

    private var activeID: String {
        state.activeSubTabID[state.activeLevel] ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if activeID.isEmpty {
                emptyEditor
            } else {
                editorContent(for: activeID)
                    .id(activeID)
            }
        }
        .background(SNESTheme.bgEditor)
    }

    private var emptyEditor: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 36))
                .foregroundStyle(SNESTheme.textDisabled)

            Text("Selectionne un onglet")
                .font(.system(size: 13))
                .foregroundStyle(SNESTheme.textDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SNESTheme.bgEditor)
    }

    @ViewBuilder
    private func editorContent(for id: String) -> some View {
        if id == "cartouche" {
            CartridgeConfigView(state: state)
        } else if id == "palettes" {
            PaletteEditorView(state: state)
        } else if id == "tiles" {
            TileEditorContainerView(state: state)
        } else if id == "tilemaps" {
            TilemapEditorContainerView(state: state)
        } else if id == "sprites" {
            SpriteEditorContainerView(state: state)
        } else if id == "controleur" {
            ControllerEditorView(state: state)
        } else if id == "registres" {
            RegistersView()
        } else if id == "memoire" {
            MemoryMapView(state: state)
        } else if id == "vram" {
            VRAMViewerView(state: state)
        } else if id == "couches_bg" {
            LayerViewerView(state: state)
        } else if id == "rom_analyzer" {
            ROMAnalyzerView(state: state)
        } else if id == "niveaux" {
            ScreenListView(state: state)
        } else if id.hasPrefix("screen_") {
            if let screenID = UUID(uuidString: String(id.dropFirst("screen_".count))) {
                LevelEditorContainerView(state: state, screenID: screenID)
            } else {
                editorPlaceholder(id: id)
            }
        } else if id.hasSuffix(".asm") || id.hasSuffix(".inc") {
            VStack(spacing: 0) {
                CodeEditorView(state: state, fileID: id)

                // Status bar
                HStack(spacing: 0) {
                    Text(id)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Spacer()
                    Text("Ln \(state.cursorLine), Col \(state.cursorColumn)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                }
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(SNESTheme.bgPanel)
                .overlay(alignment: .top) {
                    SNESTheme.border.frame(height: 1)
                }
            }
        } else {
            editorPlaceholder(id: id)
        }
    }

    private func editorPlaceholder(id: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 40))
                .foregroundStyle(state.activeLevel.accent.opacity(0.4))

            Text(id)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SNESTheme.textSecondary)

            Text("Editor placeholder — \(state.activeLevel.subtitle)")
                .font(.system(size: 12))
                .foregroundStyle(SNESTheme.textDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SNESTheme.bgEditor)
    }
}
