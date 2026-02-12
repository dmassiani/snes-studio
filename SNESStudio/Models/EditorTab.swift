import SwiftUI

struct EditorTab: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let level: PyramidLevel
    var isModified: Bool = false
}

@Observable
final class TabManager {
    var tabs: [EditorTab] = []
    var activeTabID: String?

    var activeTab: EditorTab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    func openTab(for item: SidebarItem) {
        if let existing = tabs.first(where: { $0.id == item.id }) {
            activeTabID = existing.id
        } else {
            let tab = EditorTab(id: item.id, title: item.label, icon: item.icon, level: item.level)
            tabs.append(tab)
            activeTabID = tab.id
        }
    }

    func openScreenTab(screenID: UUID, screenName: String) {
        let tabID = "screen_\(screenID.uuidString)"
        if let existing = tabs.first(where: { $0.id == tabID }) {
            activeTabID = existing.id
        } else {
            let tab = EditorTab(id: tabID, title: screenName, icon: "square.grid.3x3.fill", level: .orchestre)
            tabs.append(tab)
            activeTabID = tab.id
        }
    }

    func closeTab(_ id: String) {
        tabs.removeAll { $0.id == id }
        if activeTabID == id {
            activeTabID = tabs.last?.id
        }
    }

    func closeAllTabs() {
        tabs.removeAll()
        activeTabID = nil
    }

    func activateTab(_ id: String) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabID = id
        }
    }

    func cycleTab() {
        guard tabs.count > 1, let currentID = activeTabID,
              let idx = tabs.firstIndex(where: { $0.id == currentID }) else { return }
        let next = (idx + 1) % tabs.count
        activeTabID = tabs[next].id
    }

    func closeActiveTab() {
        if let id = activeTabID {
            closeTab(id)
        }
    }
}
