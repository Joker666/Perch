import AppKit
import SwiftData
import SwiftUI

// Perch
//   Perch                      the app
//   APP_STORE=<file> Perch     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> Perch   save a PNG of every panel state and Settings tab in two themes, then quit
//   APP_SEED=1 Perch           fill an empty /tmp store with sample todos (tools/snap.sh)
//   Perch --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_THEME=<id> Perch       run with another theme from Theme.all (UI/Theme.swift)
//   APP_GRID=1 Perch           draw grid lines every 8 pt and the layout probes over the window

/// The one model the panel, menus, and Settings share.
@MainActor
enum Shared {
    static let model = AppModel(container: Store.makeContainer())
}

struct PerchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private var model: AppModel { Shared.model }

    /// The menu bar icon at 16 pt, the size of other menu bar icons (`systemImage:` draws
    /// about 11 pt). A template image follows the menu bar's color.
    private static let menuBarIcon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "checkmark.square.fill", accessibilityDescription: "Perch")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = true
        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu()
                .environment(model)
        } label: {
            Image(nsImage: Self.menuBarIcon)
                .accessibilityLabel("Perch")
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Updates.check() }
                    .disabled(!Updates.isAvailable)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { SettingsWindowController.shared.show() }
                    .keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button("New Todo") { PanelController.shared.show(); model.add() }
                    .keyboardShortcut("n")
            }
            // Undo, Redo, the todo commands, and Show or Hide Perch are in System/AppMenus.swift.
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(before: .toolbar) {
                Button("List") { model.mode = .list }
                    .keyboardShortcut("1")
                Button("Archive") { model.mode = .archive }
                    .keyboardShortcut("2")
                Divider()
            }
        }
    }
}

/// Clearing deletes every completed todo, so it asks first. Undo still works.
@MainActor
func confirmClearArchive(_ model: AppModel) {
    let count = model.archived.count
    let alert = NSAlert()
    alert.messageText = count == 1 ? "Delete 1 Completed Todo?" : "Delete \(count) Completed Todos?"
    alert.informativeText = "You can undo this with Command-Z."
    alert.addButton(withTitle: "Delete").hasDestructiveAction = true
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn { model.clearArchive() }
}

/// The menu under the checkmark in the menu bar.
private struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(model.showHideTitle) { PanelController.shared.toggle() }
        Button("New Todo") { PanelController.shared.newTodo() }
        Divider()
        Button("Settings…") { SettingsWindowController.shared.show() }
        Divider()
        Button("Quit Perch") { NSApp.terminate(nil) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        NSApp.setActivationPolicy(.regular)
        let model = Shared.model
        Prefs.shared.applyAppearance()
        AppIcons.apply(Prefs.shared.iconID)
        SeedData.insertIfRequested(into: model)
        SettingsWindowController.shared.model = model
        let panel = PanelController(model: model)
        self.panel = panel
        Hotkey.shared.start { PanelController.shared.quickAdd() }
        // After SwiftUI has built the main menu.
        DispatchQueue.main.async { AppMenus.shared.install() }
        // The agent CLI and MCP server reach the app through this socket (Agent/).
        AgentRouter.model = model
        AgentSocket.listen { AgentRouter.handle($0) }
        Updates.start()

        if SelfTest.requested {
            SelfTest.runIfRequested(model: model)
        } else if Snapshot.requested {
            Snapshot.run(model: model)
        } else {
            panel.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Clicking the Dock icon brings the panel back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()
        return false
    }

    /// Saves a row that is still being typed in. The self-test's result becomes the exit code.
    func applicationWillTerminate(_ notification: Notification) {
        Shared.model.commitEditing()
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Where the data lives: ~/Library/Application Support/Perch/Perch.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "Perch", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Perch.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Todo.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
