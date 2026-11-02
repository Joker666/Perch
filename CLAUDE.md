# DoFloaty

A tiny floating todo list for the Mac, a rebuild of FloatyDo. A borderless
panel floats above other windows. A local SwiftData database, no server.
Brief, stories, and glossary in `docs/`. Reference notes in `docs/research/`.

## Layout

- `Sources/DoFloaty/` the app. `App.swift` has the menus, the menu bar item, and the database location.
  `Models.swift` has `Todo` and `AppModel` (every action, focus, and undo). `Panel/` is the floating panel.
  `Settings/` is the themed Settings window. `System/Hotkey.swift` is the global shortcut.
- `Sources/DoFloatyKit/` rules and data logic with no SwiftUI. Tests in `Tests/DoFloatyKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/DoFloaty.app`.
- `Icon/AppIcon.icon` the app icon, an Icon Composer file (JSON plus SVG layers). `build.sh` compiles it with `tools/make_icon.sh`; `tools/icon_review.sh` renders every look into one PNG.
- `docs/` the brief, the screen index, and the user stories, when they exist.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings; fix them.
- Unit tests: `swift test --scratch-path ~/Library/Developer/DoFloaty/test-build`.
- Self-test (the app's real functions on a /tmp store): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh`.
  It writes `/tmp/DoFloaty-shots/<page>-<theme>.png` for every panel state in `Snapshot.pages` and `settings-<tab>-<theme>.png` for every Settings tab, in Midnight and Matcha, then quits. `APP_SNAPSHOT_PAGES=panel,settings` limits the pages. `APP_SNAPSHOT_THEMES=plum,pool` picks the themes.
  The snapshot run cannot take focus from the terminal, so traffic lights and the caret show inactive there.
- Snapshots, seed data, and the self-test refuse to run without `APP_STORE` in /tmp.
- Never test against the real database in `~/Library/Application Support/DoFloaty/`.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/DoFloaty-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Design rules

- The panel has its own look, matched to FloatyDo: 8 themes in `UI/Theme.swift`, each three colors. Every other color is the theme's text color at an opacity in `Palette`. Never hard-code colors, sizes, or durations in views: use `Palette`, `PanelStyle`, `Motion`, and `PanelMetrics` (DoFloatyKit).
- A theme sets the whole app's appearance: dark themes give dark system controls, light themes light ones (`Prefs.applyAppearance`).
- The panel height always fits its rows (`PanelController.fit`). Never add a fixed height to the panel.
- The Settings window uses system controls (Slider, Picker, Button) tinted by the theme, on the theme's surface color.
- Spacing in Settings comes from `Space` in `UI/Grid.swift`, on a 4 pt grid.
- Every action has a menu bar item and a keyboard shortcut. Icon-only buttons have `.help` with the shortcut.
- Names come from `docs/GLOSSARY.md`: Todo, List, Archive, Complete, Restore, Delete.
- SF Symbols for icons. No FloatyDo assets.

## Skills

The bama plugin has a skill for each step. Call the Skill tool with `bama`
to pick the next one.

## Git

- Commit after each working change, with a message that says what the user can now do.
