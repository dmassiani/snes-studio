import SwiftUI

struct WelcomeView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Left: Recent projects (full height)
            recentProjectsSidebar

            SNESTheme.border.frame(width: 1)

            // Right: Welcome content
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Logo / Title
                    VStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        PyramidLevel.logique.accent,
                                        PyramidLevel.orchestre.accent,
                                        PyramidLevel.atelier.accent,
                                        PyramidLevel.hardware.accent,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("SNES Studio")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(SNESTheme.textPrimary)

                        Text("Developpez des jeux Super Nintendo")
                            .font(.system(size: 14))
                            .foregroundStyle(SNESTheme.textSecondary)
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        WelcomeButton(
                            icon: "plus",
                            title: "Nouveau projet",
                            color: SNESTheme.info
                        ) {
                            state.showNewProjectSheet = true
                        }

                        WelcomeButton(
                            icon: "folder",
                            title: "Ouvrir projet",
                            color: SNESTheme.success
                        ) {
                            state.projectManager.openProjectPanel()
                            state.loadProject()
                        }
                    }

                    WelcomeButton(
                        icon: "magnifyingglass",
                        title: "Analyser ROM",
                        color: PyramidLevel.orchestre.accent,
                        isSecondary: true
                    ) {
                        // TODO: Analyze ROM
                    }

                    // Keyboard hints
                    Text("Cmd+N (nouveau) | Cmd+O (ouvrir)")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Recent projects sidebar

    private var recentProjectsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("PROJETS RECENTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textDisabled)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            if state.projectManager.recentProjects.isEmpty {
                Text("Aucun projet recent")
                    .font(.system(size: 12))
                    .foregroundStyle(SNESTheme.textDisabled)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(state.projectManager.recentProjects, id: \.self) { url in
                            RecentProjectRow(url: url) {
                                if FileManager.default.fileExists(atPath: url.path) {
                                    state.projectManager.openProject(at: url)
                                    state.loadProject()
                                } else {
                                    state.appendConsole("Projet introuvable: \(url.lastPathComponent)", type: .warning)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Spacer()
        }
        .frame(width: 240)
        .background(SNESTheme.bgPanel)
    }
}

// MARK: - Recent Project Row

private struct RecentProjectRow: View {
    let url: URL
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(SNESTheme.info)

                VStack(alignment: .leading, spacing: 1) {
                    Text(projectName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SNESTheme.textPrimary)

                    Text(truncatedPath)
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? SNESTheme.border.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var projectName: String {
        url.deletingPathExtension().lastPathComponent
    }

    private var truncatedPath: String {
        let path = url.deletingLastPathComponent().path
        if path.count > 50 {
            return "..." + path.suffix(47)
        }
        return path
    }
}

// MARK: - Welcome Button

private struct WelcomeButton: View {
    let icon: String
    let title: String
    let color: Color
    var isSecondary: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { isPressed = false }
            }
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSecondary ? color : SNESTheme.bgMain)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSecondary ? color.opacity(0.15) : color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isHovered ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
