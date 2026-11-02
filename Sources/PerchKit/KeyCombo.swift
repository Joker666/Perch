import Foundation

/// A key and its modifiers, as the Carbon hot key API wants them. The global
/// shortcut that shows and hides Perch is one of these.
public struct KeyCombo: Equatable, Codable, Sendable {
    /// A virtual key code, like 49 for Space.
    public var keyCode: UInt32
    /// Carbon modifier flags: `command`, `shift`, `option`, `control`.
    public var modifiers: UInt32

    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    /// Control-Option-Space.
    public static let defaultShowHide = KeyCombo(keyCode: 49, modifiers: control | option)

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers & (Self.command | Self.shift | Self.option | Self.control)
    }

    /// The modifiers in Apple's order: ⌃⌥⇧⌘.
    public var modifierSymbols: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "⌃" }
        if modifiers & Self.option != 0 { text += "⌥" }
        if modifiers & Self.shift != 0 { text += "⇧" }
        if modifiers & Self.command != 0 { text += "⌘" }
        return text
    }

    /// A global shortcut needs ⌘, ⌥, or ⌃, or it would take keys away from
    /// every app. Function keys are the exception.
    public var isAllowedGlobally: Bool {
        Self.isFunctionKey(keyCode) || modifiers & (Self.command | Self.option | Self.control) != 0
    }

    /// The name of a key that does not type a character, like "Space" or "↩".
    /// nil for keys whose name comes from the keyboard layout (letters, digits).
    public static func specialName(_ keyCode: UInt32) -> String? {
        if let index = functionKeys.firstIndex(of: keyCode) { return "F\(index + 1)" }
        return specialNames[keyCode]
    }

    /// True when a menu item with this key equivalent and these Carbon modifiers is
    /// the same keys. An uppercase key equivalent means Shift. `layoutCharacter` is
    /// what this key types on the current keyboard layout.
    public func matches(keyEquivalent: String, modifiers: UInt32, layoutCharacter: @autoclosure () -> String?) -> Bool {
        var equivalent = keyEquivalent
        var itemModifiers = modifiers
        if equivalent.count == 1, equivalent != equivalent.lowercased() {
            itemModifiers |= Self.shift
            equivalent = equivalent.lowercased()
        }
        guard itemModifiers == self.modifiers else { return false }
        if let special = Self.keyEquivalents[keyCode] { return equivalent == special }
        return layoutCharacter()?.lowercased() == equivalent
    }

    public static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeys.contains(keyCode)
    }

    /// F1 to F20, in order.
    private static let functionKeys: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109,
                                                 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    /// How a menu item writes keys that type no letter: Return, Tab, Space,
    /// Delete, Escape, Forward Delete, and the arrows (AppKit's function key characters).
    private static let keyEquivalents: [UInt32: String] = [
        36: "\r", 48: "\t", 49: " ", 51: "\u{8}", 53: "\u{1b}", 117: "\u{7f}",
        123: "\u{F702}", 124: "\u{F703}", 125: "\u{F701}", 126: "\u{F700}",
    ]

    private static let specialNames: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 117: "⌦",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
