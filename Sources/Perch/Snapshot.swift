import AppKit
import IOKit.pwr_mgt
import SwiftUI
import PerchKit

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots /Applications/Perch.app/Contents/MacOS/Perch
/// writes <page>-<theme>.png for every panel state and settings-<tab>-<theme>.png
/// for every Settings tab, in a dark theme and a light theme, then quits.
/// Each PNG gets a <page>-<theme>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=panel,archive limits the pages. Add "settings" to include Settings.
/// APP_SNAPSHOT_THEMES=midnight,pool picks the themes.
@MainActor
enum Snapshot {
    static var requested: Bool { !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty }

    /// The panel states. Each sets up the model, then the panel is captured.
    static let pages: [(name: String, setUp: (AppModel) -> Void)] = [
        ("panel", { m in m.mode = .list; m.focus = .none }),
        ("panel-editing", { m in m.mode = .list; m.focus = .none; m.beginEditing(m.todos[1].uuid) }),
        ("panel-selection", { m in
            m.mode = .list
            m.commitEditing()
            m.focus = .selection(ListSelection(anchor: m.todos[1].uuid, cursor: m.todos[2].uuid))
        }),
        ("archive", { m in m.commitEditing(); m.mode = .archive }),
    ]

    static func run(model: AppModel) {
        let env = ProcessInfo.processInfo.environment
        let dir = env["APP_SNAPSHOT"] ?? "/tmp/Perch-shots"
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        let themes = (env["APP_SNAPSHOT_THEMES"] ?? "midnight,matcha").split(separator: ",").map(String.init)
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it, and the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let panel = PanelController.shared!
            panel.show()
            try? await Task.sleep(for: .seconds(1.2))
            for theme in themes {
                Prefs.shared.themeID = theme
                for page in pages where only?.contains(page.name) ?? true {
                    page.setUp(model)
                    try? await Task.sleep(for: .seconds(0.9))
                    capture(to: "\(dir)/\(page.name)-\(theme).png", window: panel.panel)
                }
            }
            if only == nil || only?.contains("settings") == true {
                model.commitEditing()
                model.mode = .list
                SettingsWindowController.shared.show()
                try? await Task.sleep(for: .seconds(1))
                for theme in themes {
                    Prefs.shared.themeID = theme
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(theme).png", window: SettingsWindowController.shared.window)
                    }
                    // Match System, with macOS in the appearance of this run's theme.
                    let prefs = Prefs.shared
                    prefs.lightThemeID = "matcha"
                    prefs.darkThemeID = "midnight"
                    prefs.systemIsDark = Theme.named(theme).isDark
                    prefs.themeMode = .matchSystem
                    model.settingsTab = .theme
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/settings-theme-system-\(theme).png", window: SettingsWindowController.shared.window)
                    prefs.themeMode = .one
                }
            }
            print("SNAPSHOT done \(dir)")
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, which needs Screen Recording
    /// permission for the app that started this one. Without it, draws the view hierarchy.
    private static func capture(to path: String, window: NSWindow?) {
        // Another app can hide this one while snapshots run. Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window else {
            print("SNAPSHOT no window")
            return
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission)")
        }
    }
}
