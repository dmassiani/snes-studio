import SwiftUI

struct PaletteEditorView: View {
    @Bindable var state: AppState

    @State private var palettes: [SNESPalette] = SNESPalette.defaultPalettes()
    @State private var selectedPaletteIndex: Int = 0
    @State private var selectedColorIndex: Int = 0
    @State private var undoMgr = EditorUndoManager<[SNESPalette]>()

    var body: some View {
        HStack(spacing: 0) {
            // Left: Toolbar + palette grid
            VStack(spacing: 0) {
                toolbar
                ScrollView {
                    VStack(spacing: 16) {
                        paletteBank(0..<8)
                        paletteBank(8..<16)
                    }
                    .padding(10)
                }
                .background(SNESTheme.bgEditor)
            }

            // Divider
            SNESTheme.border.frame(width: 1)

            // Right: Color picker (fixed width)
            BGR555ColorPicker(
                color: Binding(
                    get: { palettes[selectedPaletteIndex][selectedColorIndex] },
                    set: { newColor in
                        undoMgr.recordState(palettes)
                        palettes[selectedPaletteIndex][selectedColorIndex] = newColor
                    }
                )
            )
            .frame(width: 240)
        }
        .background(SNESTheme.bgEditor)
        .onReceive(NotificationCenter.default.publisher(for: .editorUndo)) { _ in
            if let prev = undoMgr.undo(current: palettes) { palettes = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorRedo)) { _ in
            if let next = undoMgr.redo(current: palettes) { palettes = next }
        }
        .onAppear {
            palettes = state.assetStore.palettes
        }
        .onDisappear {
            state.assetStore.palettes = palettes
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onChange(of: palettes) {
            state.assetStore.palettes = palettes
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .assetStoreDidChange)) { _ in
            palettes = state.assetStore.palettes
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("PALETTES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textSecondary)
            Spacer()

            Menu {
                ForEach(PalettePresets.allPresets) { preset in
                    Menu(preset.game) {
                        ForEach(preset.palettes) { pal in
                            Button(pal.name) {
                                undoMgr.recordState(palettes)
                                palettes[selectedPaletteIndex] = SNESPalette(
                                    name: pal.name,
                                    colors: pal.colors
                                )
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .help("Load a game preset")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }

    // MARK: - Palette Bank (8 palettes per row)

    private func paletteBank(_ range: Range<Int>) -> some View {
        HStack(alignment: .top, spacing: 4) {
            // Index column (8 rows: 0,2,4,...14)
            VStack(spacing: 1) {
                Text("")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .frame(height: 18)
                ForEach(0..<8, id: \.self) { row in
                    Text("\(row * 2)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .frame(height: 20)
                }
            }
            .frame(width: 20)

            // 8 palette columns (each 2 swatches wide)
            ForEach(range, id: \.self) { paletteIdx in
                paletteColumn(index: paletteIdx)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Palette Column (2 cols x 8 rows)

    private func paletteColumn(index: Int) -> some View {
        let isSelected = selectedPaletteIndex == index
        return VStack(spacing: 1) {
            // Header
            Text("P\(index)")
                .font(.system(size: 9, weight: isSelected ? .bold : .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? SNESTheme.info : SNESTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 18)

            // 8 rows of 2 colors each
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 1) {
                    colorSwatch(paletteIdx: index, colorIdx: row * 2)
                    colorSwatch(paletteIdx: index, colorIdx: row * 2 + 1)
                }
            }
        }
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? SNESTheme.info.opacity(0.08) : Color.clear)
        )
    }

    // MARK: - Color Swatch

    private func colorSwatch(paletteIdx: Int, colorIdx: Int) -> some View {
        let isSelected = selectedPaletteIndex == paletteIdx && selectedColorIndex == colorIdx
        return Button {
            selectedPaletteIndex = paletteIdx
            selectedColorIndex = colorIdx
        } label: {
            ZStack {
                if colorIdx == 0 {
                    // Checkerboard for transparent color 0
                    Canvas { ctx, sz in
                        let half = sz.width / 2
                        let halfH = sz.height / 2
                        for r in 0..<2 {
                            for c in 0..<2 {
                                let col: Color = (r + c) % 2 == 0 ? Color(white: 0.22) : Color(white: 0.13)
                                ctx.fill(
                                    Path(CGRect(x: CGFloat(c) * half, y: CGFloat(r) * halfH, width: half, height: halfH)),
                                    with: .color(col)
                                )
                            }
                        }
                    }
                } else {
                    palettes[paletteIdx][colorIdx].color
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 20)
            .border(isSelected ? Color.white : SNESTheme.border.opacity(0.3), width: isSelected ? 2 : 0.5)
        }
        .buttonStyle(.plain)
    }
}
