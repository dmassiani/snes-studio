import SwiftUI

struct NewProjectSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var projectName = ""
    @State private var projectLocation: URL? = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    @State private var selectedProfile: CartridgeProfile = CartridgeProfile.presets[1] // Standard
    @State private var template: ProjectTemplate = .basic
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New SNES Project")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SNESTheme.textPrimary)
                Spacer()
                Text("Step \(step)/3")
                    .font(.system(size: 12))
                    .foregroundStyle(SNESTheme.textSecondary)
            }
            .padding(20)
            .overlay(alignment: .bottom) { SNESTheme.border.frame(height: 1) }

            // Content
            ScrollView {
                Group {
                    switch step {
                    case 1: stepName
                    case 2: stepCartridge
                    case 3: stepSummary
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(SNESTheme.danger)
                    .padding(.horizontal, 20)
            }

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(SNESTheme.textSecondary)

                Spacer()

                if step > 1 {
                    Button("Previous") { withAnimation { step -= 1 } }
                        .buttonStyle(.plain)
                        .foregroundStyle(SNESTheme.textSecondary)
                }

                if step < 3 {
                    Button("Next") { withAnimation { step += 1 } }
                        .buttonStyle(.borderedProminent)
                        .disabled(step == 1 && projectName.isEmpty)
                } else {
                    Button("Create Project") { createProject() }
                        .buttonStyle(.borderedProminent)
                        .disabled(projectName.isEmpty)
                }
            }
            .padding(20)
            .overlay(alignment: .top) { SNESTheme.border.frame(height: 1) }
        }
        .frame(width: 600, height: 540)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Step 1: Name & Location

    private var stepName: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Name")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SNESTheme.textPrimary)

            TextField("My SNES Game", text: $projectName)
                .textFieldStyle(.roundedBorder)

            Text("Location")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SNESTheme.textPrimary)

            HStack {
                Text(projectLocation?.path ?? "Not selected")
                    .font(.system(size: 12))
                    .foregroundStyle(SNESTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Choose...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK {
                        projectLocation = panel.url
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(SNESTheme.info)
            }

            Text("Template")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SNESTheme.textPrimary)

            Picker("", selection: $template) {
                ForEach(ProjectTemplate.allCases) { t in
                    Text("\(t.label) — \(t.description)").tag(t)
                }
            }
            .labelsHidden()
    
            Spacer()
        }
        .padding(20)
    }

    // MARK: - Step 2: Cartridge Profile

    private var stepCartridge: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cartridge Profile")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SNESTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(CartridgeProfile.presets) { profile in
                    ProfileCard(profile: profile, isSelected: selectedProfile == profile) {
                        selectedProfile = profile
                    }
                }
            }

            Spacer()

            // Selected profile detail
            HStack(spacing: 16) {
                DetailChip(label: "ROM", value: formatSize(selectedProfile.romSizeKB))
                DetailChip(label: "Mapping", value: selectedProfile.mapping.rawValue)
                if selectedProfile.sramSizeKB > 0 {
                    DetailChip(label: "SRAM", value: "\(selectedProfile.sramSizeKB) KB")
                }
                if selectedProfile.chip != .none {
                    DetailChip(label: "Chip", value: selectedProfile.chip.rawValue)
                }
            }
        }
        .padding(20)
    }

    // MARK: - Step 3: Summary

    private var stepSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Summary")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SNESTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                SummaryRow(label: "Name", value: projectName)
                SummaryRow(label: "Location", value: projectLocation?.path ?? "?")
                SummaryRow(label: "Template", value: template.label)
            }

            SNESTheme.border.frame(height: 1).padding(.vertical, 4)

            Text("Cartridge")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PyramidLevel.hardware.accent)

            VStack(alignment: .leading, spacing: 6) {
                SummaryRow(label: "Profile", value: selectedProfile.name)
                SummaryRow(label: "ROM", value: formatSize(selectedProfile.romSizeKB))
                SummaryRow(label: "Mapping", value: selectedProfile.mapping.rawValue)
                SummaryRow(label: "Speed", value: selectedProfile.speed.rawValue)
                SummaryRow(label: "SRAM", value: selectedProfile.sramSizeKB > 0 ? "\(selectedProfile.sramSizeKB) KB" : "None")
                SummaryRow(label: "Chip", value: selectedProfile.chip.rawValue)
                SummaryRow(label: "Linker", value: CartridgeConfig.fromProfile(selectedProfile).linkerConfigName)
            }

            SNESTheme.border.frame(height: 1).padding(.vertical, 4)

            Text("Generated Files")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PyramidLevel.logique.accent)

            let config = CartridgeConfig.fromProfile(selectedProfile)
            let files = template.sourceFiles(config: config)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(files.keys.sorted(), id: \.self) { file in
                    Text("src/\(file)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
                Text(config.linkerConfigName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(SNESTheme.textSecondary)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Create

    private func createProject() {
        guard let location = projectLocation else {
            errorMessage = "Select a location"
            return
        }
        let config = CartridgeConfig.fromProfile(selectedProfile)
        do {
            try state.projectManager.createProject(
                name: projectName,
                at: location,
                cartridge: config,
                template: template
            )
            state.loadProject()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatSize(_ kb: Int) -> String {
        kb >= 1024 ? "\(kb / 1024) MB" : "\(kb) KB"
    }
}

// MARK: - Profile Card

private struct ProfileCard: View {
    let profile: CartridgeProfile
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? SNESTheme.textPrimary : SNESTheme.textSecondary)

                Text(profile.romSizeKB >= 1024 ? "\(profile.romSizeKB / 1024) MB" : "\(profile.romSizeKB) KB")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isSelected ? PyramidLevel.hardware.accent : SNESTheme.textDisabled)

                Text(profile.mapping.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)

                if profile.difficulty > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < profile.difficulty ? "star.fill" : "star")
                                .font(.system(size: 6))
                                .foregroundStyle(i < profile.difficulty ? SNESTheme.warning : SNESTheme.textDisabled)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? PyramidLevel.hardware.accentBg : SNESTheme.bgEditor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? PyramidLevel.hardware.accent : SNESTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .opacity(isHovered ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Detail Chip

private struct DetailChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SNESTheme.textDisabled)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(SNESTheme.bgEditor))
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textDisabled)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }
}
