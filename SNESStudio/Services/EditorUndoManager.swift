import Foundation

/// Generic undo manager for visual editors.
/// Stores snapshots of Codable state and supports undo/redo.
final class EditorUndoManager<State: Codable & Equatable> {
    private var undoStack: [Data] = []
    private var redoStack: [Data] = []
    private let maxHistory = 50
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Record the current state before a change.
    func recordState(_ state: State) {
        guard let data = try? encoder.encode(state) else { return }
        undoStack.append(data)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Undo: restore previous state and push current state onto redo stack.
    func undo(current: State) -> State? {
        guard let previousData = undoStack.popLast() else { return nil }
        if let currentData = try? encoder.encode(current) {
            redoStack.append(currentData)
        }
        return try? decoder.decode(State.self, from: previousData)
    }

    /// Redo: restore next state and push current state onto undo stack.
    func redo(current: State) -> State? {
        guard let nextData = redoStack.popLast() else { return nil }
        if let currentData = try? encoder.encode(current) {
            undoStack.append(currentData)
        }
        return try? decoder.decode(State.self, from: nextData)
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
