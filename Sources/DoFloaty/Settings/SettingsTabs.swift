import SwiftUI

/// Label column width for the Theme tab, so every control starts on one edge.
private let labelWidth: CGFloat = 100

/// Settings > Theme: background, font, font size, and radius.
struct ThemeSettings: View {
    @Bindable private var prefs = Prefs.shared

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Space.lg, verticalSpacing: Space.xl) {
            GridRow {
                label("Background")
                Swatches(selection: $prefs.themeID)
                    .gridCellColumns(3)
            }
            GridRow {
                label("Font")
                Picker("Font", selection: $prefs.font) {
                    ForEach(TodoFont.allCases) { font in Text(font.title).tag(font) }
                }
                .labelsHidden()
                .gridCellColumns(2)
                ResetButton(disabled: prefs.font == .system) { prefs.font = .system }
            }
            GridRow {
                label("Font Size")
                Slider(value: $prefs.fontSize, in: Prefs.fontSizeRange, step: 1) {
                    Text("Font Size")
                } minimumValueLabel: { EmptyView() } maximumValueLabel: { EmptyView() }
                .labelsHidden()
                value("\(Int(prefs.fontSize)) pt")
                ResetButton(disabled: prefs.fontSize == Prefs.defaultFontSize) { prefs.fontSize = Prefs.defaultFontSize }
            }
            GridRow {
                label("Radius")
                // No step: a step of 1 draws 25 tick marks. The value rounds instead.
                Slider(value: Binding(get: { prefs.radius }, set: { prefs.radius = $0.rounded() }),
                       in: Prefs.radiusRange)
                    .labelsHidden()
                value("\(Int(prefs.radius)) px")
                ResetButton(disabled: prefs.radius == Prefs.defaultRadius) { prefs.radius = Prefs.defaultRadius }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .frame(width: labelWidth, alignment: .trailing)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Palette.secondaryText)
            .frame(width: 44, alignment: .trailing)
    }
}

/// The eight theme colors in a capsule. The chosen one has a dot.
private struct Swatches: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(Theme.all) { theme in
                Button {
                    selection = theme.id
                } label: {
                    Circle()
                        .fill(theme.swatch)
                        .overlay { Circle().strokeBorder(Palette.divider, lineWidth: 1) }
                        .overlay {
                            Circle()
                                .fill(theme.textColor)
                                .frame(width: 8, height: 8)
                                .opacity(selection == theme.id ? 1 : 0)
                        }
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Use the \(theme.name) theme")
                .accessibilityLabel(theme.name)
                .accessibilityAddTraits(selection == theme.id ? .isSelected : [])
            }
        }
        .padding(Space.sm)
        .background(Capsule().fill(Palette.control))
    }
}

private struct ResetButton: View {
    var disabled: Bool
    var action: () -> Void

    var body: some View {
        Button("Reset", action: action)
            .controlSize(.small)
            .disabled(disabled)
    }
}

/// Settings > Shortcuts: the global shortcut and the keys inside the panel.
struct ShortcutsSettings: View {
    private let rows: [(String, String)] = [
        ("New todo", "⌘N"),
        ("Add a todo below", "↩"),
        ("Move between todos", "↑  ↓"),
        ("Select more todos", "⇧↑  ⇧↓"),
        ("Complete", "⌘↩"),
        ("Delete", "⌘⌫"),
        ("Move todo up or down", "⌥⌘↑  ⌥⌘↓"),
        ("Show List or Archive", "⌘1  ⌘2"),
        ("Undo", "⌘Z"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    Text("Show or hide DoFloaty")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Keycap(Hotkey.display)
                }
                Text(Hotkey.status == noErr
                     ? "Works from any app. Opens a new todo, ready to type."
                     : "Another app uses \(Hotkey.display). Quit that app, then restart DoFloaty.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondaryText)
            }
            Rectangle().fill(Palette.divider).frame(height: 1)
            VStack(spacing: Space.sm) {
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0).font(.system(size: 13))
                        Spacer()
                        Keycap(row.1)
                    }
                }
            }
        }
    }
}

private struct Keycap: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.control))
    }
}

/// Settings > Icon: one app icon per theme.
struct IconSettings: View {
    @Bindable private var prefs = Prefs.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(spacing: 0) {
                ForEach(Array(Theme.all.enumerated()), id: \.element.id) { index, theme in
                    if index > 0 { Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 84) }
                    row(theme)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.divider))
            Text("The Dock shows the new icon at once.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private func row(_ theme: Theme) -> some View {
        let current = prefs.iconID == theme.id
        return Button {
            prefs.iconID = theme.id
        } label: {
            HStack(spacing: Space.md) {
                Circle()
                    .strokeBorder(Palette.circle, lineWidth: 1)
                    .overlay { Circle().fill(Palette.text).padding(4).opacity(current ? 1 : 0) }
                    .frame(width: 18, height: 18)
                AppIconView(theme: theme, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name).font(.system(size: 13, weight: .medium))
                    if current {
                        Text("Current icon")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Space.md)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("\(theme.name) icon")
        .accessibilityAddTraits(current ? .isSelected : [])
    }
}

/// Settings > About.
struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            AppIconView(theme: Theme.named(Prefs.shared.iconID), size: 96)
            Text("DoFloaty")
                .font(.system(size: 20, weight: .semibold))
            Text(version)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryText)
            Text("A tiny floating todo list for the Mac.")
                .font(.system(size: 13))
                .padding(.top, Space.sm)
            Text("Inspired by FloatyDo by Raffi Chilingaryan and Emirhan.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
