import Foundation

/// Which theme Perch shows: one theme all the time, or one theme for macOS
/// Light and one for macOS Dark. Values are theme ids.
public struct ThemeChoice: Equatable, Sendable {
    public enum Mode: String, CaseIterable, Sendable {
        case one
        case matchSystem
    }

    public enum Appearance: String, CaseIterable, Sendable {
        case light, dark
    }

    public var mode: Mode
    public var one: String
    public var light: String
    public var dark: String

    public init(mode: Mode, one: String, light: String, dark: String) {
        self.mode = mode
        self.one = one
        self.light = light
        self.dark = dark
    }

    /// The theme to show now.
    public func themeID(systemIsDark: Bool) -> String {
        switch mode {
        case .one: one
        case .matchSystem: systemIsDark ? dark : light
        }
    }

    /// Sets the theme for `appearance`. With nil it sets the theme on screen
    /// now: the one theme, or with Match System the one for the current macOS appearance.
    public mutating func set(_ id: String, for appearance: Appearance?, systemIsDark: Bool) {
        switch appearance ?? (mode == .one ? nil : systemIsDark ? .dark : .light) {
        case .light: light = id
        case .dark: dark = id
        case nil: one = id
        }
    }
}
