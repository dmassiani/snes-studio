import SwiftUI
import Combine

struct MainView: View {
    @Bindable var state: AppState

    // Drag state for resize handles
    @State private var dragRightStart: CGFloat = 0
    @State private var dragBottomStart: CGFloat = 0

    private var hasProject: Bool {
        state.projectManager.currentProject != nil
    }

    var body: some View {
        mainContent
            .background(SNESTheme.bgMain)
            .frame(
                minWidth: SNESTheme.windowMinWidth,
                minHeight: SNESTheme.windowMinHeight
            )
            .modifier(KeyboardShortcutHandlers(state: state))
            .sheet(isPresented: $state.showNewProjectSheet) {
                NewProjectSheet(state: state)
            }
            .onReceive(NotificationCenter.default.publisher(for: .assetStoreDidChange)) { notif in
                state.recalculateBudget()
                let debounce = (notif.userInfo?["debounce"] as? Bool) ?? false
                if debounce {
                    state.scheduleAutoSave()
                } else {
                    state.saveAssetsNow()
                }
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        if hasProject {
            ideLayout
        } else {
            WelcomeView(state: state)
        }
    }

    // MARK: - IDE Layout (only when project is open)

    private var ideLayout: some View {
        VStack(spacing: 0) {
            // Toolbar (includes level tabs)
            ToolbarView(state: state)

            // Sub-tabs
            SubTabBar(state: state)

            // Main content area
            HStack(spacing: 0) {
                // Center area (editor + bottom)
                VStack(spacing: 0) {
                    CenterEditorView(state: state)
                        .frame(minWidth: 400)

                    // Bottom area: Hardware Bar + Console
                    bottomArea
                }

                // Right panel (Aide / IA) — full height
                if state.isRightPanelVisible {
                    ResizeHandle(direction: .horizontal) { delta in
                        let newWidth = dragRightStart - delta
                        state.rightPanelWidth = min(max(newWidth, SNESTheme.rightPanelMinWidth), SNESTheme.rightPanelMaxWidth)
                    }
                    .onAppear { dragRightStart = state.rightPanelWidth }
                    .onChange(of: state.rightPanelWidth) { _, new in dragRightStart = new }

                    RightPanelView(state: state)
                        .frame(width: state.rightPanelWidth)
                }
            }
        }
    }

    private var bottomArea: some View {
        VStack(spacing: 0) {
            ResizeHandle(direction: .vertical) { delta in
                let newHeight = dragBottomStart - delta
                let minH = SNESTheme.hardwareBarHeight + 40
                let maxH: CGFloat = 400
                state.bottomHeight = min(max(newHeight, minH), maxH)
            }
            .onAppear { dragBottomStart = state.bottomHeight }
            .onChange(of: state.bottomHeight) { _, new in dragBottomStart = new }

            HStack(spacing: 0) {
                HardwareBarView(meters: state.budgetMeters)
                    .frame(minWidth: 380, maxWidth: 520)

                SNESTheme.border.frame(width: 1)

                if state.isConsoleVisible {
                    ConsoleView(state: state)
                } else {
                    collapsedConsole
                }
            }
            .frame(height: state.isConsoleVisible
                ? state.bottomHeight
                : SNESTheme.hardwareBarHeight)
        }
    }

    private var collapsedConsole: some View {
        HStack {
            Text("CONSOLE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textDisabled)
            Spacer()
            Button {
                state.toggleConsole()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SNESTheme.bgConsole)
    }
}

// MARK: - Keyboard Shortcut Handlers

private struct KeyboardShortcutHandlers: ViewModifier {
    @Bindable var state: AppState

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .setLevel)) { notif in
                if let level = notif.object as? PyramidLevel {
                    state.setLevel(level)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleRightPanel)) { _ in
                state.toggleRightPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleConsole)) { _ in
                state.toggleConsole()
            }
            .onReceive(NotificationCenter.default.publisher(for: .buildProject)) { _ in
                Task { await state.buildProject() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .runProject)) { _ in
                Task { await state.buildProject() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hotReload)) { _ in
                state.appendConsole("Hot Reload...", type: .command)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showNewProject)) { _ in
                state.showNewProjectSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openProject)) { _ in
                state.projectManager.openProjectPanel()
                state.loadProject()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
                state.saveActiveFile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cycleTabs)) { _ in
                state.tabManager.cycleTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
                state.tabManager.closeActiveTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .flushAutoSave)) { _ in
                state.flushAutoSave()
            }
    }
}

#Preview {
    MainView(state: AppState())
        .frame(width: 1440, height: 900)
}
