import PerchKit
import SwiftUI

/// The open todos. Tap a row to type in it, Return for the next row, the
/// circle to complete, swipe to delete, and long-press and drag to reorder.
struct ListPage: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: UUID?

    var body: some View {
        List {
            Section {
                ForEach(model.todos) { todo in
                    ListRow(todo: todo, focused: $focused)
                }
                .onMove { from, to in model.move(from.map { model.todos[$0].uuid }, to: to) }
                NewTodoRow()
            } header: {
                PageTitle("Perch")
            }
        }
        .pageList()
        .onChange(of: model.editingID) { _, id in focused = id }
        .onChange(of: focused) { _, id in
            if let id {
                model.beginEditing(id)
            } else if model.editingID != nil {
                model.commitEditing()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .fontWeight(.semibold)
            }
        }
    }
}

/// One open todo: the text field, then the circle at the end.
struct ListRow: View {
    @Environment(AppModel.self) private var model
    let todo: Todo
    var focused: FocusState<UUID?>.Binding

    var body: some View {
        let done = model.completing.contains(todo.uuid)
        HStack(spacing: Space.md) {
            TextField("Todo", text: Binding(get: { todo.text }, set: { model.updateText(todo.uuid, $0) }))
                .focused(focused, equals: todo.uuid)
                .submitLabel(.next)
                .onSubmit {
                    // Return on an empty row ends typing. Otherwise it adds the next row.
                    if TodoText.clean(todo.text) == nil { focused.wrappedValue = nil } else { model.add(after: todo.uuid) }
                }
                .strikethrough(done, color: Palette.strikethrough)
                .foregroundStyle(done ? Palette.secondaryText : Palette.text)
            CircleButton(checked: done, label: "Complete") { model.complete([todo.uuid]) }
        }
        .todoFont()
        .pageRow(highlighted: model.editingID == todo.uuid)
        // A light tap when the circle checks, like the click on the Mac.
        .sensoryFeedback(.impact(weight: .light), trigger: done) { _, checked in checked }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { model.delete([todo.uuid]) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

/// The empty row at the end. A tap starts a new todo there.
struct NewTodoRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.add() } label: {
            Text("New todo")
                .foregroundStyle(Palette.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .todoFont()
        .pageRow(highlighted: false)
        .moveDisabled(true)
    }
}

/// The open circle that completes a todo, or the filled check in the Archive.
struct CircleButton: View {
    let checked: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: PhoneStyle.circle))
                .foregroundStyle(checked ? Palette.secondaryText : Palette.circle)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: PhoneStyle.rowHeight, height: PhoneStyle.rowHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The large title at the top of a page, in the theme's colors.
struct PageTitle<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.largeTitle, design: Prefs.shared.font.design, weight: .bold))
                .foregroundStyle(Palette.text)
            Spacer()
            trailing
        }
        .textCase(nil)
        .padding(.bottom, Space.sm)
        .listRowInsets(EdgeInsets(top: 0, leading: Space.margin, bottom: 0, trailing: Space.margin))
    }
}

extension View {
    /// The todo text in the font picked in Settings, at the reader's text size.
    func todoFont() -> some View {
        font(.system(.body, design: Prefs.shared.font.design))
    }

    /// A list row on the theme's surface, with the highlight while typing.
    func pageRow(highlighted: Bool) -> some View {
        frame(minHeight: PhoneStyle.rowHeight)
            .listRowInsets(EdgeInsets(top: 0, leading: Space.margin, bottom: 0, trailing: Space.sm))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: PhoneStyle.rowCornerRadius, style: .continuous)
                    .fill(highlighted ? Palette.highlight : .clear)
                    .padding(.horizontal, Space.sm)
            )
    }

    /// A plain list that shows the theme's surface and leaves room for the bottom bar.
    func pageList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, PhoneStyle.addButton + Space.xxl, for: .scrollContent)
    }
}
