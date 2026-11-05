import AppKit
import ServiceManagement

/// Settings > General: whether Perch opens at login and shows in the Dock.
/// Without the Dock icon, Perch is an accessory app. The menu bar icon and the
/// global shortcut still show the panel.
@MainActor
enum AppPresence {
    /// Shows or hides the Dock icon. Test runs change it too, so the self-test can check it.
    static func applyDockIcon() {
        NSApp.setActivationPolicy(Prefs.shared.showInDock ? .regular : .accessory)
        // A new Dock tile shows the bundle icon, not the one picked in Settings.
        if Prefs.shared.showInDock { AppIcons.apply(Prefs.shared.iconID) }
        // An app that leaves the Dock also loses focus. Keep Settings in front.
        if let window = SettingsWindowController.shared.window, window.isVisible {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// True when macOS opens Perch at login. macOS keeps this, not Perch.
    static var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// True when the person must allow the login item in System Settings first.
    static var loginNeedsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// Adds or removes the login item. Test runs never change it.
    static func setOpensAtLogin(_ on: Bool) throws {
        guard !Store.isOverridden else { return }
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
