import CoreGraphics

/// Fixed sizes of the Settings window's parts. Views use these, never literal
/// numbers. Spacing comes from `Space`, text from `TextStyle`.
enum SettingsStyle {
    /// The label column in Settings > Theme, so every control starts on one edge.
    static let labelWidth: CGFloat = 100
    /// The value beside a slider, such as "14 pt".
    static let valueWidth: CGFloat = 44
    /// One theme swatch, and the dot on the chosen one.
    static let swatch: CGFloat = 24
    static let swatchDot: CGFloat = 8
    /// A row in Settings > Icon, its icon, and where its divider starts.
    static let iconRow: CGFloat = 52
    static let iconSize: CGFloat = 40
    static let iconDividerInset: CGFloat = 84
    static let listRadius: CGFloat = 12
    /// The icon in About.
    static let aboutIcon: CGFloat = 96
    /// A tab in the bar at the top, its symbol's height, and its highlight's radius.
    static let tabSize = CGSize(width: 72, height: 44)
    static let tabIconHeight: CGFloat = 20
    static let tabRadius: CGFloat = 8
    /// The shortcut recorder never gets narrower than its longest usual shortcut.
    static let recorderMinWidth: CGFloat = 96
}
