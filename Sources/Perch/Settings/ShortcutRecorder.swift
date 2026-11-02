import AppKit
import Observation
import SwiftUI
import PerchKit

/// Records a new global shortcut. While it records, the old shortcut is
/// paused so pressing it records it instead of hiding the panel.
/// Escape cancels, Delete turns the shortcut off.
@MainActor
@Observable
final class ShortcutRecording {
    private(set) var isRecording = false
    /// Why the last key press was refused, in sentence case. nil when it worked.
    private(set) var problem: String?

    @ObservationIgnored private var monitor: Any?

    func start() {
        guard !isRecording else { return }
        problem = nil
        isRecording = true
        Hotkey.shared.pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.handle(event)
            return nil
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        Hotkey.shared.resume()
    }

    func reset() {
        stop()
        problem = nil
        Hotkey.shared.change(to: .defaultShowHide)
    }

    private func handle(_ event: NSEvent) {
        let combo = KeyNames.combo(from: event)
        switch (combo.keyCode, combo.modifiers) {
        case (53, 0):
            problem = nil
            stop()
            return
        case (51, 0), (117, 0):
            problem = nil
            stop()
            Hotkey.shared.change(to: nil)
            return
        default:
            break
        }
        let name = KeyNames.display(combo)
        guard combo.isAllowedGlobally else {
            problem = "Add ⌘, ⌥, or ⌃ to \(name), so it does not take the key from other apps."
            return
        }
        if let item = Hotkey.shared.menuConflict(combo) {
            problem = "\(name) is \(item) in Perch. Press another shortcut."
            return
        }
        stop()
        problem = Hotkey.shared.change(to: combo) == noErr ? nil : "Another app uses \(name). Press another shortcut."
    }
}

/// The field in Settings > Shortcuts that shows the global shortcut and records a new one.
struct ShortcutRecorder: View {
    let recording: ShortcutRecording
    private var hotkey: Hotkey { Hotkey.shared }

    var body: some View {
        HStack(spacing: Space.sm) {
            Button {
                if recording.isRecording { recording.stop() } else { recording.start() }
            } label: {
                Text(label)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(recording.isRecording || hotkey.combo == nil ? Palette.secondaryText : Palette.text)
                    .frame(minWidth: 96)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .background {
                        RoundedRectangle(cornerRadius: PanelStyle.keycapRadius, style: .continuous)
                            .fill(recording.isRecording ? Palette.highlight : Palette.control)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: PanelStyle.keycapRadius, style: .continuous)
                            .strokeBorder(Palette.text.opacity(recording.isRecording ? 0.5 : 0), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(recording.isRecording
                  ? "Press the new shortcut. Escape cancels, Delete turns it off."
                  : "Click, then press a new shortcut for showing and hiding Perch")
            .accessibilityLabel("Show or hide Perch shortcut")
            .accessibilityValue(label)

            Button("Reset") { recording.reset() }
                .controlSize(.small)
                .disabled(hotkey.combo == .defaultShowHide && !recording.isRecording)
        }
        .onDisappear { recording.stop() }
    }

    private var label: String {
        if recording.isRecording { return "Press a shortcut" }
        return hotkey.combo.map(KeyNames.display) ?? "Off"
    }
}

/// The help line under the recorder.
struct ShortcutCaption: View {
    let recording: ShortcutRecording

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var text: String {
        // A refusal comes first: recording goes on after one, and the reason must show.
        if let problem = recording.problem { return problem }
        if recording.isRecording { return "Press the new shortcut. Escape cancels, Delete turns it off." }
        if Hotkey.shared.status != noErr { return "Another app uses this shortcut. Click it and press another one." }
        if Hotkey.shared.combo == nil { return "Off. Click it and press a shortcut to show Perch from any app." }
        return "Works from any app. Opens a new todo, ready to type."
    }
}
