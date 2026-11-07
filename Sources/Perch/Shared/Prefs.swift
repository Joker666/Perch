#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Observation
import PerchKit

/// Everything people change in Settings, saved in UserDefaults. Test and
/// snapshot runs (APP_STORE set) read the defaults but never write them.
@Observable
final class Prefs {
    static let shared = Prefs()

    static let defaultFontSize = 14.0
    static let fontSizeRange = 11.0...18.0
    static let defaultRadius = 16.0
    static let radiusRange = 0.0...24.0

    /// The one theme, used when `themeMode` is `.one`.
    var themeID: String { didSet { save(themeID, "theme"); applyAppearance() } }
    /// One theme all the time, or Match System: `lightThemeID` and `darkThemeID` follow the system.
    var themeMode: ThemeChoice.Mode { didSet { save(themeMode.rawValue, "themeMode"); applyAppearance() } }
    var lightThemeID: String { didSet { save(lightThemeID, "themeLight"); applyAppearance() } }
    var darkThemeID: String { didSet { save(darkThemeID, "themeDark"); applyAppearance() } }
    /// Whether the system shows Dark now. Read from the system, because Perch sets
    /// its own appearance from the theme.
    var systemIsDark = SystemAppearance.isDark { didSet { applyAppearance() } }
    var font: TodoFont { didSet { save(font.rawValue, "font") } }
    var fontSize: Double { didSet { save(fontSize, "fontSize") } }
    var radius: Double { didSet { save(radius, "radius") } }
    var iconID: String { didSet { save(iconID, "icon"); AppIcons.select(iconID) } }
    /// The clicks when you add or complete a todo (`FeedbackSound`). On by default.
    /// Saved as "completionSound", its name when it covered only completing.
    var playSounds: Bool { didSet { save(playSounds, "completionSound") } }
    #if os(macOS)
    /// The Dock icon (System/AppPresence.swift). On by default.
    var showInDock: Bool { didSet { save(showInDock, "showInDock"); AppPresence.applyDockIcon() } }
    #endif

    var themeChoice: ThemeChoice {
        get { ThemeChoice(mode: themeMode, one: themeID, light: lightThemeID, dark: darkThemeID) }
        // Only changed values, so each one is saved and applied once.
        set {
            if themeMode != newValue.mode { themeMode = newValue.mode }
            if themeID != newValue.one { themeID = newValue.one }
            if lightThemeID != newValue.light { lightThemeID = newValue.light }
            if darkThemeID != newValue.dark { darkThemeID = newValue.dark }
        }
    }

    /// The theme on screen now.
    var theme: Theme { Theme.named(themeChoice.themeID(systemIsDark: systemIsDark)) }

    private init() {
        let env = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        let one = env["APP_THEME"] ?? defaults.string(forKey: "theme") ?? Theme.all[0].id
        themeID = one
        // Test runs show the one theme they set, whatever the real app chose.
        let saved = Store.isOverridden ? nil : defaults
        themeMode = ThemeChoice.Mode(rawValue: saved?.string(forKey: "themeMode") ?? "") ?? .one
        // Match System starts from the one theme in its own appearance and a fitting theme in the other.
        let current = Theme.named(one)
        lightThemeID = saved?.string(forKey: "themeLight") ?? (current.isDark ? "matcha" : current.id)
        darkThemeID = saved?.string(forKey: "themeDark") ?? (current.isDark ? current.id : "midnight")
        font = TodoFont(rawValue: defaults.string(forKey: "font") ?? "") ?? .system
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? Self.defaultFontSize
        radius = defaults.object(forKey: "radius") as? Double ?? Self.defaultRadius
        iconID = defaults.string(forKey: "icon") ?? Theme.all[0].id
        playSounds = defaults.object(forKey: "completionSound") as? Bool ?? true
        #if os(macOS)
        showInDock = defaults.object(forKey: "showInDock") as? Bool ?? true
        #endif
        SystemAppearance.observe { Prefs.shared.systemIsDark = $0 }
    }

    /// Dark themes give the app dark controls, light themes light ones. On iOS the
    /// root view sets the color scheme from `theme.colorScheme`.
    func applyAppearance() {
        #if os(macOS)
        NSApp.appearance = theme.appearance
        #endif
    }

    private func save(_ value: Any, _ key: String) {
        guard !Store.isOverridden else { return }
        UserDefaults.standard.set(value, forKey: key)
    }
}

#if os(macOS)
/// macOS Light or Dark. `NSApp.effectiveAppearance` cannot say, because Perch
/// sets its own appearance from the theme, so this reads the system setting.
enum SystemAppearance {
    static var isDark: Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        return CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString, kCFPreferencesAnyApplication) as? String == "Dark"
    }

    /// Calls `changed` when macOS switches between Light and Dark, also with Auto.
    static func observe(_ changed: @escaping @MainActor (Bool) -> Void) {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { changed(isDark) }
        }
    }
}
#else
/// iOS Light or Dark. The root view reports changes, because the app's own color
/// scheme comes from the theme.
enum SystemAppearance {
    static var isDark: Bool {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene).map(isDark(on:)) ?? false
    }

    /// The screen's style is the system's. The scene's and the windows' follow the
    /// app's own `preferredColorScheme`, so they cannot say.
    static func isDark(on scene: UIWindowScene) -> Bool {
        scene.screen.traitCollection.userInterfaceStyle == .dark
    }
    /// The root view reads the style again each time the app becomes active
    /// (iOS/Sources/RootView.swift), because the scene reports no change for a system switch.
    static func observe(_ changed: @escaping @MainActor (Bool) -> Void) {}
}
#endif
