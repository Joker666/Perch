# Architecture review, 2026-11-07

Perch has 5,790 lines of Swift in 44 files. The largest is `Shared/Models.swift`
(481 lines), and no file or type passes a size trigger. The cards from the
2026-11-02 review are all done, and `change` is the one write path it asked for.
The signal for this check-in is the iOS app: one feature (the shared model and
Settings) now compiles in 2 targets, and the self-test is the most changed file
(24 commits in 30 days).

There is nothing to optimize for speed. A change to the todos fetches the whole
table 4 times (before, after, renumber, reload), and every view reads colors
through an 8-theme scan. For a list of tens of todos, both are far under a
millisecond. The cards below are about locality and duplication.

## Type and size tokens for Settings  [Strong]

Files: Settings/SettingsTabs.swift (326 lines), Settings/SettingsWindow.swift,
Settings/ShortcutRecorder.swift
Signal: the design rule "never hard-code colors, sizes, or durations in views"
Problem: Settings writes its font sizes by hand 17 times (`13` seven times,
`11` five times, `12` three times, `15`, `20`), and its sizes too: the 100 pt
label column, the 44 pt value column, the 72 by 44 tab, the 24 pt swatch with
an 8 pt dot, the 52 pt icon row, the 84 pt divider inset, corner radii 8 and
12. The panel has `PanelStyle` and iOS has `PhoneStyle`. Settings has nothing,
so the same label style is written in four views (`GeneralSettings.row`,
`ThemeSettings.label`, `ShortcutsSettings`, `IconSettings.row`), and a change
to the label weight is four edits.
Proposal: text styles next to `Palette`, and a `SettingsStyle` next to
`PanelStyle`.

```swift
/// Text styles. Views never write a font size.
enum TextStyle {
    static let label = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 11)
    static let keycap = Font.system(size: 12, weight: .medium).monospacedDigit()
    static let value = Font.system(size: 13).monospacedDigit()
    static let title = Font.system(size: 20, weight: .semibold)
}

enum SettingsStyle {
    static let labelWidth: CGFloat = 100
    static let valueWidth: CGFloat = 44
    static let tabSize = CGSize(width: 72, height: 44)
    static let swatch: CGFloat = 24
    static let iconRow: CGFloat = 52
}
```

Benefits: locality, because a type or size change is one edit. The grid lint
gets fewer `// grid: ok` candidates. iOS keeps its Dynamic Type styles.
Proof of same behavior: the Settings snapshots in both themes are the same
pixels before and after (`tools/snap.sh`, `APP_SNAPSHOT_PAGES=settings`), and
`check-layout.swift` passes.
Plan: 2 commits. First `TextStyle` and every `.system(size:` in Settings. Then
`SettingsStyle` and the sizes.

## One table of shortcuts  [Worth exploring]

Files: App.swift (SwiftUI commands), System/AppMenus.swift (AppKit items),
Settings/SettingsTabs.swift (the Shortcuts tab), Panel/PanelView.swift,
Panel/TodoRow.swift, Panel/PanelController.swift (help texts)
Signal: one fact written in 4 places
Problem: ⌘1 is in the SwiftUI command, in the Shortcuts tab as the string
"⌘1  ⌘2", and in a help text "Show your todos (⌘1)". ⌘↩ is an AppKit item, a
context menu `.keyboardShortcut`, a help text, and a table row. The table and
the menus have already drifted: the Window menu's Hide Perch (⌘0) and
Settings (⌘,) are not in the Shortcuts tab. A new or changed shortcut is four
edits, and the self-test can check only the menus.
Proposal: one list of the app's shortcuts, built on `KeyCombo` (PerchKit),
which already knows modifier symbols and key names.

