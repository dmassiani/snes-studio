import SwiftUI

// MARK: - Sub Tab Bar (items for active level)

struct SubTabBar: View {
    @Bindable var state: AppState

    private var items: [(id: String, label: String, icon: String)] {
        switch state.activeLevel {
        case .atelier:
            return [
                ("palettes",   "Palettes",   "paintpalette"),
                ("tiles",      "Tiles",      "square.grid.3x3"),
                ("tilemaps",   "Tilemaps",   "map"),
                ("sprites",    "Sprites",    "figure.run"),
                ("audio",      "Audio",      "music.note"),
                ("controleur", "Controller", "gamecontroller"),
            ]
        case .orchestre:
            return [
                ("niveaux", "Screens", "square.grid.3x3.fill"),
            ]
        case .logique:
            return state.sourceFiles.map { file in
                (file, file, "doc.text")
            }
        case .hardware:
            return [
                ("cartouche",    "Cartridge",    "cpu"),
                ("registres",    "Registers",    "list.clipboard"),
                ("memoire",      "Memory",       "memorychip"),
                ("vram",         "VRAM",         "photo.artframe"),
                ("couches_bg",   "BG Layers",    "square.3.layers.3d"),
                ("rom_analyzer", "ROM Analyzer", "magnifyingglass"),
            ]
        }
    }

    var body: some View {
        HStack {
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(items, id: \.id) { item in
                        subTab(id: item.id, label: item.label, icon: item.icon)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer()
        }
        .frame(height: 34)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    private func subTab(id: String, label: String, icon: String) -> some View {
        let activeID = state.activeSubTabID[state.activeLevel] ?? ""
        let isActive = activeID == id

        return Button {
            state.selectSubTab(id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? SNESTheme.textPrimary : SNESTheme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .overlay(alignment: .bottom) {
                if isActive {
                    state.activeLevel.accent.frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
