import AppKit
import Carbon.HIToolbox
import Observation
import PerchKit

/// The global shortcut that shows and hides the panel. Control-Option-Space
/// by default. People record another one in Settings > Shortcuts.
/// Carbon hot keys need no permission, and the key never reaches the front app.
@MainActor
@Observable
final class Hotkey {
    static let shared = Hotkey()

    /// The saved shortcut, or nil when people turned it off.
    private(set) var combo: KeyCombo?
    /// Non-zero when another app owns the combination. Settings > Shortcuts shows it.
    private(set) var status: OSStatus = noErr

    @ObservationIgnored private var ref: EventHotKeyRef?
    @ObservationIgnored private var action: (() -> Void)?
    @ObservationIgnored private var handlerInstalled = false

    private static let savedKey = "hotkey"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.savedKey) {
            combo = try? JSONDecoder().decode(KeyCombo?.self, from: data)
        } else {
            combo = .defaultShowHide
        }
    }

    /// Installs the event handler once and registers the saved shortcut.
    func start(_ perform: @escaping () -> Void) {
        action = perform
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                Task { @MainActor in Hotkey.shared.action?() }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        register()
    }

    /// Changes the shortcut. When the system refuses it, the old one comes
    /// back and the result says why. nil turns the shortcut off.
    @discardableResult
    func change(to new: KeyCombo?) -> OSStatus {
        let old = combo
        combo = new
        register()
        guard status == noErr else {
            let refused = status
            combo = old
            register()
            return refused
        }
        save()
        return noErr
    }

    /// While a new shortcut is being recorded, the old one must not fire.
    func pause() {
        unregister()
    }

    func resume() {
        register()
    }

    /// The menu item that already uses `combo` in Perch, if any. A global
    /// shortcut on top of it would make that menu item unreachable.
    func menuConflict(_ combo: KeyCombo) -> String? {
        guard let menu = NSApp.mainMenu else { return nil }
        return Self.find(combo, in: menu)
    }

    // MARK: Private

    private func register() {
        unregister()
        guard let combo else {
            status = noErr
            return
        }
        let id = EventHotKeyID(signature: OSType(0x5052_4348), id: 1) // 'PRCH'
        status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { ref = nil }
    }

    private func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    private func save() {
        guard !Store.isOverridden, let data = try? JSONEncoder().encode(combo) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedKey)
    }

    private static func find(_ combo: KeyCombo, in menu: NSMenu) -> String? {
        for item in menu.items {
            if let submenu = item.submenu, let found = find(combo, in: submenu) { return found }
            guard !item.keyEquivalent.isEmpty, KeyNames.matches(combo, item: item) else { continue }
            return item.title
        }
        return nil
    }
}

/// Names for keys and shortcuts, from the current keyboard layout.
@MainActor
enum KeyNames {
    /// "⌃⌥Space", "⌘⇧K", or "F5".
    static func display(_ combo: KeyCombo) -> String {
        combo.modifierSymbols + key(combo.keyCode)
    }

    static func key(_ keyCode: UInt32) -> String {
        KeyCombo.specialName(keyCode) ?? layoutCharacter(UInt16(keyCode))?.uppercased() ?? "Key \(keyCode)"
    }

    /// A combination from a key press.
    static func combo(from event: NSEvent) -> KeyCombo {
        let flags = event.modifierFlags
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= KeyCombo.command }
        if flags.contains(.shift) { modifiers |= KeyCombo.shift }
        if flags.contains(.option) { modifiers |= KeyCombo.option }
        if flags.contains(.control) { modifiers |= KeyCombo.control }
        return KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    /// True when a menu item's key equivalent is the same keys as `combo`.
    static func matches(_ combo: KeyCombo, item: NSMenuItem) -> Bool {
        var equivalent = item.keyEquivalent
        var mask = item.keyEquivalentModifierMask
        // An uppercase letter as the key equivalent means Shift.
        if equivalent.count == 1, equivalent != equivalent.lowercased() {
            mask.insert(.shift)
            equivalent = equivalent.lowercased()
        }
        var modifiers: UInt32 = 0
        if mask.contains(.command) { modifiers |= KeyCombo.command }
        if mask.contains(.shift) { modifiers |= KeyCombo.shift }
        if mask.contains(.option) { modifiers |= KeyCombo.option }
        if mask.contains(.control) { modifiers |= KeyCombo.control }
        guard modifiers == combo.modifiers else { return false }
        let special: [UInt32: String] = [
            36: "\r", 48: "\t", 49: " ", 51: "\u{8}", 53: "\u{1b}", 117: "\u{7f}",
            123: String(UnicodeScalar(NSLeftArrowFunctionKey)!), 124: String(UnicodeScalar(NSRightArrowFunctionKey)!),
            125: String(UnicodeScalar(NSDownArrowFunctionKey)!), 126: String(UnicodeScalar(NSUpArrowFunctionKey)!),
        ]
        if let name = special[combo.keyCode] { return equivalent == name }
        return layoutCharacter(UInt16(combo.keyCode))?.lowercased() == equivalent
    }

    /// The character a key types with no modifiers on the current layout.
    private static func layoutCharacter(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeys: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let result = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            guard result == noErr, length > 0 else { return nil }
            let text = String(utf16CodeUnits: chars, count: length)
            return text.trimmingCharacters(in: .controlCharacters).isEmpty ? nil : text
        }
    }
}
