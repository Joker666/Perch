# Architecture review, 2026-11-02

Perch has 4,004 lines of Swift. The largest file is `Models.swift` (443 lines),
and no file or type passes a size trigger. The agent CLI work touched 9 files
in 2 targets, which is the signal for this check-in. The review found one real
bug, and it comes from the same duplication that card 2 removes.

## Renumbering uses the list from before the change  [Strong]

Files: Sources/Perch/Models.swift (`save()`, lines 436 to 442)
Signal: a bug found during the survey
Problem: `save()` checks `TodoOrder.isCrowded` on `todos` and renumbers `todos`,
but every caller reloads `todos` only after `save()`. A todo that was just added
is not in that array yet, so it keeps its old order value after the others
are renumbered.
Reproduced on a /tmp store. I added A and B, then added 40 todos, each one
after the one before. Expected: `A n1 … n40 B`. Result:
`A n40 n39 … n31 n1 n2 … n30 B`. In the panel, about 30 presses of Return in
the middle of the List do the same.
Proposal: renumber from a fresh fetch of the open todos, after the change is
saved, not from the cached array.

```swift
private func save() {
    try? context.save()
    let open = openTodosInOrder()   // fetched, not the cached `todos`
    guard TodoOrder.isCrowded(open.map(\.order)) else { return }
    for (todo, order) in zip(open, TodoOrder.renumbered(count: open.count)) { todo.order = order }
    try? context.save()
}
```

Benefits: the List keeps its order however many todos you add in one place.
Proof of same behavior: a new self-test check that adds 40 todos at one spot
and expects `A n1 … n40 B` (it fails today). The 47 self-test checks and
`check-agent-cli.sh` still pass.
Plan: 1 commit (the fix, the self-test check, and a FIXLOG entry).

## One write path for todo changes  [Strong]

Files: Sources/Perch/Models.swift
Signal: one feature (the agent CLI) touched 9 files in 2 targets, and the bug
above comes from the repeated write steps
Problem: 10 methods (`add`, `add(text:)`, `rename`, `commitEditing`,
`finishCompleting`, `restore`, `delete`, `move`, `clearArchive`, `restoreAll`)
each repeat the same steps by hand: take `records()`, change the todos,
`save()`, `registerUndo`, `reload()`. There are 24 calls to `records()` and
`registerUndo` in the file. The order of these steps matters (the bug above),
and a new command can forget one. For example, the CLI's `rename` had to copy
the steps from `commitEditing`.
Proposal: one private method does the steps in the right order. Each public
method only says what changes.

```swift
/// One change to the todos: saves, renumbers when crowded, reloads, and adds
/// one undo step named `undoName` that puts back `start` (the list now by default).
/// With `undoName` nil, the change joins an edit that is still open.
private func change(_ undoName: String?, from start: [TodoRecord]? = nil,
                    _ body: (ModelContext) -> Void)
```

Benefits: locality, because the save, renumber, undo, and reload order lives
in one place. Leverage, because each mutator gets shorter, and a new agent
command cannot skip undo or reload.
Proof of same behavior: the 47 self-test checks (most are undo and order
checks), `check-agent-cli.sh`, and the Edit > Undo test with a CLI delete.
Plan: 2 commits. First add `change` and move `add(text:)`, `rename`, `restore`,
and `clearArchive`, the simple ones. Then move the rest, which have the
`editStart` cases.

## Focus rules as plain values in PerchKit  [Worth exploring]

Files: Sources/Perch/Models.swift (`editNeighbor`, `extendSelection`,
`moveCursor`, `click`, `deleteEmptyRow`, about 80 lines)
Signal: pure logic inside a `@MainActor` store
Problem: these rules only read the visible ids, the focus, and the page, and
return a new focus. They sit on `AppModel`, so only the in-app self-test can
check them, not `swift test`.
Proposal: a `FocusRules` type in PerchKit that takes `[ID]`, `PanelFocus`, and
the page, and returns the new focus plus whether to commit the edit first.
`AppModel` applies the result.
Benefits: unit tests for keyboard behavior that run in 1 second without the app.
Proof of same behavior: the 8 keyboard checks in the self-test.
Plan: 2 commits (move `PanelFocus` and the rules, then the unit tests).
Why not Strong: the rules call `commitEditing` between steps, so the
interface needs a design pass, and keyboard bugs have not come up yet.

## Top recommendation

Do card 1, then card 2. Card 1 fixes a bug that users can hit. Card 2 moves
the fixed write steps into one place, so this kind of bug cannot come back.

## Considered, not recommended

- **Split UI state out of `AppModel`** (`settingsTab`, `panelVisible`,
  `panelIsKey`). Three small values that change rarely, and few views read
  them. A split adds a type and gains nothing.
- **Split `PanelController`** (316 lines). It is one window's behavior,
  under every trigger.
- **Agent files** (`AgentCore`, `AgentSocket`, `AgentCLI`, `AgentMCP`). They
  come from the bama template. Changes made here would drift from the skill.
- **Self-test and snapshot code in the app target.** This is how bama tests
  work. Both refuse to run without `APP_STORE` in /tmp.
- No drifted `private struct` copies were found. `Sources/DoFloaty` shows up
  in the git log only from before the rename.

## Note

There is no `ARCHITECTURE.md` yet. The refactor step adds one.

## Result

Rafi chose cards 1 and 2. Both are done:

- `c5b2ac3` fixes the renumbering, with the self-test check and a FIXLOG entry.
- `e611726` adds `change` and moves `add(text:)`, `rename`, `restore`, and `clearArchive`.
- `eda4b50` moves `add(after:)`, `commitEditing`, `finishCompleting`, `delete`, and `move`.

One difference is on purpose: a change that leaves the todos as they were no
longer adds an empty undo step. `restoreAll` still saves on its own, because
it is the undo step and must always register Redo. Before and after, the 48
self-test checks, `check-agent-cli.sh`, 12 unit tests, and the grid lint pass.
Card 3 stays open.
