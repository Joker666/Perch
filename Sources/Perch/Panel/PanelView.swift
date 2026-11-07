import SwiftUI
import PerchKit

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
                    .gesture(reorderGesture(todo, index), including: model.editingID == todo.uuid ? .subviews : .all)
                    .transition(.opacity)
            }
            ForEach(0..<PanelMetrics.fillerCount, id: \.self) { index in
                FillerRow(index: index, metrics: metrics)
            }
        }
        .animation(Motion.collapse, value: model.todos.map(\.uuid))
    }

    /// The drag as plain numbers (PerchKit), so its math has unit tests.
    private var reorder: DragReorder? {
        drag.map { DragReorder(from: $0.from, translation: $0.translation, rowHeight: metrics.rowHeight, count: model.todos.count) }
    }

    private var target: Int? { reorder?.target }

    private func offset(at index: Int) -> CGFloat {
        reorder?.offset(at: index) ?? 0 // grid: ok no drag, so no row moves
    }

    private func reorderGesture(_ todo: Todo, _ index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                drag = (todo.uuid, index, value.translation.height)
            }
            .onEnded { _ in
                guard let drag, let reorder else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    model.move([drag.id], to: reorder.destination)
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
                    .frame(height: metrics.rowHeight * Double(PanelMetrics.emptyArchiveRows))
            } else {
                ForEach(model.archived, id: \.uuid) { todo in
                    TodoRow(todo: todo, metrics: metrics)
                }
            }
        }
        .animation(Motion.collapse, value: model.archived.map(\.uuid))
    }
}

/// Close, minimize, and zoom, drawn like the system buttons. Detached system
/// buttons cannot see a borderless panel's key state, so these are drawn here.
struct TrafficLights: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        HStack(spacing: PanelStyle.trafficLightSpacing) {
            light(0xFF5F57, "xmark", "Close", "Hide the panel (⌘W)") { PanelController.shared.hide() }
            light(0xFEBC2E, "minus", "Minimize", "Minimize the panel to the Dock") {
                PanelController.shared.panel.miniaturize(nil)
            }
            light(0x28C840, "plus", "Zoom", "Switch between the wide and the default width") {
                PanelController.shared.toggleWidth()
            }
        }
        .onHover { hovering = $0 }
    }

    private func light(_ color: UInt32, _ glyph: String, _ label: String, _ help: String,
                       action: @escaping () -> Void) -> some View {
        let active = model.panelIsKey || hovering
        return Button(action: action) {
            Circle()
                .fill(active ? Color(hex: color) : Palette.inactiveLight)
                .overlay { Circle().strokeBorder(.black.opacity(active ? 0.12 : 0), lineWidth: 0.5) } // grid: ok hairline edge like the system buttons
                .overlay {
                    Image(systemName: glyph)
                        .font(.system(size: 6.5, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.55))
                        .opacity(hovering ? 1 : 0)
                }
                .frame(width: 12, height: 12)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(label)
    }
}
