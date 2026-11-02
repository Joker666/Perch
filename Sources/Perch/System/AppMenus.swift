import AppKit

/// The main menu items whose title or state follows the model: Undo, Redo,
/// the todo commands in Edit, and Show or Hide Perch in Window.
///
/// They are AppKit items, not SwiftUI commands. Perch has no SwiftUI window
/// (the panel and Settings are AppKit), and SwiftUI never redraws the main
/// menu after launch then: items stayed off, and Undo missed an agent's change.
/// AppKit validates each item when its menu opens and when its shortcut is pressed.
@MainActor
final class AppMenus: NSObject, NSMenuItemValidation {
    static let shared = AppMenus()

    /// Marks Perch's items, so `ensure` can tell whether they are still in the menu.
    private static let tag = 0x5052_4348 // 'PRCH'

    private var model: AppModel { Shared.model }

    /// Adds the items, and adds them again if SwiftUI rebuilt the main menu.
    func install() {
        ensure()
        let center = NotificationCenter.default
        for name in [NSMenu.didBeginTrackingNotification, NSApplication.didBecomeActiveNotification,
                     NSWindow.didBecomeKeyNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppMenus.shared.ensure() }
            }
        }
    }

    func ensure() {
        guard let menu = NSApp.mainMenu else { return }
        if let edit = submenu("Edit", in: menu), edit.item(withTag: Self.tag) == nil {
            edit.insertItem(item("Undo", #selector(undo(_:)), "z"), at: 0)
            edit.insertItem(item("Redo", #selector(redo(_:)), "z", [.command, .shift]), at: 1)
            edit.insertItem(.separator(), at: 2)
            var index = (edit.items.firstIndex { $0.action == #selector(NSResponder.selectAll(_:)) } ?? edit.items.count - 1) + 1
            for new in [NSMenuItem.separator(),
                        item("Complete Todo", #selector(complete(_:)), "\r"),
                        item("Delete Todo", #selector(deleteTodo(_:)), "\u{8}"),
                        item("Move Todo Up", #selector(moveUp(_:)), key(NSUpArrowFunctionKey), [.command, .option]),
                        item("Move Todo Down", #selector(moveDown(_:)), key(NSDownArrowFunctionKey), [.command, .option]),
                        NSMenuItem.separator(),
                        item("Clear Archive…", #selector(clearArchive(_:)), "")] {
                edit.insertItem(new, at: index)
                index += 1
            }
        }
        if let window = submenu("Window", in: menu), window.item(withTag: Self.tag) == nil {
            let index = window.items.firstIndex { $0.action == #selector(NSApplication.arrangeInFront(_:)) } ?? window.items.count
            window.insertItem(item("Hide Perch", #selector(showOrHide(_:)), "0"), at: index)
            window.insertItem(.separator(), at: index + 1)
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
            item.title = model.panelVisible ? "Hide Perch" : "Show Perch"
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