```swift
/// Every shortcut Perch shows or handles. Menus, help texts, and the
/// Shortcuts tab read this list.
enum Shortcut: CaseIterable {
    case newTodo, complete, delete, moveUp, moveDown, list, archive, settings, showHide, undo

    var title: String
    var combo: KeyCombo
    var display: String { KeyNames.display(combo) }          // "⌘↩"
    var keyEquivalent: (String, NSEvent.ModifierFlags)        // for AppMenus
    var swiftUI: KeyboardShortcut                             // for .commands and .help
}
```

Benefits: locality, and the Shortcuts tab can never miss a shortcut again.
Help texts like "Show your todos (\(Shortcut.list.display))" stay right when
a shortcut changes. The self-test can check that every `Shortcut` is in a menu.
Proof of same behavior: the menu titles and key equivalents dumped before and
after (`NSApp.mainMenu`), the Shortcuts tab snapshot, and the self-test's
menu checks.
Plan: 3 commits (the type and the menus, then the help texts and the tab,
then the self-test check).
Why not Strong: shortcuts have not changed since the first release, so the
duplication has not cost anything yet.

## The undo diff as plain values in PerchKit  [Worth exploring]

Files: Shared/Models.swift (`change`, `changedIDs`, `byID`, about 30 lines)
Signal: pure logic inside a `@MainActor` store
Problem: the rule that decides what an undo step puts back (what this change
touched, what the open edit touched, and never a todo iCloud merged in
between) is the most intricate rule in the app. It takes four arrays of plain
records and returns two sets. It sits in `AppModel.change`, so only two
self-test checks reach it, and they need the whole app and 10 seconds.
Proposal: a generic step maker in PerchKit, with `TodoRecord` conforming.

```swift
/// What one undo step puts back, from the records before and after a change.
public struct UndoStep<Record: Identifiable & Equatable> {
    public var touched: Set<Record.ID>
    public var records: [Record]

    /// `start` and `owned` describe an edit the change joined, or nil.
    public static func make(before: [Record], after: [Record],
                            editStart start: [Record]?, owned: Set<Record.ID>) -> UndoStep?
}
```

Benefits: unit tests for "undo leaves a merged change" and "an edit puts back
what it owned" run in a second. `change` gets 15 lines shorter.
Proof of same behavior: the self-test's undo checks (about 12), and new unit
tests that encode the two iCloud checks.
Plan: 2 commits (the type and its tests, then `change` calls it).
Why not Strong: the rule works and has no fix-log entry.

## One function per story area in the self-test  [Worth exploring]

Files: SelfTest.swift (430 lines, `run` is 380 lines)
Signal: the most changed file in 30 days (24 commits)
Problem: every story adds checks to one function. Finding the shortcut checks
means scrolling past the undo checks. A check that leaves state behind (a
todo not deleted, a mode not reset) breaks the checks after it, and the long
function hides which one.
Proposal: `run` calls one function per area, each named for its stories, each
leaving the store as it found it.

```swift
private static func run(_ m: AppModel) async {
    await checkPanelShowAndHide(m)      // S-034
    checkAddEditAndUndo(m)              // S-002 S-003 S-004 S-007 S-010
    checkKeyboardAndSelection(m)        // S-008 S-009 S-013
    await checkCompleteAndArchive(m)    // S-005 S-014 S-015 S-016
    checkAgentEntryPoints(m)
    await checkSounds(m)
    checkSync(m)
    checkMenus(m)
    checkShortcuts(m)
    checkThemesAndDock(m)
    await checkSettingsWindow(m)
}
```

Benefits: locality, because a story's checks are one function. `CLAUDE.md`
says "add a check for every story with logic", and this says where.
Proof of same behavior: the same checks pass in the same order.
Plan: 1 commit. No check changes.

## Words and pickers both apps share  [Worth exploring]

