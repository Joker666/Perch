import AppKit

/// Main menu items whose title or state follows the model: Undo, Redo, the todo
/// commands in Edit, and Show or Hide Perch in Window. They are AppKit items,
/// because SwiftUI never redraws the main menu of an app with no SwiftUI window.
@MainActor
final class AppMenus: NSObject, NSMenuItemValidation {
    static let shared = AppMenus()

    /// Marks Perch's items, so `ensure` can tell whether they are still in the menu.
    private static let tag = 0x5052_4348 // 'PRCH'

    private var model: AppModel { Shared.model }

    /// Adds the items, and adds them back one run loop turn after SwiftUI rebuilds a
    /// menu. That is too late for the shortcut that caused the rebuild, so the
    /// windows call `performKeyEquivalent` first.
    func install() {
        ensure()
        let center = NotificationCenter.default
        for name in [NSMenu.didAddItemNotification, NSMenu.didRemoveItemNotification,
                     NSMenu.didChangeItemNotification, NSApplication.didBecomeActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppMenus.shared.ensureSoon() }
            }
        }
        center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppMenus.shared.ensure() }
        }
    }

    private var ensureQueued = false

    /// One `ensure` for a burst of menu changes.
    private func ensureSoon() {
        guard !ensureQueued else { return }
        ensureQueued = true
        DispatchQueue.main.async {
            self.ensureQueued = false
            self.ensure()
        }
    }

    func ensure() {
        guard let menu = NSApp.mainMenu else { return }
        if let edit = submenu("Edit", in: menu), edit.item(withTag: Self.tag) == nil {
            insert(editTop, into: edit, at: 0)
            let selectAll = edit.items.firstIndex { $0.action == #selector(NSResponder.selectAll(_:)) }
            insert(editTodo, into: edit, at: (selectAll ?? edit.items.count - 1) + 1)
        }
        if let window = submenu("Window", in: menu), window.item(withTag: Self.tag) == nil {
            let index = window.items.firstIndex { $0.action == #selector(NSApplication.arrangeInFront(_:)) } ?? window.items.count
            insert(windowItems, into: window, at: index)
        }
    }

    /// Runs the item whose shortcut `event` is, as the menu would. False when no
    /// item has that shortcut, or when the item is off.
    func performKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard flags.contains(.command), var key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if key == "\u{7F}" { key = "\u{8}" }  // the Delete key, which menus write as backspace
        guard let item = (editTop + editTodo + windowItems).first(where: {
            $0.action != nil && $0.keyEquivalent == key && $0.keyEquivalentModifierMask == flags
        }), validateMenuItem(item), let action = item.action else { return false }
        return NSApp.sendAction(action, to: self, from: item)
    }

    // MARK: Items

    // Made once and put back after each rebuild, so `performKeyEquivalent` can find them.
    private lazy var editTop: [NSMenuItem] = [
        item("Undo", #selector(undo(_:)), "z"),
        item("Redo", #selector(redo(_:)), "z", [.command, .shift]),
        .separator(),
    ]
    private lazy var editTodo: [NSMenuItem] = [
        .separator(),
        item("Complete Todo", #selector(complete(_:)), "\r"),
        item("Delete Todo", #selector(deleteTodo(_:)), "\u{8}"),
        item("Move Todo Up", #selector(moveUp(_:)), key(NSUpArrowFunctionKey), [.command, .option]),
        item("Move Todo Down", #selector(moveDown(_:)), key(NSDownArrowFunctionKey), [.command, .option]),
        .separator(),
        item("Clear Archive…", #selector(clearArchive(_:)), ""),
    ]
    private lazy var windowItems: [NSMenuItem] = [
        item("Hide Perch", #selector(showOrHide(_:)), "0"),
        .separator(),
    ]

    private func insert(_ items: [NSMenuItem], into menu: NSMenu, at index: Int) {
        for (offset, item) in items.enumerated() {
            item.menu?.removeItem(item)  // still in a menu SwiftUI replaced
            menu.insertItem(item, at: index + offset)
        }
    }

    // MARK: Actions

    @objc func undo(_ sender: Any?) { model.undoManager.undo() }
    @objc func redo(_ sender: Any?) { model.undoManager.redo() }
    @objc func complete(_ sender: Any?) { model.completeSelected() }
    @objc func deleteTodo(_ sender: Any?) { model.deleteSelected() }
    @objc func moveUp(_ sender: Any?) { model.moveSelected(by: -1) }
    @objc func moveDown(_ sender: Any?) { model.moveSelected(by: 1) }
    @objc func clearArchive(_ sender: Any?) { confirmClearArchive(model) }
    @objc func showOrHide(_ sender: Any?) { PanelController.shared.toggle() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        let undo = model.undoManager
        let hasSelection = !model.selectedIDs.isEmpty
        switch item.action {
        case #selector(undo(_:)):
            item.title = undo.undoMenuItemTitle
            return undo.canUndo
        case #selector(redo(_:)):
            item.title = undo.redoMenuItemTitle
            return undo.canRedo
        case #selector(complete(_:)), #selector(moveUp(_:)), #selector(moveDown(_:)):
            return model.mode == .list && hasSelection
        case #selector(deleteTodo(_:)):
            return hasSelection
        case #selector(clearArchive(_:)):
            return !model.archived.isEmpty
        case #selector(showOrHide(_:)):
            item.title = model.showHideTitle
            return true
        default:
            return true
        }
    }

    // MARK: Building

    private func item(_ title: String, _ action: Selector, _ key: String,
                      _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        item.tag = Self.tag
        return item
    }

    private func key(_ functionKey: Int) -> String {
        String(Character(UnicodeScalar(UInt16(functionKey))!))
    }

    private func submenu(_ title: String, in menu: NSMenu) -> NSMenu? {
        menu.items.first { $0.submenu?.title == title }?.submenu
    }
}
