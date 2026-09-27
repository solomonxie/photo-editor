import Foundation

/// Snapshot undo/redo. A gesture (slider drag, layer drag) folds into one step.
nonisolated struct EditHistory: Sendable {
    private(set) var undoStack: [EditDocument] = []
    private(set) var redoStack: [EditDocument] = []
    private var gestureStart: EditDocument?
    let limit: Int

    init(limit: Int = 100) {
        self.limit = limit
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Call before a discrete change with the document as it was.
    mutating func record(_ before: EditDocument) {
        guard gestureStart == nil else { return }
        push(before)
    }

    mutating func beginGesture(_ before: EditDocument) {
        if gestureStart == nil { gestureStart = before }
    }

    mutating func endGesture(_ after: EditDocument) {
        guard let start = gestureStart else { return }
        gestureStart = nil
        if start != after { push(start) }
    }

    mutating func undo(_ current: EditDocument) -> EditDocument? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    mutating func redo(_ current: EditDocument) -> EditDocument? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    private mutating func push(_ doc: EditDocument) {
        undoStack.append(doc)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
    }
}
