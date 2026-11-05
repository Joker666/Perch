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
            if model.archived.isEmpty {
                Text("Completed todos show here.")
                    .foregroundStyle(Palette.tertiaryText)
            }
        }
    }

    private var clearTitle: String {
        model.archived.count == 1 ? "Delete 1 Completed Todo?" : "Delete \(model.archived.count) Completed Todos?"
    }
}
