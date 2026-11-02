import AppKit
import SwiftUI
import PerchKit

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case theme, shortcuts, icon, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Theme"
        case .shortcuts: "Shortcuts"
        case .icon: "Icon"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
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

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        keepOnScreen(window)
    }

    /// The height of the tab bar and the tab, under the title bar. The self-test reads it.
    private(set) var contentHeight: CGFloat = 0

    /// Fits the window to the height of the tab's content, with the top edge
    /// fixed. A tab change animates on the same curve as the cross-fade.
    /// Near the bottom of the screen the window moves up instead of under the Dock.
    func fit(contentHeight: CGFloat) {
        self.contentHeight = contentHeight
        guard let window, contentHeight > 0 else { return }
        let titlebar = window.frame.height - window.contentLayoutRect.height
        var frame = window.frame
        frame.origin.y = frame.maxY - contentHeight - titlebar
        frame.size.height = contentHeight + titlebar
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame = WindowPlacement.keptOnScreen(frame, in: visible)
        }
        guard frame != window.frame else { return }
        guard window.isVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.tabChange
            context.timingFunction = Motion.tabChangeCurve
            window.animator().setFrame(frame, display: true)
        }
    }

    private func keepOnScreen(_ window: NSWindow) {
        guard let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        let frame = WindowPlacement.keptOnScreen(window.frame, in: visible)
        if frame != window.frame { window.setFrameOrigin(frame.origin) }
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView().environment(model))
        host.sizingOptions = [] // fit(contentHeight:) sizes the window, so it can animate
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.title = "Perch"
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName(Store.isOverridden ? "" : "Settings")
        if !window.setFrameUsingName("Settings") { window.center() }
        recolor(window)
        trackTheme(window)
        self.window = window
        fit(contentHeight: contentHeight)
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
    /// The tab fading out after a tab change. It sits on top without taking
    /// space, so the window fits the new tab while the two cross-fade.
    @State private var leaving: SettingsTab?
    @State private var fadeIn = 1.0

    var body: some View {
        VStack(spacing: 0) {
            TabBar()
                .padding(.bottom, Space.sm)
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)
            content(model.settingsTab)
                .gridArea("settings-\(model.settingsTab.rawValue)")
                .opacity(fadeIn)
                .overlay(alignment: .top) {
                    if let leaving {
                        content(leaving)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(1 - fadeIn)
                            .allowsHitTesting(false)
                    }
                }
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            SettingsWindowController.shared.fit(contentHeight: height)
        }
        // The window animates its height, so the content stays at the top and clips.
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .foregroundStyle(Palette.text)
        .tint(Palette.text)
        .background(Palette.surface)
        .noInitialFocus()
        .onChange(of: model.settingsTab) { old, _ in
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            leaving = old
            fadeIn = 0
            withAnimation(Motion.tabFade) {
                fadeIn = 1
            } completion: {
                leaving = nil
            }
        }
    }

    @ViewBuilder
    private func content(_ tab: SettingsTab) -> some View {
        Group {
            switch tab {
            case .theme: ThemeSettings()
            case .shortcuts: ShortcutsSettings()
            case .icon: IconSettings()
            case .about: AboutSettings()
            }
        }
        .padding(Space.xxl)
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
                            .font(.system(size: 15))
                            .frame(height: 20)
                        Text(tab.title)
                            .font(.system(size: 11))
                    }
                    .frame(width: 72, height: 44)
                    .foregroundStyle(selected ? Palette.text : Palette.secondaryText)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
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
