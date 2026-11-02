import SwiftUI
import DoFloatyKit

/// One todo: a circle and one line of text. Typing happens in place.
struct TodoRow: View {
    @Environment(AppModel.self) private var model
    let todo: Todo
    let metrics: PanelMetrics
    var isDragging = false

    @State private var hovering = false
    private var prefs: Prefs { Prefs.shared }

    private var isEditing: Bool { model.editingID == todo.uuid }
    private var isSelected: Bool { isDragging || model.selectedIDs.contains(todo.uuid) }
    private var isCompleting: Bool { model.completing.contains(todo.uuid) }
    private var isChecked: Bool { todo.isCompleted || isCompleting }

    var body: some View {
        HStack(spacing: PanelStyle.textInset) {
            CheckCircle(checked: isChecked, size: metrics.circleSize) {
                if todo.isCompleted { model.restore([todo.uuid]) } else { model.complete([todo.uuid]) }
            }
            label
        }
        .padding(.horizontal, PanelStyle.rowInset)
        .frame(height: metrics.rowHeight)
        .background { highlight }
        .contentShape(Rectangle())
        .onHover { inside in withAnimation(Motion.hover) { hovering = inside } }
        .contextMenu { menu }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(todo.text)
        .accessibilityValue(todo.isCompleted ? "Completed" : "")
        .accessibilityAction(named: todo.isCompleted ? "Restore" : "Complete") {
            if todo.isCompleted { model.restore([todo.uuid]) } else { model.complete([todo.uuid]) }
        }
    }

    @ViewBuilder
    private var label: some View {
        if isEditing {
            RowTextField(
                text: Binding(get: { todo.text }, set: { model.updateText(todo.uuid, $0) }),
                font: prefs.font.nsFont(size: prefs.fontSize),
                color: NSColor(hex: prefs.theme.text),
                onCommand: handle
            )
            .frame(maxWidth: .infinity)
        } else {
            Text(todo.text)
                .font(.system(size: prefs.fontSize, design: prefs.font.design))
                .foregroundStyle(todo.isCompleted ? Palette.secondaryText : Palette.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .overlay(alignment: .leading) { strike }
                .help(todo.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.click(todo.uuid, extend: NSEvent.modifierFlags.contains(.shift))
                }
        }
    }

    /// The line that sweeps across the text when the todo is completed.
    private var strike: some View {
        Rectangle()
            .fill(Palette.strikethrough)
            .frame(height: 1)
            .scaleEffect(x: isChecked ? 1 : 0, anchor: .leading)
            .animation(.easeOut(duration: Motion.completionSweep), value: isChecked)
    }

    private var highlight: some View {
        RoundedRectangle(cornerRadius: PanelStyle.rowCornerRadius, style: .continuous)
            .fill(Palette.highlight)
            .opacity(isSelected ? 1 : (hovering && !isCompleting ? 0.6 : 0))
            .padding(.horizontal, PanelStyle.highlightInset)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private var menu: some View {
        if todo.isCompleted {
            Button("Restore") { model.restore([todo.uuid]) }
            Divider()
            Button("Delete") { model.delete([todo.uuid]) }
        } else {
            Button("Complete") { model.complete([todo.uuid]) }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Edit") { model.beginEditing(todo.uuid) }
            Divider()
            Button("Delete") { model.delete([todo.uuid]) }
                .keyboardShortcut(.delete, modifiers: .command)
        }
    }

    private func handle(_ command: RowTextField.Command) {
        let id = todo.uuid
        switch command {
        case .submit:
            if TodoText.clean(todo.text) == nil { model.commitEditing() } else { model.add(after: id) }
        case .cancel: model.commitEditing(then: .selection(ListSelection(id)))
        case .up: model.editNeighbor(of: id, step: -1)
        case .down: model.editNeighbor(of: id, step: 1)
        case .extendUp: model.extendSelection(step: -1)
        case .extendDown: model.extendSelection(step: 1)
        case .backspaceEmpty: model.deleteEmptyRow(id)
        }
    }
}

/// The hollow circle that completes a todo, or the filled circle with a check.
struct CheckCircle: View {
    var checked: Bool
    var size: CGFloat
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Palette.circle, lineWidth: 1)
                    .opacity(checked ? 0 : 1)
                Circle()
                    .fill(Palette.text)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.5, weight: .bold))
                            .foregroundStyle(Palette.surface)
                    }
                    .scaleEffect(checked ? 1 : 0.4)
                    .opacity(checked ? 1 : 0)
            }
            .frame(width: size, height: size)
            .padding(3)
            .contentShape(Circle())
            .animation(.spring(duration: 0.3, bounce: 0.4), value: checked)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(checked ? "Move this todo back to the list" : "Complete this todo (⌘↩)")
    }
}

/// An empty row below the last todo. Clicking it adds a todo.
struct FillerRow: View {
    @Environment(AppModel.self) private var model
    let index: Int
    let metrics: PanelMetrics

    var body: some View {
        HStack {
            Circle()
                .strokeBorder(Palette.filler(index), lineWidth: 1)
                .frame(width: metrics.circleSize, height: metrics.circleSize)
                .padding(3)
            Spacer()
        }
        .padding(.horizontal, PanelStyle.rowInset)
        .frame(height: metrics.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.add() }
        .accessibilityElement()
        .accessibilityLabel("New todo")
        .accessibilityAddTraits(.isButton)
    }
}
