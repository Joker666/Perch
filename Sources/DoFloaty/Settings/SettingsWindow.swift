import AppKit
import SwiftUI

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
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView().environment(model))
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.title = "DoFloaty"
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName(Store.isOverridden ? "" : "Settings")
        if !window.setFrameUsingName("Settings") { window.center() }
        recolor(window)
        trackTheme(window)
        return window
    }

    private func recolor(_ window: NSWindow) {
        window.backgroundColor = NSColor(hex: Prefs.shared.theme.surface)
    }

    private func trackTheme(_ window: NSWindow) {
        withObservationTracking {
            _ = Prefs.shared.themeID
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
                case .theme: ThemeSettings()
                case .shortcuts: ShortcutsSettings()
                case .icon: IconSettings()
                case .about: AboutSettings()
                }
            }
            .padding(Space.xxl)
            .gridArea("settings-\(model.settingsTab.rawValue)")
        }
        .frame(width: 520)
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
