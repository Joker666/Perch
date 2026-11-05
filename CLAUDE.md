# Perch

A tiny floating todo list for the Mac, a rebuild of FloatyDo. A borderless
panel floats above other windows. A SwiftData database that syncs with iCloud, no server.
An iPhone and iPad app in `iOS/` shares the model, themes, and iCloud container.
Brief, stories, and glossary in `docs/`. Reference notes in `docs/research/`.

## Layout

- `Sources/Perch/` the app. `App.swift` has the scenes, the menu bar item, and the database location.
  `Models.swift` has `Todo` and `AppModel` (every action and undo). `Panel/` is the floating panel.
  `Settings/` is the themed Settings window. `System/` has the menus (`AppMenus`), the global shortcut (`Hotkey`), and updates (`Updates`).
  `Agent/` is the `perch` command and the MCP server. Its commands are in `AgentCommands.swift`.
- `Sources/Perch/Shared/` files both apps compile: `Todo` and `AppModel` (Models.swift), `Store`, themes, `Prefs`, sounds, icons, seed data, `Space`.
  Platform code in them uses `#if os(macOS)`. A change there must build for both apps.
- `iOS/` the iOS app. `iOS/project.yml` is the XcodeGen project (scheme `PerchPhone`). The generated `Perch.xcodeproj` is not in git.
- `Sources/PerchKit/` rules and data logic with no SwiftUI, including the keyboard focus rules. Tests in `Tests/PerchKitTests/`.
- `DockTile/` the Dock tile plug-in that shows the picked icon while Perch is quit. `build.sh` compiles it with `swiftc` and fills it with `Perch --dock-icons`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `/Applications/Perch.app`, the same place as the dmg. Keep only that one copy.
- `Icon/AppIcon.icon` the app icon, an Icon Composer file (JSON plus SVG layers). `build.sh` compiles it with `tools/make_icon.sh`. `tools/icon_review.sh` renders every look into one PNG.
- `ARCHITECTURE.md` targets, layers, seams, and the rules that keep them working. Read it before a change that crosses layers.
- `docs/` the brief, the user stories, the glossary, the agent commands, and reference notes. `docs/FIXLOG.md` has hard bugs and their rules.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings. Fix them.
- iCloud sync turns on when build.sh finds a provisioning profile with iCloud. Setup and schema: `docs/ICLOUD.md`.
- Unit tests: `swift test --scratch-path ~/Library/Developer/Perch/test-build`.
- Self-test (the app's real functions on a /tmp store): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- Agent CLI: `build.sh` links `~/.local/bin/perch`. After a change to `Agent/`, run `check-agent-cli.sh /Applications/Perch.app/Contents/MacOS/Perch` from the bama agent-cli skill's `scripts/`, and update `docs/AGENT-COMMANDS.md` and `.claude/skills/perch/SKILL.md`.
- iOS: `cd iOS && xcodegen` then `xcodebuild -scheme PerchPhone -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath ~/Library/Developer/Perch/ios-build build`. No warnings.
  `tools/ios-snap.sh` writes `/tmp/Perch-ios-shots/<page>-<theme>.png` (list, edit, archive, archive-empty, settings) on a test store. Look at them after an iOS UI change.
  `tools/make_ios_icons.sh` remakes `iOS/Icons.xcassets` from `AppIconView` after a change to the icons or themes.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh`.
  It writes `/tmp/Perch-shots/<page>-<theme>.png` for every panel state in `Snapshot.pages` and `settings-<tab>-<theme>.png` for every Settings tab, in Midnight and Matcha, then quits. `APP_SNAPSHOT_PAGES=panel,settings` limits the pages. `APP_SNAPSHOT_THEMES=plum,pool` picks the themes.
  The snapshot run cannot take focus from the terminal, so traffic lights and the caret show inactive there.
- Snapshots, seed data, and the self-test refuse to run without `APP_STORE` in /tmp.
- Never test against the real database in `~/Library/Application Support/Perch/`.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/Perch-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Release and site

- `tools/release.sh` builds `dist/Perch.app` and `dist/Perch.dmg`, notarizes when the Apple values are set, signs the dmg for Sparkle, and rewrites `site/appcast.xml`. `.github/workflows/release.yml` runs it for each `v*` tag. README lists the secrets.
- Sparkle: `System/Updates.swift`. The feed URL and public key are in `Info.plist.in`. The private key is in the login keychain under the account `perch`. Never commit it.
  `TagVersionRules` offers an update only for a newer version tag (CFBundleShortVersionString). Build numbers are timestamps and never decide an update.
- Only the release workflow writes `site/appcast.xml`. Release notes go inline in its `<description>` (from `docs/release-notes/v<version>.md` when it exists, otherwise the commit subjects since the last tag). Never use `sparkle:releaseNotesLink`: Sparkle loads that whole page into the update window. To fix a live entry by hand, keep its version, enclosure, and edSignature.
- `site/` is the website, published by `.github/workflows/pages.yml` to https://rafihasan.com/Perch/. No build step: plain HTML and CSS.

## Design rules

- The panel has its own look, matched to FloatyDo: 8 themes in `UI/Theme.swift`, each three colors. Every other color is the theme's text color at an opacity in `Palette`. Never hard-code colors, sizes, or durations in views: use `Palette`, `PanelStyle`, `Motion`, and `PanelMetrics` (PerchKit).
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
