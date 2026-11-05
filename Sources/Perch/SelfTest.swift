import AppKit
import SwiftData
import PerchKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Perch-self.store /Applications/Perch.app/Contents/MacOS/Perch --selftest
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
        panel.hide()
        panel.show()
        // S-034 the panel springs in from 98% of its size, about its center, and shrinks and fades out
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            check("Reduce Motion shows the panel without the spring", !panel.isAppearing)
        } else {
            let fitted = panel.fittedFrame()
            let start = panel.panel.frame
            check("Show starts the panel at 98% of its size, about its center",
                  panel.isAppearing && abs(start.width - fitted.width * Motion.appearScale) < 1
                      && abs(start.midX - fitted.midX) < 1 && abs(start.midY - fitted.midY) < 1,
                  "\(start) to \(fitted)")
            panel.finishAppear()
            check("The spring ends at the fitted frame", !panel.isAppearing && panel.panel.frame == fitted,
                  "\(panel.panel.frame)")
        }
        let shown = panel.panel.frame
        panel.hide()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            check("Reduce Motion hides the panel at once", !panel.panel.isVisible)
        } else {
            check("Hide starts a fade, and the panel counts as hidden at once",
                  panel.isHiding && !panel.isVisible && panel.panel.isVisible && !m.panelVisible)
            panel.show()
            check("Show during the fade brings the panel back with the spring",
                  !panel.isHiding && panel.isAppearing && panel.panel.alphaValue == 1)
            panel.finishAppear()
            panel.hide()
            panel.finishHide()
            check("The fade ends hidden, at full size and opacity for the next show",
                  !panel.panel.isVisible && panel.panel.alphaValue == 1 && panel.panel.frame == shown,
                  "\(panel.panel.frame)")
        }
        panel.show()
        panel.finishAppear()

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

        // A panel at the bottom of the screen moves up as it grows, so no row goes under the Dock
        if let visible = (panel.panel.screen ?? NSScreen.main)?.visibleFrame {
            let start = panel.panel.frame
            panel.panel.setFrameOrigin(NSPoint(x: start.minX, y: visible.minY))
            let added = (1...3).compactMap { m.add(text: "Low panel \($0)") }
            panel.fit(animated: false)
            let frame = panel.panel.frame
            check("A panel at the bottom moves up as it grows", frame.minY >= visible.minY - 0.5 && frame.height > start.height,
                  "bottom \(frame.minY), Dock top \(visible.minY)")
            m.delete(added.map(\.uuid))
            panel.panel.setFrame(start, display: false)
        }

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

        // S-031, S-033 the sounds: the panel asks for them, an agent does not
        check("The add and complete sounds are valid sounds",
              (FeedbackSound.sound(.add)?.duration ?? 0) > 0.03 && (FeedbackSound.sound(.complete)?.duration ?? 0) > 0.05)
        let adds = { FeedbackSound.requests[.add, default: 0] }
        let completes = { FeedbackSound.requests[.complete, default: 0] }
        let addsBefore = adds()
        if let quiet = m.add(text: "Sound check") {
            check("An agent's add plays no sound", adds() == addsBefore)
            let asked = completes()
            m.complete([quiet.uuid], animated: false)
            check("An agent's complete plays no sound", completes() == asked)
            m.restore([quiet.uuid])
            m.complete([quiet.uuid])
            check("Completing in the panel plays the sound", completes() == asked + 1)
            try? await Task.sleep(for: .seconds(Motion.completionSettle + 0.2))
            m.delete([quiet.uuid])
        }
        let addsAtStart = adds()
        m.add()
        m.commitEditing()
        check("An empty new row plays no sound", adds() == addsAtStart)
        m.add()
        if let id = m.editingID { m.updateText(id, "Typed in the panel") }
        m.commitEditing()
        check("Saving a new todo in the panel plays the add sound", adds() == addsAtStart + 1)
        if let typed = m.todos.first(where: { $0.text == "Typed in the panel" }) { m.delete([typed.uuid]) }

        // Many adds at one spot crowd the order values. Renumbering keeps the List in order.
        if let first = m.add(text: "Order A") {
            m.add(text: "Order B")
            var previous = first.uuid
            for i in 1...40 { previous = m.add(text: "Order \(i)", after: previous)?.uuid ?? previous }
            let expected = ["Order A"] + (1...40).map { "Order \($0)" } + ["Order B"]
            let got = m.todos.map(\.text).filter { $0.hasPrefix("Order ") }
            check("40 adds at one spot keep their order", got == expected, got.joined(separator: ", "))
            m.delete(m.todos.filter { $0.text.hasPrefix("Order ") }.map(\.uuid))
        }

        // iCloud sync (docs/ICLOUD.md). A test store never syncs, so these checks write to
        // the store directly, the way iCloud does when it merges a change from another Mac.
        check("A test store never syncs with iCloud", !Store.syncs)
        check("A test store asks for no iCloud push", m.iCloudPush == "off", m.iCloudPush)
        let store = m.container.mainContext
        if let mine = m.add(text: "Sync mine") {
            let theirs = Todo(text: "Sync theirs", order: TodoOrder.between(m.todos.last?.order, nil))
            store.insert(theirs)
            try? store.save()
            m.reload()
            undo.undo()
            check("Undo takes back only this Mac's change, not a todo from another Mac",
                  !m.todos.contains { $0.uuid == mine.uuid } && m.todos.contains { $0.uuid == theirs.uuid }, texts().joined(separator: ", "))
            m.delete([theirs.uuid])
        }
        if let typed = m.add(text: "Sync typed"), let other = m.add(text: "Sync other") {
            m.beginEditing(typed.uuid)
            other.text = "Sync other, changed elsewhere"
            try? store.save()
            m.updateText(typed.uuid, "Sync typed again")
            m.commitEditing()
            undo.undo()
            check("Undo of an edit leaves a change iCloud merged during it",
                  typed.text == "Sync typed" && other.text == "Sync other, changed elsewhere", "\(typed.text), \(other.text)")
            m.delete([typed.uuid, other.uuid])
        }
        let order = TodoOrder.between(m.todos.last?.order, nil)
        let later = Todo(text: "Tie later", order: order)
        let earlier = Todo(text: "Tie earlier", order: order)
        earlier.createdAt = later.createdAt.addingTimeInterval(-60)
        store.insert(later)
        store.insert(earlier)
        try? store.save()
        m.reload()
        let ties = texts().filter { $0.hasPrefix("Tie ") }
        check("Todos with the same order value sort by creation time", ties == ["Tie earlier", "Tie later"], ties.joined(separator: ", "))
        m.delete([earlier.uuid, later.uuid])

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
            panel.finishAppear()
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

        // The recorder in Settings > Shortcuts, fed real key events
        func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags = [], _ text: String = "") -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                             context: nil, characters: text, charactersIgnoringModifiers: text,
                             isARepeat: false, keyCode: code)!
        }
        let recorder = ShortcutRecording()
        recorder.start()
        recorder.handle(key(35, [], "p"))
        check("The recorder refuses a key with no modifier and keeps recording",
              recorder.isRecording && recorder.problem?.hasPrefix("Add ⌘, ⌥, or ⌃") == true, recorder.problem ?? "no problem")
        recorder.handle(key(45, .command, "n"))
        check("The recorder refuses ⌘N, Perch's New Todo",
              recorder.isRecording && recorder.problem == "⌘N is New Todo in Perch. Press another shortcut.",
              recorder.problem ?? "no problem")
        recorder.handle(key(53, [], "\u{1b}"))
        check("Escape stops recording and keeps the old shortcut",
              !recorder.isRecording && recorder.problem == nil && hotkey.combo == .defaultShowHide && hotkey.status == noErr)
        recorder.start()
        recorder.handle(key(51, [], "\u{7f}"))
        check("Delete stops recording and turns the shortcut off", !recorder.isRecording && hotkey.combo == nil)
        recorder.start()
        recorder.handle(key(35, [.control, .option, .command], "p"))
        check("The recorder saves a new shortcut", !recorder.isRecording && hotkey.combo == newCombo && recorder.problem == nil,
              recorder.problem ?? "")
        hotkey.change(to: .defaultShowHide)

        // S-017 themes
        check("There are 8 themes", Theme.all.count == 8)
        check("Theme ids are unique", Set(Theme.all.map(\.id)).count == Theme.all.count)

        // S-032 Match System: one theme for macOS Light, one for macOS Dark
        let prefs = Prefs.shared
        let oneTheme = prefs.theme.id
        prefs.lightThemeID = "matcha"
        prefs.darkThemeID = "navy"
        prefs.themeMode = .matchSystem
        prefs.systemIsDark = false
        check("Match System shows the Light theme when macOS is Light",
              prefs.theme.id == "matcha" && NSApp.appearance?.name == .aqua, prefs.theme.id)
        prefs.systemIsDark = true
        check("Match System switches to the Dark theme when macOS turns Dark",
              prefs.theme.id == "navy" && NSApp.appearance?.name == .darkAqua, prefs.theme.id)
        prefs.themeMode = .one
        check("One Theme ignores macOS", prefs.theme.id == oneTheme, prefs.theme.id)
        prefs.systemIsDark = SystemAppearance.isDark

        // Settings > General: the Dock icon follows the switch
        prefs.showInDock = false
        check("Show Perch in Dock off makes Perch an accessory app", NSApp.activationPolicy() == .accessory)
        prefs.showInDock = true
        check("Show Perch in Dock on brings back the Dock icon", NSApp.activationPolicy() == .regular)
        // A new Dock tile shows the bundle icon. Perch applies the picked icon again.
        let appliedBefore = AppIcons.applied
        prefs.showInDock = false
        prefs.showInDock = true
        check("The picked icon is set again when the Dock icon comes back", AppIcons.applied == appliedBefore + 1)

        // Settings fits each tab, with the top edge fixed
        let settings = SettingsWindowController.shared
        m.settingsTab = .theme
        settings.show()
        try? await Task.sleep(for: .seconds(0.5))
        if let window = settings.window, let panelFrame = PanelController.shared?.homeFrame,
           let screen = NSScreen.showing(panelFrame) {
            let expected = WindowPlacement.beside(panelFrame, size: window.frame.size, gap: SettingsWindowController.gap,
                                                  in: screen.visibleFrame)
            check("Settings opens beside the panel, top edges aligned", window.frame == expected,
                  "Settings \(window.frame), expected \(expected), panel \(panelFrame)")
        }
        if let window = settings.window, let view = window.contentViewController?.view,
           let visible = window.screen?.visibleFrame {
            window.setFrameTopLeftPoint(NSPoint(x: visible.minX + 40, y: visible.maxY - 40))
            let before = window.frame
            check("The Settings window is full width", before.width == SettingsWindowController.width, "\(before)")
            m.settingsTab = .shortcuts
            try? await Task.sleep(for: .seconds(0.5))
            let after = window.frame
            check("A taller tab grows the Settings window to fit it, top edge fixed",
                  after.height > before.height && abs(after.maxY - before.maxY) < 1
                      && abs(window.contentRect(forFrameRect: after).height - view.fittingSize.height) < 1,
                  "\(before) to \(after), fits \(view.fittingSize.height)")
            m.settingsTab = .theme
            try? await Task.sleep(for: .seconds(0.5))
            check("A shorter tab shrinks it back", window.frame == before, "\(window.frame)")
            window.close()
        } else {
            check("Settings opens", false)
        }
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
