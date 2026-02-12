import Foundation

struct BuildError: Identifiable {
    let id = UUID()
    let file: String
    let line: Int
    let column: Int
    let message: String
    let severity: Severity

    enum Severity { case error, warning }
}

struct BuildResult {
    let success: Bool
    let romURL: URL?
    let romSize: Int
    let errors: [BuildError]
    let duration: TimeInterval
}

@Observable
final class BuildSystem {
    var isBuilding = false
    var lastResult: BuildResult?

    private var ca65Path: String?
    private var ld65Path: String?

    init() {
        detectTools()
    }

    // MARK: - Detect ca65/ld65

    private func detectTools() {
        ca65Path = findTool("ca65")
        ld65Path = findTool("ld65")
    }

    private func findTool(_ name: String) -> String? {
        // Check common paths
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // Try which
        let result = shell("which \(name)")
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }
        return nil
    }

    var toolsAvailable: Bool {
        ca65Path != nil && ld65Path != nil
    }

    // MARK: - Build

    @MainActor
    func build(project: SNESProject, console: AppState) async {
        guard !isBuilding else { return }
        guard let ca65 = ca65Path, let ld65 = ld65Path else {
            console.appendConsole("ca65/ld65 non trouves. Installez cc65: brew install cc65", type: .error)
            return
        }
        guard let projectPath = project.projectPath else {
            console.appendConsole("Chemin du projet non defini", type: .error)
            return
        }

        isBuilding = true
        let startTime = Date()
        var errors: [BuildError] = []

        console.appendConsole("=== Build \(project.name) ===", type: .info)

        let srcDir = projectPath.appendingPathComponent("src")
        let buildDir = projectPath.appendingPathComponent("build")
        let linkerConfig = projectPath.appendingPathComponent(project.cartridge.linkerConfigName)
        let outputName = project.buildSettings.outputName
        let outputFile = buildDir.appendingPathComponent("\(outputName).\(project.buildSettings.outputFormat)")

        // Create build directory
        try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        // Assemble each .asm file
        var objectFiles: [URL] = []
        for sourceFile in project.sourceFiles {
            let srcFile = srcDir.appendingPathComponent(sourceFile)
            guard FileManager.default.fileExists(atPath: srcFile.path) else { continue }

            let objFile = buildDir.appendingPathComponent(sourceFile.replacingOccurrences(of: ".asm", with: ".o"))
            objectFiles.append(objFile)

            var args = [
                "--cpu", "65816",
                "-I", srcDir.path,
                "-o", objFile.path,
                srcFile.path,
            ]
            if project.buildSettings.generateDebugSymbols {
                args.insert("-g", at: 0)
            }

            console.appendConsole("$ ca65 \(sourceFile)", type: .command)
            let (output, exitCode) = await runProcess(ca65, arguments: args, workingDirectory: projectPath)

            if exitCode != 0 {
                let parsed = parseCA65Errors(output, sourceFile: sourceFile)
                errors.append(contentsOf: parsed)
                for err in parsed {
                    console.appendConsole(
                        "\(err.file):\(err.line): \(err.severity == .error ? "Error" : "Warning"): \(err.message)",
                        type: err.severity == .error ? .error : .warning,
                        fileRef: FileReference(file: err.file, line: err.line, column: err.column)
                    )
                }
            }
        }

        if !errors.contains(where: { $0.severity == .error }) && !objectFiles.isEmpty {
            // Link
            var linkArgs = [
                "-C", linkerConfig.path,
                "-o", outputFile.path,
            ]
            linkArgs.append(contentsOf: objectFiles.map(\.path))

            if project.buildSettings.generateMapFile {
                let mapFile = buildDir.appendingPathComponent("\(outputName).map")
                linkArgs.append(contentsOf: ["-m", mapFile.path])
            }

            console.appendConsole("$ ld65 -C \(project.cartridge.linkerConfigName) -o \(outputName).\(project.buildSettings.outputFormat)", type: .command)
            let (output, exitCode) = await runProcess(ld65, arguments: linkArgs, workingDirectory: projectPath)

            if exitCode != 0 {
                let parsed = parseLD65Errors(output)
                errors.append(contentsOf: parsed)
                for err in parsed {
                    console.appendConsole("ld65: \(err.message)", type: .error)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let success = !errors.contains(where: { $0.severity == .error })

        var romSize = 0
        if success, FileManager.default.fileExists(atPath: outputFile.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: outputFile.path) {
                romSize = (attrs[.size] as? Int) ?? 0
            }

            // Fix checksum if enabled
            if project.buildSettings.fixChecksum {
                fixChecksum(at: outputFile, mapping: project.cartridge.mapping)
            }
        }

        let result = BuildResult(
            success: success,
            romURL: success ? outputFile : nil,
            romSize: romSize,
            errors: errors,
            duration: duration
        )
        lastResult = result
        isBuilding = false

        if success {
            console.appendConsole("BUILD SUCCEEDED — \(romSize) bytes (\(String(format: "%.2f", duration))s)", type: .success)
        } else {
            console.appendConsole("BUILD FAILED — \(errors.count) error(s) (\(String(format: "%.2f", duration))s)", type: .error)
        }
    }

    // MARK: - Parse errors

    private func parseCA65Errors(_ output: String, sourceFile: String) -> [BuildError] {
        // ca65 format: filename(line): Error: message
        // or: filename(line): Warning: message
        var errors: [BuildError] = []
        let pattern = #"(.+?)\((\d+)\):\s*(Error|Warning):\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return errors }

        for line in output.components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range) {
                let file = (line as NSString).substring(with: match.range(at: 1))
                let lineNum = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let severity = (line as NSString).substring(with: match.range(at: 3))
                let message = (line as NSString).substring(with: match.range(at: 4))

                errors.append(BuildError(
                    file: URL(fileURLWithPath: file).lastPathComponent,
                    line: lineNum,
                    column: 0,
                    message: message,
                    severity: severity == "Error" ? .error : .warning
                ))
            }
        }

        if errors.isEmpty && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(BuildError(
                file: sourceFile, line: 0, column: 0,
                message: output.trimmingCharacters(in: .whitespacesAndNewlines),
                severity: .error
            ))
        }

        return errors
    }

    private func parseLD65Errors(_ output: String) -> [BuildError] {
        var errors: [BuildError] = []
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            errors.append(BuildError(
                file: "linker", line: 0, column: 0,
                message: line.trimmingCharacters(in: .whitespacesAndNewlines),
                severity: .error
            ))
        }
        return errors
    }

    // MARK: - Checksum fix

    private func fixChecksum(at url: URL, mapping: ROMMapping) {
        guard var data = try? Data(contentsOf: url) else { return }
        guard data.count >= 0x10000 else { return }

        // Pad to power of 2 if needed
        var targetSize = 1
        while targetSize < data.count { targetSize <<= 1 }
        if data.count < targetSize {
            data.append(Data(count: targetSize - data.count))
        }

        // Calculate checksum
        var checksum: UInt16 = 0
        for byte in data {
            checksum = checksum &+ UInt16(byte)
        }
        let complement = checksum ^ 0xFFFF

        // Write at header location (varies by mapping)
        let headerBase: Int
        switch mapping {
        case .loROM:   headerBase = 0x7FDC
        case .hiROM, .exHiROM, .sa1: headerBase = 0xFFDC
        }

        guard data.count > headerBase + 3 else { return }
        data[headerBase]     = UInt8(complement & 0xFF)
        data[headerBase + 1] = UInt8(complement >> 8)
        data[headerBase + 2] = UInt8(checksum & 0xFF)
        data[headerBase + 3] = UInt8(checksum >> 8)

        try? data.write(to: url)
    }

    // MARK: - Process helpers

    private func runProcess(_ path: String, arguments: [String], workingDirectory: URL) async -> (String, Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.currentDirectoryURL = workingDirectory

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (output, process.terminationStatus))
                } catch {
                    continuation.resume(returning: (error.localizedDescription, -1))
                }
            }
        }
    }

    private func shell(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
