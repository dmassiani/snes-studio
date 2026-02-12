import SwiftUI
import AppKit

struct ROMAnalyzerView: View {
    @Bindable var state: AppState
    @State private var selectedTab = 0

    private var analyzer: ROMAnalyzer { state.romAnalyzer }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let result = analyzer.result {
                TabView(selection: $selectedTab) {
                    ROMHeaderView(header: result.header, fileName: result.fileName,
                                  fileSize: result.fileSize, hasSMCHeader: result.hasSMCHeader)
                        .tabItem { Label("Header", systemImage: "doc.text") }
                        .tag(0)

                    ROMTileExplorerView(state: state)
                        .tabItem { Label("Tiles", systemImage: "square.grid.3x3") }
                        .tag(1)

                    ROMPaletteExplorerView(state: state)
                        .tabItem { Label("Palettes", systemImage: "paintpalette") }
                        .tag(2)
                }
            } else if let error = analyzer.errorMessage {
                errorView(error)
            } else {
                dropZone
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("ROM Analyzer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textPrimary)

            Spacer()

            if analyzer.result != nil {
                Text(analyzer.result!.fileName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(SNESTheme.textSecondary)
            }

            Button("Importer ROM...") {
                importROM()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(PyramidLevel.hardware.accent.opacity(0.4))

            Text("Importer une ROM SNES")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SNESTheme.textSecondary)

            Text("Fichiers .sfc ou .smc")
                .font(.system(size: 12))
                .foregroundStyle(SNESTheme.textDisabled)

            Button("Choisir un fichier...") {
                importROM()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(SNESTheme.danger)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(SNESTheme.textSecondary)
            Button("Reessayer") {
                importROM()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import

    private func importROM() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "sfc")!,
            .init(filenameExtension: "smc")!,
        ]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            analyzer.analyzeROM(at: url)

            // Auto-scan for palettes and tiles
            if let data = try? Data(contentsOf: url) {
                let romData: Data
                if analyzer.result?.hasSMCHeader == true {
                    romData = data.dropFirst(512)
                } else {
                    romData = data
                }

                // Scan palettes
                let paletteBlocks = analyzer.scanForPalettes(data: romData)
                state.romAnalyzer.result?.paletteBlocks = paletteBlocks

                // Extract first 256 tiles at common offsets
                let firstTiles = analyzer.extractTilesAtOffset(data: romData, offset: 0, depth: .bpp4, count: 256)
                if !firstTiles.isEmpty {
                    state.romAnalyzer.result?.tileBlocks = [
                        ROMTileBlock(offset: 0, depth: .bpp4, tiles: firstTiles)
                    ]
                }
            }

            state.appendConsole("ROM analysee: \(analyzer.result?.fileName ?? "?")", type: .info)
        }
    }
}
