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
        // A regular app with a Dock icon, unless Settings > General turned it off.
        // Started from a terminal, the process is not a foreground app until this.
        AppPresence.applyDockIcon()
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
        // iCloud tells the app about changes from other Macs with a silent push.
        if Store.syncs {
            model.iCloudPush = "waiting"
            NSApp.registerForRemoteNotifications()
            model.reloadOnSync()
        }

        if SelfTest.requested {
            SelfTest.runIfRequested(model: model)
        } else if Snapshot.requested {
            Snapshot.run(model: model)
        } else {
            panel.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The Dock can make a new tile while Perch runs (a new build, a Dock restart),
    /// which shows the bundle icon again. Applying it on each activation fixes that.
    func applicationDidBecomeActive(_ notification: Notification) {
        AppIcons.apply(Prefs.shared.iconID)
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Shared.model.iCloudPush = "on"
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Shared.model.iCloudPush = "failed: \(error.localizedDescription)"
    }

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

