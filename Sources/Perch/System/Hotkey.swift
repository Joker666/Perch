import Carbon.HIToolbox
import Foundation

/// The global shortcut that shows and hides the panel: Control-Option-Space.
/// Carbon hot keys need no permission, and the key never reaches the front app.
@MainActor
enum Hotkey {
    static let display = "⌃⌥Space"
    /// Non-zero when another app owns the combination. Settings > Shortcuts shows it.
    private(set) static var status: OSStatus = noErr
    private static var ref: EventHotKeyRef?
    private static var action: (() -> Void)?

    static func register(_ perform: @escaping () -> Void) {
        action = perform
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in Hotkey.action?() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x5052_4348), id: 1) // 'PRCH'
        status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), id,
                                     GetApplicationEventTarget(), 0, &ref)
    }
}
