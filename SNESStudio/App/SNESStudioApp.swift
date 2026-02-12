import SwiftUI

@main
struct SNESStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView(state: appState)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1440, height: 900)

        Window("Sprite Drawing", id: "sprite-drawing") {
            SpriteDrawingWindowView(state: appState)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 650)

        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }
        .commands {
            // Step 11 — Keyboard shortcuts

            // Pyramid levels: Cmd+1/2/3/4
            CommandGroup(after: .toolbar) {
                Button("Hardware (Niveau 1)") {
                    NotificationCenter.default.post(name: .setLevel, object: PyramidLevel.hardware)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Atelier (Niveau 2)") {
                    NotificationCenter.default.post(name: .setLevel, object: PyramidLevel.atelier)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Orchestre (Niveau 3)") {
                    NotificationCenter.default.post(name: .setLevel, object: PyramidLevel.orchestre)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Logique (Niveau 4)") {
                    NotificationCenter.default.post(name: .setLevel, object: PyramidLevel.logique)
                }
                .keyboardShortcut("4", modifiers: [.command])

                Divider()
            }

            // Panel toggles
            CommandGroup(after: .sidebar) {
                Button("Toggle Right Panel") {
                    NotificationCenter.default.post(name: .toggleRightPanel, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Toggle Console") {
                    NotificationCenter.default.post(name: .toggleConsole, object: nil)
                }
                .keyboardShortcut("j", modifiers: [.command])

                Divider()
            }

            // Build & Run
            CommandGroup(replacing: .newItem) {
                Button("New Project...") {
                    NSApp.sendAction(#selector(AppDelegate.newProject), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open Project...") {
                    NSApp.sendAction(#selector(AppDelegate.openProject), to: nil, from: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()

                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    // Route undo to sprite drawing window if active
                    if appState.spriteDrawingSession.isActive {
                        NotificationCenter.default.post(name: .spriteDrawingUndo, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .editorUndo, object: nil)
                    }
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("Redo") {
                    if appState.spriteDrawingSession.isActive {
                        NotificationCenter.default.post(name: .spriteDrawingRedo, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .editorRedo, object: nil)
                    }
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandMenu("Build") {
                Button("Build") {
                    NotificationCenter.default.post(name: .buildProject, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button("Build & Run") {
                    NotificationCenter.default.post(name: .runProject, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Hot Reload") {
                    NotificationCenter.default.post(name: .hotReload, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            // Tab management
            CommandGroup(after: .windowArrangement) {
                Button("Cycle Tabs") {
                    NotificationCenter.default.post(name: .cycleTabs, object: nil)
                }
                .keyboardShortcut("`", modifiers: [.command])

                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command])
            }

            // Sprite drawing frame navigation
            CommandGroup(after: .pasteboard) {
                Button("Previous Frame") {
                    NotificationCenter.default.post(name: .spriteDrawingPrevFrame, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Button("Next Frame") {
                    NotificationCenter.default.post(name: .spriteDrawingNextFrame, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("SNES Studio Help") {}
            }
        }
    }
}

// MARK: - Notification Names for keyboard shortcuts

extension Notification.Name {
    static let setLevel = Notification.Name("SNESStudio.setLevel")
    static let toggleRightPanel = Notification.Name("SNESStudio.toggleRightPanel")
    static let toggleConsole = Notification.Name("SNESStudio.toggleConsole")
    static let buildProject = Notification.Name("SNESStudio.build")
    static let runProject = Notification.Name("SNESStudio.run")
    static let hotReload = Notification.Name("SNESStudio.hotReload")
    static let cycleTabs = Notification.Name("SNESStudio.cycleTabs")
    static let closeTab = Notification.Name("SNESStudio.closeTab")
    static let saveFile = Notification.Name("SNESStudio.saveFile")
    static let setCursorPosition = Notification.Name("SNESStudio.setCursorPosition")
    static let editorUndo = Notification.Name("SNESStudio.editorUndo")
    static let editorRedo = Notification.Name("SNESStudio.editorRedo")
    static let showNewProject = Notification.Name("SNESStudio.showNewProject")
    static let openProject = Notification.Name("SNESStudio.openProject")
    static let assetStoreDidChange = Notification.Name("SNESStudio.assetStoreDidChange")
    static let codeFileDidChange = Notification.Name("SNESStudio.codeFileDidChange")
    static let flushAutoSave = Notification.Name("SNESStudio.flushAutoSave")
    static let spriteDrawingUndo = Notification.Name("SNESStudio.spriteDrawingUndo")
    static let spriteDrawingRedo = Notification.Name("SNESStudio.spriteDrawingRedo")
    static let spriteDrawingPrevFrame = Notification.Name("SNESStudio.spriteDrawingPrevFrame")
    static let spriteDrawingNextFrame = Notification.Name("SNESStudio.spriteDrawingNextFrame")
}
