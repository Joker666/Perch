import AppKit
import SwiftUI

/// The text field inside a row while it is being typed in. An AppKit field,
/// because the panel's keys (Return, Up, Down, Backspace in an empty row)
/// must reach the model before the field editor acts on them.
struct RowTextField: NSViewRepresentable {
    enum Command {
        case submit, cancel, up, down, extendUp, extendDown, backspaceEmpty
    }

    @Binding var text: String
    var font: NSFont
    var color: NSColor
    var onCommand: (Command) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusingTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = context.coordinator
        field.setAccessibilityLabel("Todo")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text, field.currentEditor() == nil || field.stringValue.isEmpty {
            field.stringValue = text
        }
        field.font = font
        field.textColor = color
        if let editor = field.currentEditor() as? NSTextView {
            editor.insertionPointColor = color
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RowTextField

        init(parent: RowTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let command: Command? = switch selector {
            case #selector(NSResponder.insertNewline(_:)): .submit
            case #selector(NSResponder.cancelOperation(_:)): .cancel
            case #selector(NSResponder.moveUp(_:)): .up
            case #selector(NSResponder.moveDown(_:)): .down
            case #selector(NSResponder.moveUpAndModifySelection(_:)): .extendUp
            case #selector(NSResponder.moveDownAndModifySelection(_:)): .extendDown
            case #selector(NSResponder.deleteBackward(_:)) where textView.string.isEmpty: .backspaceEmpty
            default: nil
            }
            guard let command else { return false }
            parent.text = textView.string
            parent.onCommand(command)
            return true
        }
    }
}

/// Takes the keyboard as soon as it is in a window, with the caret at the end.
private final class FocusingTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
            if let editor = self.currentEditor() {
                editor.selectedRange = NSRange(location: (editor.string as NSString).length, length: 0)
            }
        }
    }
}
