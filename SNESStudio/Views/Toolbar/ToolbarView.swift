import SwiftUI

struct ToolbarView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Left: Build/Run actions
            HStack(spacing: 6) {
                ToolbarButton(icon: "hammer", label: "Build", shortcut: "B") {
                    Task { await state.buildProject() }
                }
                ToolbarButton(icon: "play.fill", label: "Run", shortcut: "R") {
                    Task { await state.buildProject() }
                }
                ToolbarButton(icon: "arrow.clockwise", label: "Hot Reload") {
                    state.appendConsole("Hot Reload...", type: .command)
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Center: level tabs
            HStack(spacing: 0) {
                ForEach(PyramidLevel.allCases) { level in
                    let isActive = state.activeLevel == level
                    Button {
                        state.setLevel(level)
                    } label: {
                        Text(level.label)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(isActive ? level.accent : SNESTheme.textDisabled)
                            .padding(.horizontal, 12)
                            .frame(height: SNESTheme.toolbarHeight)
                            .overlay(alignment: .bottom) {
                                if isActive {
                                    level.accent.frame(height: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Right: Aide, IA, Search, Console toggle
            HStack(spacing: 6) {
                ToolbarToggle(icon: "questionmark.circle", label: "Aide",
                              isActive: state.isRightPanelVisible && state.rightPanelMode == .aide) {
                    state.toggleAide()
                }
                ToolbarToggle(icon: "bubble.left", label: "IA",
                              isActive: state.isRightPanelVisible && state.rightPanelMode == .chat) {
                    state.toggleChat()
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ToolbarButton(icon: "magnifyingglass", label: "Search") {}

                ToolbarToggle(icon: "terminal", isActive: state.isConsoleVisible) {
                    state.toggleConsole()
                }
            }
            .padding(.trailing, 12)
        }
        .frame(height: SNESTheme.toolbarHeight)
        .background(SNESTheme.bgPanel)
        .overlay(alignment: .bottom) {
            SNESTheme.border.frame(height: 1)
        }
    }
}

// MARK: - Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let label: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { isPressed = false }
            }
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(SNESTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(SNESTheme.bgEditor.opacity(isPressed ? 1 : 0))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .help(shortcut != nil ? "\(label) (Cmd+\(shortcut!))" : label)
    }
}

// MARK: - Toolbar Toggle

private struct ToolbarToggle: View {
    let icon: String
    var label: String? = nil
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundStyle(isActive ? SNESTheme.textPrimary : SNESTheme.textDisabled)
            .padding(.horizontal, label != nil ? 8 : 0)
            .frame(minWidth: 24, minHeight: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? SNESTheme.bgEditor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
