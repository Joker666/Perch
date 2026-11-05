import PerchKit
import SwiftUI

/// Theme, font, sounds, app icon, the version, and iCloud, as a sheet over the List.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = Prefs.shared
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $prefs.themeMode) {
                        Text("One Theme").tag(ThemeChoice.Mode.one)
                        Text("Match System").tag(ThemeChoice.Mode.matchSystem)
                    }
                    .pickerStyle(.segmented)
                    if prefs.themeMode == .one {
                        ThemeGrid(selected: prefs.themeID) { prefs.themeChoice.set($0, for: nil, systemIsDark: prefs.systemIsDark) }
                    } else {
                        LabeledContent("Light") {}
                        ThemeGrid(selected: prefs.lightThemeID) { prefs.themeChoice.set($0, for: .light, systemIsDark: prefs.systemIsDark) }
                        LabeledContent("Dark") {}
                        ThemeGrid(selected: prefs.darkThemeID) { prefs.themeChoice.set($0, for: .dark, systemIsDark: prefs.systemIsDark) }
                    }
                }
                Section("Text") {
                    Picker("Font", selection: $prefs.font) {
                        ForEach(TodoFont.allCases) { Text($0.title).font(.system(.body, design: $0.design)).tag($0) }
                    }
                    Toggle("Sounds", isOn: $prefs.playSounds)
                }
                Section("App Icon") {
                    IconGrid(selected: prefs.iconID) { prefs.iconID = $0 }
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    LabeledContent("iCloud", value: Store.syncs ? "On" : "Off")
                } footer: {
                    Text("Your todos sync through your iCloud account. Perch has no account or server of its own.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(Palette.surface)
        .preferredColorScheme(prefs.theme.colorScheme)
    }
}

/// The 8 themes as round swatches. The picked one has a ring.
struct ThemeGrid: View {
    let selected: String
    let pick: (String) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Space.md) {
            ForEach(Theme.all) { theme in
                Button { pick(theme.id) } label: {
                    VStack(spacing: Space.xs) {
                        Circle()
                            .fill(theme.surfaceColor)
                            .overlay(Circle().fill(theme.highlightColor).padding(PhoneStyle.swatch / 4))
                            .overlay(Circle().strokeBorder(Palette.text, lineWidth: theme.id == selected ? 3 : 0))
                            .overlay(Circle().strokeBorder(Palette.divider, lineWidth: 1))
                            .frame(width: PhoneStyle.swatch, height: PhoneStyle.swatch)
                        Text(theme.name)
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.name)
                .accessibilityAddTraits(theme.id == selected ? .isSelected : [])
            }
        }
        .padding(.vertical, Space.xs)
    }
}

/// The 8 app icons. iOS asks before it changes the icon.
struct IconGrid: View {
    let selected: String
    let pick: (String) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Space.md) {
            ForEach(Theme.all) { theme in
                Button { pick(theme.id) } label: {
                    VStack(spacing: Space.xs) {
                        AppIconView(theme: theme, size: PhoneStyle.icon, fullBleed: true)
                            .clipShape(.rect(cornerRadius: PhoneStyle.icon * 0.225, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PhoneStyle.icon * 0.225, style: .continuous)
                                    .strokeBorder(Palette.text, lineWidth: theme.id == selected ? 3 : 0)
                            )
                        Text(theme.name)
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.name) icon")
                .accessibilityAddTraits(theme.id == selected ? .isSelected : [])
            }
        }
        .padding(.vertical, Space.xs)
    }
}
