# Architecture

Perch is a Swift package with an app target, a rules target, and a test target. There is no Xcode project.

## Targets

| Target | What it holds | Depends on |
|---|---|---|
| `PerchKit` | Rules and data logic with no SwiftUI or AppKit: todo text, order values, list selection, keyboard focus rules, drag reorder, panel sizes, window placement, theme choice, key combos and shortcut matching. | Foundation only |
| `Perch` | The app: SwiftData store, model, panel, Settings, menus, global shortcut, updates, agent CLI. Code runs on the main actor unless it says otherwise. | `PerchKit`, Sparkle |
| `PerchKitTests` | Unit tests for `PerchKit` (`swift test`). | `PerchKit` |

Dependencies point one way: `Perch` uses `PerchKit`, never the other way.
Logic that tests must reach without the app goes in `PerchKit`, as plain
types that take plain values.

## Layers in the app

- **Store and model** (`App.swift` `Store`, `Models.swift`). One SwiftData
  container. `AppModel` holds the todos, the focus (typing or selection),
  and every action. The panel, the menus, Settings, and the agent CLI all
  call the same `AppModel` methods.
- **Windows** (`Panel/`, `Settings/`). AppKit windows with SwiftUI content.
  The panel height comes from `PanelMetrics`. The panel springs in (`Spring`
  in PerchKit) and shrinks and fades out by setting its frame on each
  display frame, and `fit` moves the full-size frame while either runs.
- **System** (`System/`). Menus (`AppMenus`), the global shortcut
  (`Hotkey`), and Sparkle updates (`Updates`).
- **Agent** (`Agent/`). The app binary is also the `perch` command. The
  command talks to the running app over a Unix socket and runs entries from
  `AgentCommands.all` on the main actor. `perch mcp` serves the same commands
  as MCP tools.
- **Look** (`UI/`). Themes, `Palette`, `Motion`, `PanelStyle`, the Settings
  grid, and app icons. Views never hard-code colors, sizes, or durations.
- **Checks** (`SelfTest.swift`, `Snapshot.swift`, `SeedData.swift`). They
  run the real app on a store in /tmp and refuse to run without `APP_STORE`.

## Rules that keep it working

- **Every todo change goes through `AppModel.change`.** It runs the change,
  saves (and renumbers a crowded List), adds one undo step, and reloads, in
  that order. Only `restoreAll`, which is the undo step itself, saves on its
  own. See `docs/FIXLOG.md` for the bug that the order prevents.
- **Keyboard and click rules live in `FocusRules`** (PerchKit). `AppModel`
  decides when an edit ends, asks the rule where the keyboard goes, and
  applies the answer. A new key or click rule gets a unit test there.
- **Undo is a whole-list snapshot.** Each step stores `TodoRecord`s of every
  todo and puts them all back. One `UndoManager` (`AppModel.undoManager`)
  serves the panel, Settings, and agent commands, so Edit > Undo takes back
  a change an agent made.
- **Menus with live state are AppKit items** (`AppMenus`). SwiftUI rebuilds
  the Edit menu after the app becomes active and drops inserted items, so
  the windows also match those shortcuts in `performKeyEquivalent`.

## Seams

| Seam | Production | Test |
|---|---|---|
| `APP_STORE` | `~/Library/Application Support/Perch/Perch.store` and `agent.sock` | a store in /tmp and `<store>.sock` |
| `AgentCommands.all` | the CLI and MCP tools | `check-agent-cli.sh` (bama agent-cli skill) and the self-test |
| `Updates` | Sparkle with `TagVersionRules` | off when `APP_STORE` is set or the app is not bundled |
| `Hotkey` | saves the shortcut in UserDefaults | does not save when `APP_STORE` is set |
| `Prefs` | saves Settings in UserDefaults | reads them but never writes when `APP_STORE` is set |
