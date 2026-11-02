import SwiftUI
import DoFloatyKit

/// Everything inside the floating panel: the title bar and the List or Archive.
struct PanelView: View {
    @Environment(AppModel.self) private var model
    private var prefs: Prefs { Prefs.shared }

    var body: some View {
        let metrics = PanelMetrics(fontSize: prefs.fontSize)
        VStack(spacing: 0) {
            TitleBar()
                .frame(height: PanelMetrics.titlebarHeight)
                .padding(.top, PanelMetrics.topInset)
            ScrollView {
                Group {
                    if model.mode == .list { TodoList(metrics: metrics) } else { ArchiveList(metrics: metrics) }
                }
                .padding(.top, PanelMetrics.contentTopPadding)
                .padding(.bottom, PanelMetrics.contentBottomPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: prefs.radius, style: .continuous))
        .tint(Palette.text)
    }
}

/// Traffic lights on the left, List, Archive, and Settings on the right.
/// Dragging the bar moves the panel.
private struct TitleBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 2) {
            TrafficLights()
                .padding(.leading, PanelStyle.trafficLightLeading)
            Spacer(minLength: 0)
            ToolbarButton(symbol: "checklist", label: "List", help: "Show your todos (⌘1)",
                          active: model.mode == .list) { model.mode = .list }
            ToolbarButton(symbol: "archivebox", label: "Archive", help: "Show completed todos (⌘2)",
                          active: model.mode == .archive) { model.mode = .archive }
            ToolbarButton(symbol: "gearshape", label: "Settings", help: "Change the theme, font, and icon (⌘,)",
                          active: false) { SettingsWindowController.shared.show() }
        }
        .padding(.trailing, PanelStyle.titlebarTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }
}

private struct ToolbarButton: View {
    let symbol: String
    let label: String
    let help: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: PanelStyle.toolbarIcon, weight: .medium))
                .foregroundStyle(active ? Palette.text : Palette.toolbarIcon)
                .frame(width: PanelStyle.toolbarButton, height: PanelStyle.toolbarButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(label)
    }
}

/// The open todos, then three filler rows. Rows reorder by dragging.
private struct TodoList: View {
    @Environment(AppModel.self) private var model
    let metrics: PanelMetrics

    @State private var drag: (id: UUID, from: Int, translation: CGFloat)?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.todos.enumerated()), id: \.element.uuid) { index, todo in
                TodoRow(todo: todo, metrics: metrics, isDragging: drag?.id == todo.uuid)
                    .offset(y: offset(at: index)) // grid: ok the dragged row follows the pointer
                    .zIndex(drag?.id == todo.uuid ? 1 : 0)
                    .animation(drag?.id == todo.uuid ? nil : Motion.dragReorder, value: target)
                    .gesture(reorder(todo, index), including: model.editingID == todo.uuid ? .subviews : .all)
                    .transition(.opacity)
            }
            ForEach(0..<PanelMetrics.fillerCount, id: \.self) { index in
                FillerRow(index: index, metrics: metrics)
            }
        }
        .animation(Motion.collapse, value: model.todos.map(\.uuid))
    }

    /// The index the dragged row would land on now.
    private var target: Int? {
        guard let drag else { return nil }
        let moved = Int((drag.translation / metrics.rowHeight).rounded())
        return max(0, min(model.todos.count - 1, drag.from + moved))
    }

    private func offset(at index: Int) -> CGFloat {
        guard let drag, let target else { return 0 }
        if index == drag.from { return drag.translation }
        if drag.from < index, index <= target { return -metrics.rowHeight }
        if target <= index, index < drag.from { return metrics.rowHeight }
        return 0
    }

    private func reorder(_ todo: Todo, _ index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                drag = (todo.uuid, index, value.translation.height)
            }
            .onEnded { _ in
                guard let drag, let target else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    model.move([drag.id], to: target > drag.from ? target + 1 : target)
                    self.drag = nil
                }
            }
    }
}

/// Completed todos, newest first.
private struct ArchiveList: View {
    @Environment(AppModel.self) private var model
    let metrics: PanelMetrics

    var body: some View {
        VStack(spacing: 0) {
            if model.archived.isEmpty {
                Text("Nothing completed yet")
                    .font(.system(size: Prefs.shared.fontSize, design: Prefs.shared.font.design))
                    .foregroundStyle(Palette.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.rowHeight * 2)
            } else {
                ForEach(model.archived, id: \.uuid) { todo in
                    TodoRow(todo: todo, metrics: metrics)
                }
            }
        }
        .animation(Motion.collapse, value: model.archived.map(\.uuid))
    }
}
