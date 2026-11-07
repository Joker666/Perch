import AppKit
import SwiftUI
import PerchKit

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, theme, shortcuts, icon, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .theme: "Theme"
        case .shortcuts: "Shortcuts"
        case .icon: "Icon"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .theme: "paintbrush"
        case .shortcuts: "command"
        case .icon: "app.badge.checkmark"
        case .about: "info.circle"
        }
    }
}

/// Perch's menu shortcuts work even while SwiftUI rebuilds the Edit menu (System/AppMenus.swift).
final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        super.performKeyEquivalent(with: event) || AppMenus.shared.performKeyEquivalent(event)
    }
}

/// The Settings window (Command-Comma). It takes the theme's colors, like the panel.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private(set) var window: NSWindow?
    var model: AppModel!

    static let width: CGFloat = 560
    /// The gap between the panel and Settings when Settings opens beside it.
    static let gap: CGFloat = 24
    /// The top-left corner where you last left Settings. Test runs neither read nor write it.
    private static let placeKey = "settingsTopLeft"
    /// True while Perch moves the window itself, so only your moves are saved.
    private var placing = false

    func show() {
        let isNew = window == nil
        let window = window ?? makeWindow()
        self.window = window
        if isNew || !window.isVisible { place(window) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        keepOnScreen(window)
    }

    /// Where you last left Settings, or beside the panel with the top edges aligned.
    private func place(_ window: NSWindow) {
        placing = true
        defer { placing = false }
        let saved = Store.isOverridden ? nil : UserDefaults.standard.array(forKey: Self.placeKey) as? [Double]
        if let saved, saved.count == 2 {
            window.setFrameTopLeftPoint(NSPoint(x: saved[0], y: saved[1]))
        } else if let panel = PanelController.shared?.homeFrame,
                  let visible = NSScreen.showing(panel)?.visibleFrame {
            // A new window does not have its content's size yet, so place it by the size it will take.
            let content = window.contentViewController?.view.fittingSize ?? window.contentLayoutRect.size
            let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
            let frame = WindowPlacement.beside(panel, size: size, gap: Self.gap, in: visible)
            window.setFrame(frame, display: false)
        } else {
            window.center()
        }
    }

    /// A taller tab grows the window down from its top edge. Near the bottom of
    /// the screen that put rows under the Dock, so the window moves up instead.
    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow { keepOnScreen(window) }
    }

    /// Saves the top-left corner after you drag the window. The size comes from the tab.
    func windowDidMove(_ notification: Notification) {
        guard !placing, !Store.isOverridden, let window = notification.object as? NSWindow else { return }
        UserDefaults.standard.set([window.frame.minX, window.frame.maxY], forKey: Self.placeKey)
    }

    private func keepOnScreen(_ window: NSWindow) {
        guard let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        let frame = WindowPlacement.keptOnScreen(window.frame, in: visible)
        guard frame != window.frame else { return }
        placing = true
        window.setFrameOrigin(frame.origin)
        placing = false
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView().environment(model))
        host.sizingOptions = [.preferredContentSize]
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.title = "Perch"
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Older versions saved the whole frame, size included. Only the corner is saved now.
        if !Store.isOverridden { UserDefaults.standard.removeObject(forKey: "NSWindow Frame Settings") }
        recolor(window)
        trackTheme(window)
        return window
    }

    /// Edit > Undo in Settings takes back todo changes too, like in the panel,
    /// including changes an agent made through the CLI.
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        model.undoManager
    }

    private func recolor(_ window: NSWindow) {
        window.backgroundColor = NSColor(hex: Prefs.shared.theme.surface)
    }

    private func trackTheme(_ window: NSWindow) {
        withObservationTracking {
            _ = Prefs.shared.theme
        } onChange: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, let window else { return }
                self.recolor(window)
                self.trackTheme(window)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            TabBar()
                .padding(.bottom, Space.sm)
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)
            Group {
                switch model.settingsTab {
                case .general: GeneralSettings()
                case .theme: ThemeSettings()
                case .shortcuts: ShortcutsSettings()
                case .icon: IconSettings()
                case .about: AboutSettings()
                }
            }
            // Room like FloatyDo's Settings: wide margins and rows well apart.
            .padding(.horizontal, Space.section)
            .padding(.vertical, Space.section)
            .gridArea("settings-\(model.settingsTab.rawValue)")
        }
        .frame(width: SettingsWindowController.width)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Palette.text)
        .tint(Palette.text)
        .background(Palette.surface)
        .noInitialFocus()
    }
}

/// Icon-over-label tabs, like the toolbar of a Mac Settings window.
private struct TabBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(SettingsTab.allCases) { tab in
                let selected = model.settingsTab == tab
                Button {
                    model.settingsTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbol)
                            .font(TextStyle.tabIcon)
                            .frame(height: SettingsStyle.tabIconHeight)
                        Text(tab.title)
                            .font(TextStyle.caption)
                    }
                    .frame(width: SettingsStyle.tabSize.width, height: SettingsStyle.tabSize.height)
                    .foregroundStyle(selected ? Palette.text : Palette.secondaryText)
                    .background {
                        RoundedRectangle(cornerRadius: SettingsStyle.tabRadius, style: .continuous)
                            .fill(Palette.highlight)
                            .opacity(selected ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
