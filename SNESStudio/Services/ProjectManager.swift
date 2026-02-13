import SwiftUI
import UniformTypeIdentifiers

@Observable
final class ProjectManager {
    var currentProject: SNESProject?
    var recentProjects: [URL] = []
    var error: String?

    private let recentsKey = "SNESStudio.recentProjects"
    private let maxRecents = 10

    init() {
        loadRecents()
    }

    // MARK: - Create Project

    func createProject(name: String, at directory: URL, cartridge: CartridgeConfig, template: ProjectTemplate) throws {
        let projectDir = directory.appendingPathComponent(name)
        let fm = FileManager.default

        // Create directory structure
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: projectDir.appendingPathComponent("src"), withIntermediateDirectories: true)
        try fm.createDirectory(at: projectDir.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try fm.createDirectory(at: projectDir.appendingPathComponent("build"), withIntermediateDirectories: true)

        // Generate linker config
        let linkerConfig = LinkerConfigGenerator.generate(for: cartridge)
        try linkerConfig.write(
            to: projectDir.appendingPathComponent(cartridge.linkerConfigName),
            atomically: true,
            encoding: .utf8
        )

        // Generate template source files
        let sourceFiles = template.sourceFiles(config: cartridge)
        var fileNames: [String] = []
        for (filename, content) in sourceFiles.sorted(by: { $0.key < $1.key }) {
            try content.write(
                to: projectDir.appendingPathComponent("src").appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
            fileNames.append(filename)
        }

        // Create project file
        var project = SNESProject(
            name: name,
            cartridge: cartridge,
            sourceFiles: fileNames
        )
        project.projectPath = projectDir

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: projectDir.appendingPathComponent("\(name).snesproj"))

        currentProject = project
        addRecent(projectDir.appendingPathComponent("\(name).snesproj"))
    }

    // MARK: - Open Project (panel)

    func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open a SNES Studio project"
        panel.allowedContentTypes = [UTType(filenameExtension: "snesproj") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openProject(at: url)
    }

    // MARK: - Open Project (direct)

    func openProject(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var project = try decoder.decode(SNESProject.self, from: data)
            project.projectPath = url.deletingLastPathComponent()

            // Discover source files on disk
            let srcDir = project.sourceDirectoryURL
            if let srcDir, FileManager.default.fileExists(atPath: srcDir.path) {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: srcDir,
                    includingPropertiesForKeys: nil
                )
                project.sourceFiles = contents
                    .filter { $0.pathExtension == "asm" || $0.pathExtension == "inc" }
                    .map { $0.lastPathComponent }
                    .sorted()
            }

            currentProject = project
            addRecent(url)
            error = nil
        } catch {
            self.error = "Open error: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Project

    func saveProject() throws {
        guard var project = currentProject, let fileURL = project.projectFileURL else { return }
        project.modifiedDate = Date()
        currentProject = project

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: fileURL)
    }

    // MARK: - Update Cartridge & Regenerate

    func updateCartridge(_ config: CartridgeConfig) throws {
        guard var project = currentProject, let projectPath = project.projectPath else { return }
        project.cartridge = config
        project.modifiedDate = Date()
        currentProject = project

        // Regenerate linker config
        let linkerConfig = LinkerConfigGenerator.generate(for: config)
        try linkerConfig.write(
            to: projectPath.appendingPathComponent(config.linkerConfigName),
            atomically: true,
            encoding: .utf8
        )

        try saveProject()
    }

    // MARK: - Recents

    private func loadRecents() {
        if let bookmarks = UserDefaults.standard.array(forKey: recentsKey) as? [Data] {
            recentProjects = bookmarks.compactMap { data in
                var stale = false
                return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            }
        }
    }

    private func addRecent(_ url: URL) {
        recentProjects.removeAll { $0.lastPathComponent == url.lastPathComponent }
        recentProjects.insert(url, at: 0)
        if recentProjects.count > maxRecents {
            recentProjects = Array(recentProjects.prefix(maxRecents))
        }
        // Save as bookmarks
        let bookmarks = recentProjects.compactMap { try? $0.bookmarkData(options: .withSecurityScope) }
        UserDefaults.standard.set(bookmarks, forKey: recentsKey)
    }
}
