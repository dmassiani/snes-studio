import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window appearance
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any pending auto-save before quitting
        NotificationCenter.default.post(name: .flushAutoSave, object: nil)
    }

    @objc func newProject() {
        NotificationCenter.default.post(name: .showNewProject, object: nil)
    }

    @objc func openProject() {
        NotificationCenter.default.post(name: .openProject, object: nil)
    }
}
