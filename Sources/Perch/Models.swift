import AppKit
import Foundation
import SwiftData
import PerchKit

@Model
final class Todo {
    /// A stable id for selection, undo, and the agent CLI.
    var uuid: UUID = UUID()
    var text: String = ""
    var isCompleted: Bool = false
    var order: Double = 0
    var createdAt: Date = Date.now
    var completedAt: Date?

    init(text: String, order: Double) {
        self.text = text
        self.order = order
    }
}

/// A plain copy of a todo. Undo restores the whole list from these, so a
/// deleted todo comes back with the same id.
struct TodoRecord: Equatable {
    var uuid: UUID
    var text: String
    var isCompleted: Bool
    var order: Double
    var createdAt: Date
    var completedAt: Date?

    init(_ todo: Todo) {
        uuid = todo.uuid
        text = todo.text
        isCompleted = todo.isCompleted
        order = todo.order
        createdAt = todo.createdAt
        completedAt = todo.completedAt
    }

    func apply(to todo: Todo) {
        todo.uuid = uuid
        todo.text = text
        todo.isCompleted = isCompleted
        todo.order = order
        todo.createdAt = createdAt
        todo.completedAt = completedAt
    }
}

/// What the panel shows.
enum PanelMode: String, CaseIterable {
    case list, archive
}

/// Where the keyboard is in the panel. The rules that move it are `FocusRules` (PerchKit).
typealias PanelFocus = RowFocus<UUID>

/// App-wide state the panel, menus, and Settings share.
@Observable
final class AppModel {
    let container: ModelContainer
    let undoManager = UndoManager()

    var mode: PanelMode = .list { didSet { if mode != oldValue { focus = .none } } }
    var focus: PanelFocus = .none
    /// Todos not completed, in list order.
    private(set) var todos: [Todo] = []
    /// Completed todos, newest first.
    private(set) var archived: [Todo] = []
    /// Rows playing the completion animation. They stay in `todos` until it ends.
    private(set) var completing: Set<UUID> = []
    /// Settings reopens on the last tab.
    var settingsTab: SettingsTab = .theme
    /// Mirrors the panel's visibility for the Show and Hide menu items.
    var panelVisible = false
    /// The Show and Hide menu items' title.
    var showHideTitle: String { panelVisible ? "Hide Perch" : "Show Perch" }
    /// True while the panel takes the keyboard. The traffic lights show color only then.
    var panelIsKey = false

