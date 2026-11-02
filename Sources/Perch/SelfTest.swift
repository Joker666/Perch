import AppKit
import SwiftData
import PerchKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Perch-self.store ~/Applications/Perch.app/Contents/MacOS/Perch --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            await run(model)
            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func run(_ m: AppModel) async {
        let texts = { m.todos.map(\.text) }
        let undo = m.undoManager
        // The whole test runs in one run loop pass, so each step groups its own undo.
        undo.groupsByEvent = false
        let panel = PanelController.shared!
        panel.show()

        // S-002 add from a filler row, S-007 saved
        m.add()
        check("Add starts typing in a new row", m.editingID != nil && m.todos.count == 1)
        m.commitEditing()
        check("An empty new row is not saved", m.todos.isEmpty)
        check("An empty new row leaves no undo step", !undo.canUndo)

        m.add()
        m.updateText(m.editingID!, "  Buy   milk ")
        m.commitEditing()
        check("A typed row is saved with clean text", texts() == ["Buy milk"])
        check("Undo names the add", undo.undoActionName == "Add Todo")

        // S-003 Return inserts below
        m.add()
        m.updateText(m.editingID!, "Call Anna")
        m.commitEditing()
        let first = m.todos[0].uuid
        m.add(after: first)
        m.updateText(m.editingID!, "Between")
        m.commitEditing()
        check("Return inserts the new row right below", texts() == ["Buy milk", "Between", "Call Anna"])

        // S-004 edit, empty means delete
        m.beginEditing(m.todos[1].uuid)
        m.updateText(m.todos[1].uuid, "")
        m.commitEditing()
        check("Clearing a row's text deletes it", texts() == ["Buy milk", "Call Anna"])
        undo.undo()
        check("Undo brings the cleared row back", texts() == ["Buy milk", "Between", "Call Anna"])

        // S-006 the panel height fits the rows
        let metrics = PanelMetrics(fontSize: Prefs.shared.fontSize)
        try? await Task.sleep(for: .seconds(0.5))
        check("Panel height fits todos plus fillers",
              abs(panel.panel.frame.height - metrics.height(rows: m.todos.count + PanelMetrics.fillerCount)) < 1,
              "height \(panel.panel.frame.height)")

        // S-008, S-009 selection
        m.focus = .none
        m.moveCursor(step: 1)
        check("Down with nothing selected types in the first row", m.editingID == m.todos[0].uuid)
        m.extendSelection(step: 1)
        check("Shift-Down selects two rows", m.selectedIDs.count == 2)
        m.extendSelection(step: 1)
        check("Shift-Down again selects three rows", m.selectedIDs.count == 3)
        m.moveCursor(step: -1)
        check("Up collapses the selection to one typing row", m.editingID == m.todos[1].uuid)

        // S-010 delete and undo
        m.focus = .selection(ListSelection(anchor: m.todos[0].uuid, cursor: m.todos[1].uuid))
        m.deleteSelected()
        check("Delete removes the selected rows", texts() == ["Call Anna"])
        undo.undo()
        check("Undo puts deleted rows back in place", texts() == ["Buy milk", "Between", "Call Anna"])

        // S-013 move with the keyboard, S-012 move by drag
        m.focus = .selection(ListSelection(m.todos[0].uuid))
        m.moveSelected(by: 1)
        check("Move Down moves the row one place", texts() == ["Between", "Buy milk", "Call Anna"])
        m.move([m.todos[2].uuid], to: 0)
        check("A drop moves the row to the top", texts() == ["Call Anna", "Between", "Buy milk"])

        // S-005 complete, S-014 archive
        let done = m.todos[1].uuid
        m.complete([done])
        check("A completing row stays until its animation ends", m.todos.contains { $0.uuid == done })
        try? await Task.sleep(for: .seconds(Motion.completionSettle + 0.3))
        check("A completed todo leaves the list", texts() == ["Call Anna", "Buy milk"])
        check("A completed todo is in the Archive", m.archived.first?.uuid == done)
        undo.undo()
        check("Undo un-completes it", texts() == ["Call Anna", "Between", "Buy milk"])
        undo.redo()
        check("Redo completes it again", m.archived.count == 1)

        // S-015 restore
        m.restore([done])
        check("Restore moves the todo to the end of the list", texts().last == "Between" && m.archived.isEmpty)

        // S-016 clear the Archive
        m.complete(m.todos.map(\.uuid))
        try? await Task.sleep(for: .seconds(Motion.completionSettle + 0.3))
        check("Completing every todo empties the list", m.todos.isEmpty && m.archived.count == 3)
        m.clearArchive()
        check("Clear Archive deletes every completed todo", m.archived.isEmpty)
        undo.undo()
        check("Undo brings the Archive back", m.archived.count == 3)

        // S-007 todos survive a new context, as after a restart
        let fresh = ModelContext(m.container)
        let saved = (try? fresh.fetchCount(FetchDescriptor<Todo>())) ?? 0
        check("Todos are saved to the store", saved == 3)

        // Agent CLI entry points: one undo step each, the same code as the window
        let added = m.add(text: "  From   an agent ")
        check("add(text:) saves clean text in one step", added?.text == "From an agent" && m.editingID == nil)
        check("add(text:) leaves one undo step", undo.undoActionName == "Add Todo")
        check("add(text:) refuses empty text", m.add(text: "   ") == nil)
        if let added {
            check("rename changes the text", m.rename(added.uuid, to: "Renamed") && added.text == "Renamed")
            check("rename to the same text changes nothing", !m.rename(added.uuid, to: "Renamed"))
            m.complete([added.uuid], animated: false)
            check("complete without animation finishes at once", m.archived.contains { $0.uuid == added.uuid })
            undo.undo()
            check("Undo takes back an instant complete", m.todos.contains { $0.uuid == added.uuid })
            m.delete([added.uuid])
        }

        // Edit and Window menu items follow the model (AppKit validation, System/AppMenus.swift)
        AppMenus.shared.ensure()
        func menuItem(_ menu: String, _ action: Selector) -> NSMenuItem? {
            NSApp.mainMenu?.items.first { $0.submenu?.title == menu }?.submenu?.items.first { $0.action == action }
        }
        if let undoItem = menuItem("Edit", #selector(AppMenus.undo(_:))) {
            let temp = m.add(text: "Menu check")
            let enabled = AppMenus.shared.validateMenuItem(undoItem)
            check("Edit > Undo names the last change", enabled && undoItem.title == "Undo Add Todo", undoItem.title)
            if let temp { m.delete([temp.uuid]) }
        } else {
            check("Edit > Undo is in the menu", false)
        }
        if let toggle = menuItem("Window", #selector(AppMenus.showOrHide(_:))) {
            panel.hide()
            _ = AppMenus.shared.validateMenuItem(toggle)
            let hiddenTitle = toggle.title
            panel.show()
            _ = AppMenus.shared.validateMenuItem(toggle)
            check("Window menu says Show Perch, then Hide Perch", hiddenTitle == "Show Perch" && toggle.title == "Hide Perch",
                  "\(hiddenTitle), \(toggle.title)")
        } else {
            check("Show or Hide Perch is in the Window menu", false)
        }
        // The first shortcut after the app becomes active meets an Edit menu that SwiftUI is rebuilding
        if let edit = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "Edit" })?.submenu,
           let commandZ = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                           windowNumber: 0, context: nil, characters: "z",
                                           charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6) {
            let temp = m.add(text: "Shortcut check")
            for item in edit.items where item.target === AppMenus.shared { edit.removeItem(item) }
            let handled = AppMenus.shared.performKeyEquivalent(commandZ)
            check("⌘Z undoes while the Edit menu has no Undo item", handled && !m.todos.contains { $0.uuid == temp?.uuid })
            AppMenus.shared.ensure()
        }

        // S-028 change the global shortcut
        let hotkey = Hotkey.shared
        check("The global shortcut starts as ⌃⌥Space", hotkey.combo == .defaultShowHide && hotkey.status == noErr,
              "status \(hotkey.status)")
        check("The shortcut shows as ⌃⌥Space", KeyNames.display(.defaultShowHide) == "⌃⌥Space")
        let newCombo = KeyCombo(keyCode: 35, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command) // ⌃⌥⌘P
        check("A new shortcut registers", hotkey.change(to: newCombo) == noErr && hotkey.combo == newCombo)
        check("Its name comes from the keyboard layout", KeyNames.display(newCombo) == "⌃⌥⌘P", KeyNames.display(newCombo))
        let newTodo = KeyCombo(keyCode: 45, modifiers: KeyCombo.command) // ⌘N
        check("⌘N is refused as Perch's own New Todo", hotkey.menuConflict(newTodo) == "New Todo",
              hotkey.menuConflict(newTodo) ?? "no conflict found")
        check("A shortcut with no modifier is refused", !KeyCombo(keyCode: 35, modifiers: 0).isAllowedGlobally)
        check("The shortcut can be turned off", hotkey.change(to: nil) == noErr && hotkey.combo == nil)
        hotkey.change(to: .defaultShowHide)
        check("Reset brings back ⌃⌥Space", hotkey.combo == .defaultShowHide && hotkey.status == noErr)

        // S-017 themes
        check("There are 8 themes", Theme.all.count == 8)
        check("Theme ids are unique", Set(Theme.all.map(\.id)).count == Theme.all.count)
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