Files: App.swift (`confirmClearArchive`), iOS/Sources/ArchivePage.swift
(`clearTitle`), Settings/SettingsTabs.swift (`Swatches`),
iOS/Sources/SettingsSheet.swift (`ThemeGrid`)
Signal: drifted copies across 2 targets
Problem: "Delete 1 Completed Todo?" and its plural are written in both apps.
The Appearance picker (two tags, two titles) is written in both. The Mac
swatches set `prefs.themeID` directly while iOS and `perch theme set` go
through `themeChoice.set`, so there are two ways to pick a theme. A change to
the wording or the modes is two edits that can drift.
Proposal: the words move to the shared model, and the Mac swatches use the
same path as iOS.

```swift
extension AppModel {
    /// The question before Clear Archive, on both apps.
    var clearArchiveTitle: String {
        archived.count == 1 ? "Delete 1 Completed Todo?" : "Delete \(archived.count) Completed Todos?"
    }
}
// Shared/Theme.swift
struct AppearancePicker: View { @Bindable var prefs: Prefs; var body: some View { Picker(...) } }
```

Benefits: one wording for both apps, one way to pick a theme.
Proof of same behavior: the Archive snapshots on both apps
(`tools/snap.sh`, `tools/ios-snap.sh`), and the Match System self-test checks.
Plan: 2 commits (the title and the picker, then the swatches).

## Small moves  [Worth exploring]

Files: Panel/PanelController.swift, Settings/SettingsTabs.swift,
Shared/Models.swift, System/AppMenus.swift, Shared/Theme.swift
Signal: locality and repeated 5-line patterns
- `TrafficLights` is a SwiftUI view at the bottom of `PanelController.swift`.
  It belongs in `PanelView.swift` with `TitleBar`, which uses it.
- The "a switch, not a checkbox" Toggle with its 4 modifiers and its fix-log
  comment is written twice in Settings. A `SettingsSwitch` view writes the
  rule once.
- `AppModel.scheduleReload` and `AppMenus.ensureSoon` are the same
  "once per run loop turn" flag and `DispatchQueue.main.async`. A 10-line
  `Coalescer` in UI/ does it once.
- `NSColor(hex:)` repeats the bit math of `Color(hex:)`. `NSColor(Color(hex:))`
  does the same.
- `panelVisible`, `panelIsKey`, and `showHideTitle` are Mac panel state in the
  shared `AppModel` that iOS compiles and never reads. `#if os(macOS)`, like
  `settingsTab`, says so.
- The iOS `TodoRow` has the same name as the Mac `TodoRow`. They never compile
  together, but a search for one finds both. `ListRow` fits the iOS one.
Proof of same behavior: the panel and Settings snapshots, the self-test.
Plan: 1 commit per bullet.

## Top recommendation

Do card 1 (the tokens). It is the one card that fixes a written rule, it
touches the files that changed most this month after the self-test, and the
snapshots prove it. Then card 6 (small moves), which is cheap and raises
locality in five places. Cards 2 to 5 wait for the signal that makes them
worth it: a shortcut change, an undo bug, a self-test failure that is hard to
place, or a third target.

## Considered, not recommended

- **Fewer fetches in `change`.** Four fetches of the whole table per change.
  `records()` could be passed into `reload`, saving one. The table has tens
  of rows, and the fix-log rule "code inside a change reads the store, never
  a cached array" argues against caching.
- **Cache `Prefs.theme`.** Every `Palette` read scans 8 themes. Negligible, and
  a stored copy adds a place that can go stale.
- **`selectedIDs` per row.** Each `TodoRow` computes the selection from the
  visible ids, so a render is O(rows²). With 50 rows that is 2,500 steps.
- **Split `PanelController` (421 lines).** The show and hide transition
  (display link, 80 lines) could be a `PanelTransition` type. The file is one
  window's behavior, under every trigger, and the self-test covers it.
- **Share Settings views between Mac and iOS.** The Mac uses a grid with
  system controls, iOS a `Form`. Only the Appearance picker (card 5) is the
  same view.
- **Agent files.** They follow the bama template, as the last review said.

## Result

Open. No code changed in this review.
