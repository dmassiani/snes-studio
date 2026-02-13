import SwiftUI
import AppKit

@Observable
final class AppState {
    // MARK: - Navigation
    var activeLevel: PyramidLevel = .atelier
    var activeSubTabID: [PyramidLevel: String] = [
        .atelier: "palettes",
        .orchestre: "niveaux",
        .logique: "",
        .hardware: "cartouche",
    ]
    var sourceFiles: [String] = []

    // MARK: - Tabs (kept for screen tab tracking)
    var tabManager = TabManager()

    // MARK: - Panel visibility
    var isRightPanelVisible: Bool = false
    var isConsoleVisible: Bool = true

    // MARK: - Panel sizes
    var rightPanelWidth: CGFloat = SNESTheme.rightPanelDefaultWidth
    var bottomHeight: CGFloat = SNESTheme.hardwareBarHeight + SNESTheme.consoleDefaultHeight

    // MARK: - Hardware budget
    var budgetMeters: [BudgetMeter] = []

    // MARK: - Cursor
    var cursorLine: Int = 1
    var cursorColumn: Int = 1

    // MARK: - Console
    var consoleMessages: [ConsoleMessage] = [
        ConsoleMessage(timestamp: Date(), type: .info, text: "SNES Studio v0.1.0 — Ready"),
    ]

    // MARK: - Project
    var projectManager = ProjectManager()
    var buildSystem = BuildSystem()
    var assetStore = AssetStore()
    var romAnalyzer = ROMAnalyzer()
    var chatManager = ChatManager()
    var spriteDrawingSession = SpriteDrawingSession()
    var showNewProjectSheet = false

    // MARK: - Right panel mode
    enum RightPanelMode { case aide, chat }
    var rightPanelMode: RightPanelMode = .aide

    // MARK: - Termination observer
    private var terminationObserver: NSObjectProtocol?

