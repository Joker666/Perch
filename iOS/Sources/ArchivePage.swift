import SwiftUI

/// Completed todos, newest first. The check restores a todo to the List, a
/// swipe deletes it, and Clear deletes them all after a question.
struct ArchivePage: View {
    @Environment(AppModel.self) private var model
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                ForEach(model.archived) { todo in
                    HStack(spacing: Space.md) {
                        Text(todo.text)
                            .strikethrough(color: Palette.strikethrough)
                            .foregroundStyle(Palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        CircleButton(checked: true, label: "Restore") { model.restore([todo.uuid]) }
                    }
                    .todoFont()
                    .pageRow(highlighted: false)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { model.delete([todo.uuid]) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } header: {
                PageTitle("Archive") {
                    if !model.archived.isEmpty {
                        Button("Clear") { confirmClear = true }
                            .confirmationDialog(clearTitle, isPresented: $confirmClear, titleVisibility: .visible) {
                                Button("Delete", role: .destructive) { model.clearArchive() }
                            } message: {
                                Text("You can undo this.")
                            }
                    }
                }
            }
        }
        .pageList()
        .overlay {
            if model.archived.isEmpty { EmptyArchive() }
        }
    }

    private var clearTitle: String {
        model.archived.count == 1 ? "Delete 1 Completed Todo?" : "Delete \(model.archived.count) Completed Todos?"
    }
}

/// The Archive with nothing in it: a large check in the theme's colors, a short
/// line on what goes here, and a way back to the List.
struct EmptyArchive: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle()
                    .fill(Palette.highlight)
                    .frame(width: PhoneStyle.emptyBadge, height: PhoneStyle.emptyBadge)
                Image(systemName: "checkmark")
                    .font(.system(size: PhoneStyle.emptyBadge * 0.4, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
            .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                Text("Nothing completed yet")
                    .font(.system(.title3, design: Prefs.shared.font.design, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text("Tap a circle in the List to complete a todo. It moves here, and you can bring it back.")
                    .font(.system(.subheadline, design: Prefs.shared.font.design))
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Button {
                model.mode = .list
            } label: {
                Text("Go to List")
                    .font(.system(.subheadline, design: Prefs.shared.font.design, weight: .semibold))
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.sm)
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, Space.section)
        .frame(maxWidth: PhoneStyle.emptyWidth)
    }
}
