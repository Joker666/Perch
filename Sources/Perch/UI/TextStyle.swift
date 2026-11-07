import SwiftUI

/// Text styles for the Mac windows. Views use these, never a literal font
/// size. The panel's todo text is the one exception: its size is a setting.
enum TextStyle {
    /// A control's label in Settings.
    static let label = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13)
    /// A value beside a slider, such as "14 pt".
    static let value = Font.system(size: 13).monospacedDigit()
    /// A key or shortcut in a keycap.
    static let keycap = Font.system(size: 12, weight: .medium).monospacedDigit()
    static let footnote = Font.system(size: 12)
    /// A help line under a control.
    static let caption = Font.system(size: 11)
    /// The app's name in About.
    static let title = Font.system(size: 20, weight: .semibold)
    /// The symbol on a Settings tab.
    static let tabIcon = Font.system(size: 15)
}