    init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushAutoSave()
        }
    }

    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Navigation Actions

    func selectSubTab(_ id: String) {
        activeSubTabID[activeLevel] = id
    }

    func openScreenTab(screenID: UUID, screenName: String) {
        activeLevel = .orchestre
        activeSubTabID[.orchestre] = "screen_\(screenID.uuidString)"
    }

    func toggleAide() {
        if isRightPanelVisible && rightPanelMode == .aide {
            withAnimation(.easeInOut(duration: 0.2)) { isRightPanelVisible = false }
        } else {
            rightPanelMode = .aide
            withAnimation(.easeInOut(duration: 0.2)) { isRightPanelVisible = true }
        }
    }

    func toggleChat() {
        if isRightPanelVisible && rightPanelMode == .chat {
            withAnimation(.easeInOut(duration: 0.2)) { isRightPanelVisible = false }
        } else {
            rightPanelMode = .chat
            withAnimation(.easeInOut(duration: 0.2)) { isRightPanelVisible = true }
        }
    }

    func toggleRightPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRightPanelVisible.toggle()
        }
    }

    func toggleConsole() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isConsoleVisible.toggle()
        }
    }

    func setLevel(_ level: PyramidLevel) {
        withAnimation(.easeInOut(duration: 0.3)) {
            activeLevel = level
        }
    }

    func appendConsole(_ text: String, type: ConsoleMessage.MessageType = .info, fileRef: FileReference? = nil) {
        consoleMessages.append(
            ConsoleMessage(timestamp: Date(), type: type, text: text, fileRef: fileRef)
        )
    }

    func clearConsole() {
        consoleMessages.removeAll()
    }

    // MARK: - File URL helper

    /// Returns the file URL for a source file ID (filename like "main.asm")
    func fileURL(for fileID: String) -> URL? {
        guard sourceFiles.contains(fileID),
              let srcDir = projectManager.currentProject?.sourceDirectoryURL else { return nil }
        return srcDir.appendingPathComponent(fileID)
    }

    /// Label for the current active sub-tab
    var activeSubTabLabel: String {
        guard let id = activeSubTabID[activeLevel], !id.isEmpty else { return "" }
        // For source files, the ID is the filename
        if activeLevel == .logique { return id }
        // For screen tabs
        if id.hasPrefix("screen_") {
            if let uuid = UUID(uuidString: String(id.dropFirst("screen_".count))),
               let screen = assetStore.worldScreens.first(where: { $0.id == uuid }) {
                return screen.name
            }
            return String(localized: "Screen")
        }
        // Static sub-tab names
        let labels: [String: String] = [
            "palettes": String(localized: "Palettes"), "tiles": String(localized: "Tiles"), "tilemaps": String(localized: "Tilemaps"),
            "sprites": String(localized: "Sprites"), "audio": String(localized: "Audio"), "controleur": String(localized: "Controller"),
            "niveaux": String(localized: "Screens"),
            "cartouche": String(localized: "Cartridge"), "registres": String(localized: "Registers"), "memoire": String(localized: "Memory"),
            "vram": String(localized: "VRAM"), "couches_bg": String(localized: "BG Layers"), "rom_analyzer": String(localized: "ROM Analyzer"),
        ]
        return labels[id] ?? id
    }

    // MARK: - Auto-save

    private var autoSaveWork: DispatchWorkItem?

    /// Immediate save — for discrete changes (palette, controller, world, code)
    func saveAssetsNow() {
        autoSaveWork?.cancel()
        autoSaveWork = nil
        performAutoSave()
    }

    /// Debounced save — for continuous drawing (tiles, tilemap, sprites, levels)
    func scheduleAutoSave() {
        autoSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performAutoSave()
        }
        autoSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// Flush on app termination
    func flushAutoSave() {
        autoSaveWork?.cancel()
        autoSaveWork = nil
        performAutoSave()
    }

    private func performAutoSave() {
        guard let project = projectManager.currentProject else {
            return
        }
        guard let assetsDir = project.assetsDirectoryURL else {
            appendConsole(String(localized: "Auto-save: no assets folder"), type: .warning)
            return
        }
        do {
            try assetStore.save(to: assetsDir)
            try projectManager.saveProject()
        } catch {
            appendConsole(String(localized: "Auto-save error: \(error.localizedDescription)"), type: .error)
        }
    }

    // MARK: - Project actions

    func loadProject() {
        guard let project = projectManager.currentProject else { return }
        sourceFiles = project.sourceFiles
        tabManager.closeAllTabs()

        // Set default logique sub-tab to first source file
        if let first = sourceFiles.first {
            activeSubTabID[.logique] = first
        }

        if let assetsDir = project.assetsDirectoryURL {
            let result = assetStore.load(from: assetsDir)
            if !result.directoryExists {
                appendConsole(String(localized: "assets/ folder not found — \(assetsDir.path)"), type: .warning)
            } else if !result.loaded.isEmpty {
                appendConsole(String(localized: "Assets loaded: \(result.loaded.joined(separator: ", "))"), type: .info)
            }
            if !result.missing.isEmpty {
                appendConsole(String(localized: "Missing files (defaults): \(result.missing.joined(separator: ", "))"), type: .info)
            }
            for (file, err) in result.errors {
                appendConsole(String(localized: "Error \(file): \(err)"), type: .error)
            }
            // New project: save defaults so files exist for next load
            if result.loaded.isEmpty && result.errors.isEmpty {
                performAutoSave()
            }
        } else {
            appendConsole(String(localized: "No assets path configured"), type: .warning)
        }
        recalculateBudget()
        appendConsole(String(localized: "Project \"\(project.name)\" loaded — \(project.projectPath?.path ?? "?")"), type: .success)
    }

    func recalculateBudget() {
        guard let config = projectManager.currentProject?.cartridge else {
            budgetMeters = []
            return
        }
        budgetMeters = BudgetMeter.metersFromCartridge(config, assets: assetStore)
    }

    func saveActiveFile() {
        do {
            try projectManager.saveProject()
            if let assetsDir = projectManager.currentProject?.assetsDirectoryURL {
                try assetStore.save(to: assetsDir)
            }
            recalculateBudget()
            appendConsole(String(localized: "Project saved"), type: .success)
        } catch {
            appendConsole(String(localized: "Save error: \(error.localizedDescription)"), type: .error)
        }
    }

    func openFileAtLine(file: String, line: Int) {
        if sourceFiles.contains(file) {
            activeLevel = .logique
            activeSubTabID[.logique] = file
        } else {
            appendConsole(String(localized: "File \(file) not found in project"), type: .warning)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: .setCursorPosition,
                object: nil,
                userInfo: ["line": line, "column": 1]
            )
        }
    }

    func buildProject() async {
        guard let project = projectManager.currentProject else {
            appendConsole(String(localized: "No project open"), type: .error)
            return
        }
        await buildSystem.build(project: project, console: self)
    }
}