    /// The list before the current edit began, for that edit's undo step.
    private var editStart: [TodoRecord]?
    private var editIsNew = false

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
        undoManager.levelsOfUndo = 100
        reload()
    }

    // MARK: Reading

    func reload() {
        let all = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        todos = all.filter { !$0.isCompleted }.sorted { $0.order < $1.order }
        archived = all.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// The rows the panel shows in the current mode.
    var visible: [Todo] { mode == .list ? todos : archived }

    func todo(_ id: UUID) -> Todo? {
        todos.first { $0.uuid == id } ?? archived.first { $0.uuid == id }
    }

    var editingID: UUID? { focus.editingID }

    /// The ids highlighted as selected.
    var selectedIDs: [UUID] { focus.selectedIDs(in: visible.map(\.uuid)) }

    // MARK: Adding and editing

    /// Adds an empty todo after `id` (or at the end) and starts editing it.
    /// Nothing is saved for undo until the text is committed.
    func add(after id: UUID? = nil) {
        if mode != .list { mode = .list }
        commitEditing()
        let start = records()
        let todo = Todo(text: "", order: insertionOrder(after: id))
        change(nil) { context.insert(todo) }
        editStart = start
        editIsNew = true
        focus = .editing(todo.uuid)
    }

    /// Adds a todo with its text in one step, with one undo step. The agent
    /// CLI uses it. Returns nil when the text is empty.
    @discardableResult
    func add(text: String, after id: UUID? = nil) -> Todo? {
        guard let text = TodoText.clean(text) else { return nil }
        commitEditing()
        let todo = Todo(text: text, order: insertionOrder(after: id))
        change("Add Todo") { context.insert(todo) }
        return todo
    }

    /// Changes a todo's text without the typing flow, with one undo step.
    /// Returns false when the text was already the same. Empty text is refused.
    func rename(_ id: UUID, to text: String) -> Bool {
        guard let todo = todo(id), let text = TodoText.clean(text), todo.text != text else { return false }
        if editingID == id { commitEditing() }
        change("Edit Todo") { todo.text = text }
        return true
    }

    /// The order value for a todo placed after `id`, or at the end of the List.
    private func insertionOrder(after id: UUID?) -> Double {
        let index = id.flatMap { id in todos.firstIndex { $0.uuid == id } }
        let before = index.map { todos[$0].order } ?? todos.last?.order
        let after = index.flatMap { $0 + 1 < todos.count ? todos[$0 + 1].order : nil }
        return TodoOrder.between(before, after)
    }

    /// Starts typing in a row. Ends any other edit first.
    func beginEditing(_ id: UUID) {
        guard editingID != id, mode == .list else { return }
        commitEditing()
        editStart = records()
        editIsNew = false
        focus = .editing(id)
    }

    /// Live text from the row's field. The model keeps it so a quit mid-edit loses nothing.
    func updateText(_ id: UUID, _ text: String) {
        todo(id)?.text = text
    }

    /// Ends the edit: an empty row is removed, a changed row gets one undo step.
    /// Focus moves to `next`, or the row stays selected when `next` is nil.
    func commitEditing(then next: PanelFocus? = nil) {
        guard let id = editingID, let todo = todo(id) else {
            if let next { focus = next }
            return
        }
        let start = editStart
        editStart = nil
        if let text = TodoText.clean(todo.text) {
            change(start == nil ? nil : editIsNew ? "Add Todo" : "Edit Todo", from: start) { todo.text = text }
        } else {
            // An emptied row that existed before is a delete. A new empty row was never a todo.
            change(start == nil || editIsNew ? nil : "Delete Todo", from: start) { context.delete(todo) }
        }
        focus = next ?? .none
    }

    // MARK: Moving the keyboard

    /// Up and Down while typing: edit the row above or below.
    func editNeighbor(of id: UUID, step: Int) {
        guard let target = FocusRules.neighbor(of: id, step: step, in: todos.map(\.uuid)) else { return }
        commitEditing()
        if todo(target) != nil { beginEditing(target) }
    }

    /// Shift-Up and Shift-Down: select rows. From typing, the typed row is the anchor.
    func extendSelection(step: Int) {
        let before = focus
        if before.editingID != nil { commitEditing() }
        if let next = FocusRules.extending(before, step: step, in: visible.map(\.uuid)) { focus = next }
    }

    /// Up and Down with no row typing: move to one row. In the list that row starts typing.
    func moveCursor(step: Int) {
        if let next = FocusRules.cursor(from: focus, step: step, in: visible.map(\.uuid), isList: mode == .list) {
            go(to: next)
        }
    }

    /// Click and Shift-click on a row.
    func click(_ id: UUID, extend: Bool) {
        let next = FocusRules.click(id, extend: extend, from: focus, isList: mode == .list)
        if extend { commitEditing() }
        go(to: next)
    }

    /// Typing in a row starts an edit. Any other focus is set as it is.
    private func go(to next: PanelFocus) {
        if let id = next.editingID { beginEditing(id) } else { focus = next }
    }

    // MARK: Changing todos

    /// Marks todos done. The rows play the check and sweep, then leave the list.
    /// `animated: false` (the agent CLI) completes at once and silently, inside the command's undo group.
    func complete(_ ids: [UUID], animated: Bool = true) {
        let ids = ids.filter { todo($0)?.isCompleted == false && !completing.contains($0) }
        guard !ids.isEmpty else { return }
        commitEditing()
        let start = records()
        let live = ids.filter { todo($0) != nil }
        guard !live.isEmpty else { return }
        let next = FocusRules.afterRemoving(Set(live), from: todos.map(\.uuid))
        guard animated else {
            finishCompleting(live, start: start, next: next)
            return
        }
        CompletionSound.play()
        completing.formUnion(live)
        Task {
            try? await Task.sleep(for: .seconds(Motion.completionSettle))
            self.finishCompleting(live, start: start, next: next)
        }
    }

    private func finishCompleting(_ ids: [UUID], start: [TodoRecord], next: PanelFocus) {
        completing.subtract(ids)
        change(ids.count == 1 ? "Complete Todo" : "Complete Todos", from: start) {
            for id in ids {
                guard let todo = todo(id) else { continue }
                todo.isCompleted = true
                todo.completedAt = .now
            }
        }
        if case .selection = focus { focus = next }
    }

    /// Completes the selected rows, or the row being typed in.
    func completeSelected() {
        complete(selectedIDs)
    }

    /// Moves completed todos back to the end of the list.
    func restore(_ ids: [UUID]) {
        change(ids.count == 1 ? "Restore Todo" : "Restore Todos") {
            var last = todos.last?.order
            for id in ids {
                guard let todo = todo(id), todo.isCompleted else { continue }
                todo.isCompleted = false
                todo.completedAt = nil
                todo.order = TodoOrder.between(last, nil)
                last = todo.order
            }
        }
    }

    func delete(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        if editingID != nil, ids != [editingID] { commitEditing() }
        let start = editStart ?? records()
        editStart = nil
        let next = FocusRules.afterRemoving(Set(ids), from: visible.map(\.uuid))
        change(ids.count == 1 ? "Delete Todo" : "Delete Todos", from: start) {
            for id in ids { if let todo = todo(id) { context.delete(todo) } }
        }
        focus = next
    }

    func deleteSelected() {
        delete(selectedIDs)
    }

    /// Backspace in an empty row: remove it and keep typing at the end of the row above.
    func deleteEmptyRow(_ id: UUID) {
        guard todos.contains(where: { $0.uuid == id }) else { return }
        let above = FocusRules.neighbor(of: id, step: -1, in: todos.map(\.uuid))
        commitEditing()
        if let above { beginEditing(above) }
    }

    /// Drag and Command-Option-arrow: moves rows so they land before the row now at `destination`.
    func move(_ ids: [UUID], to destination: Int) {
        let current = todos.map(\.uuid)
        let indices = IndexSet(ids.compactMap { current.firstIndex(of: $0) })
        guard !indices.isEmpty else { return }
        let reordered = TodoOrder.moving(todos, indices: indices, to: destination)
        guard reordered.map(\.uuid) != current else { return }
        // While a row is typed in, the move joins that edit's undo step.
        change(editStart == nil ? (ids.count == 1 ? "Move Todo" : "Move Todos") : nil) {
            for (todo, order) in zip(reordered, TodoOrder.renumbered(count: reordered.count)) { todo.order = order }
        }
    }

    /// Command-Option-Up and -Down: moves the selected rows one place.
    func moveSelected(by step: Int) {
        guard mode == .list else { return }
        let ids = todos.map(\.uuid)
        let selected = selectedIDs
        let positions = selected.compactMap { ids.firstIndex(of: $0) }
        guard let low = positions.min(), let high = positions.max() else { return }
        if step < 0, low > 0 { move(selected, to: low - 1) }
        if step > 0, high + 1 < ids.count { move(selected, to: high + 2) }
    }

    func clearArchive() {
        guard !archived.isEmpty else { return }
        change("Clear Archive") { for todo in archived { context.delete(todo) } }
        focus = .none
    }

    // MARK: Saving and undo

    /// Every todo change: runs `body`, saves (renumbering a crowded List), adds an
    /// undo step back to `start`, and reloads. No undo step when nothing changed,
    /// or when `undoName` is nil because the change joins an open edit.
    private func change(_ undoName: String?, from start: [TodoRecord]? = nil, _ body: () -> Void) {
        let start = undoName == nil ? nil : start ?? records()
        body()
        save()
        if let undoName, let start, start != records() { registerUndo(start, name: undoName) }
        reload()
    }

    private func records() -> [TodoRecord] {
        ((try? context.fetch(FetchDescriptor<Todo>())) ?? []).map(TodoRecord.init)
    }

    /// One undo step that puts the whole list back to `records`. Redo puts it back again.
    private func registerUndo(_ records: [TodoRecord], name: String) {
        // The app groups undo by event. The self-test turns that off and groups each step itself.
        let explicit = !undoManager.groupsByEvent && !undoManager.isUndoing && !undoManager.isRedoing
        if explicit { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { model in
            let now = model.records()
            model.restoreAll(records)
            model.registerUndo(now, name: name)
        }
        undoManager.setActionName(name)
        if explicit { undoManager.endUndoGrouping() }
    }

    private func restoreAll(_ records: [TodoRecord]) {
        editStart = nil
        focus = .none
        completing = []
        let all = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        var byID = Dictionary(all.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        for record in records {
            if let todo = byID.removeValue(forKey: record.uuid) {
                record.apply(to: todo)
            } else {
                let todo = Todo(text: record.text, order: record.order)
                record.apply(to: todo)
                context.insert(todo)
            }
        }
        for leftover in byID.values { context.delete(leftover) }
        save()
        reload()
    }

    /// Saves, and renumbers the List when two order values get too close.
    private func save() {
        try? context.save()
        // Read the open todos from the store, not `todos`, which misses a todo added in this change.
        let all = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        let open = all.filter { !$0.isCompleted }.sorted { $0.order < $1.order }
        guard TodoOrder.isCrowded(open.map(\.order)) else { return }
        for (todo, order) in zip(open, TodoOrder.renumbered(count: open.count)) { todo.order = order }
        try? context.save()
    }
}
