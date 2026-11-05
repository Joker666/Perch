import PerchKit
import SwiftUI
import UIKit

/// The whole screen: the List or the Archive in the theme's colors, and a bar at
/// the bottom to switch pages, open Settings, undo, and add a todo.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.surface.ignoresSafeArea()
            Group {
                switch model.mode {
                case .list: ListPage()
                case .archive: ArchivePage()
                }
            }
            // Typing shows the keyboard's Done button instead of the bar.
            if model.editingID == nil {
                BottomBar(showSettings: $showSettings)
                    .transition(.opacity)
            }
        }
        .animation(Motion.hover, value: model.editingID == nil)
        .foregroundStyle(Palette.text)
        .tint(Palette.text)
        .preferredColorScheme(Prefs.shared.theme.colorScheme)
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .onAppear {
            SystemAppearance.start()
            openRequestedPage()
        }
    }
}

extension RootView {
    /// For screenshots with a test store: APP_PAGE=archive, settings, or edit.
    ///   xcrun simctl launch <device> com.rafi.perch with SIMCTL_CHILD_APP_STORE, _APP_SEED, _APP_PAGE
    private func openRequestedPage() {
        guard Store.isOverridden else { return }
        switch ProcessInfo.processInfo.environment["APP_PAGE"] {
        case "archive": model.mode = .archive
        case "settings": showSettings = true
        case "edit": if let first = model.todos.first { model.beginEditing(first.uuid) }
        default: break
        }
    }
}

/// Page buttons on the left, Undo and Add on the right, on Liquid Glass.
struct BottomBar: View {
    @Environment(AppModel.self) private var model
    @Binding var showSettings: Bool
    @State private var undo = UndoState()

    var body: some View {
        HStack(spacing: Space.md) {
            HStack(spacing: Space.xs) {
                pageButton(.list, icon: "checklist", label: "List")
                pageButton(.archive, icon: "tray", label: "Archive")
                barButton(icon: "gearshape", label: "Settings") { showSettings = true }
            }
            .padding(Space.xs)
            .glassEffect(.regular, in: .capsule)
            Spacer()
            if let title = undo.title {
                Button { model.commitEditing(); model.undoManager.undo() } label: {
                    Label(title, systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                        .frame(width: PhoneStyle.barButton, height: PhoneStyle.barButton)
                }
                .glassEffect(.regular, in: .circle)
                .accessibilityLabel(title)
            }
            if model.mode == .list {
                Button { model.add() } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: PhoneStyle.addButton, height: PhoneStyle.addButton)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("New Todo")
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.sm)
        .onAppear { undo.watch(model.undoManager) }
    }

    private func pageButton(_ mode: PanelMode, icon: String, label: String) -> some View {
        barButton(icon: icon, label: label, selected: model.mode == mode) {
            model.commitEditing()
            model.mode = mode
        }
    }

    private func barButton(icon: String, label: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: PhoneStyle.barButton, height: PhoneStyle.barButton)
                .background(selected ? Palette.highlight : .clear, in: .circle)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "Undo Add Todo" and so on, kept current from the model's undo manager.
@Observable
final class UndoState {
    private(set) var title: String?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func watch(_ manager: UndoManager) {
        guard observers.isEmpty else { return }
        let names: [Notification.Name] = [.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: manager, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update(manager) }
            }
        }
        update(manager)
    }

    private func update(_ manager: UndoManager) {
        title = manager.canUndo ? manager.undoMenuItemTitle : nil
    }
}

/// Sizes of the iOS parts. Views use these, never literal numbers.
enum PhoneStyle {
    static let barButton: CGFloat = 40
    static let addButton: CGFloat = 52
    static let circle: CGFloat = 22
    static let rowHeight: CGFloat = 44
    static let rowCornerRadius: CGFloat = 12
    static let swatch: CGFloat = 44
    static let icon: CGFloat = 60
}

extension SystemAppearance {
    /// Follows the system's Light and Dark from the window scene. The window
    /// itself shows the theme's scheme, so it cannot tell.
    static func start() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        Prefs.shared.systemIsDark = scene.traitCollection.userInterfaceStyle == .dark
        scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (scene: UIWindowScene, _) in
            Prefs.shared.systemIsDark = scene.traitCollection.userInterfaceStyle == .dark
        }
    }
}
