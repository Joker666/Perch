# Fix log

Bugs that were hard to find, and the rule each one taught. Newest first.

## 2026-11-07: The iPhone app died at launch

TestFlight 0.1.7 died at launch on iOS 27.2 beta but not the iOS 27.0 simulator.
Match System with a dark theme in the Light slot and a light theme in the Dark
slot created a feedback loop: the window scene's appearance followed the app's
`preferredColorScheme`, so each theme selected the other. TestFlight recorded
no crash; device reports showed `0x8BADF00D`, a 20-second scene-create watchdog.

Fix: read appearance from `UIWindowScene.screen`, update `systemIsDark` only
when changed, and reread on activation because the overridden scene reports no
system trait change. A system switch while the app stays active takes effect
on the next activation.

Rule: Read system appearance from something the app cannot override. For a
device-only launch failure, pull the phone's reports with
`xcrun devicectl device copy from --domain-type systemCrashLogs`.

## 2026-11-07: Quick Add jumped at the bottom while opening

New Todo inserted its row after showing the panel, so the row-count observer
retargeted the appearance spring and the bottom jumped. Ending an edit before
hiding caused the reverse jump. A running `panel.animator()` resize also
overwrote directly set frames on its next tick, even while hidden.

Fix: finish a pending hide, insert the row without animation, then fit and lay
out the hidden panel before showing it. Keep the editing row until off screen,
end the edit there without animation, and leave a fading panel alone in `fit`.
Adding while visible ends any appearance spring before growing. Before a
transition or direct frame change, `endResizeAnimation` ends the resize at its
target.

Rule: Prepare rows and height before appearance, preserve them through hide,
and end animator resizes before setting frames directly.
Check: the self-test covers the first frame and deferred observer target when
hidden or interrupting a hide, and the hidden frame after a fade.

## 2026-11-04: The picked app icon went back to Midnight

`NSApp.applicationIconImage` applied the picked icon only to the running
process. New Dock tiles (after updates, Dock restarts, or the Dock visibility
switch) and tiles while quit showed the bundle icon.

Fix: reapply on activation and after the Dock switch. `DockTile/`, built by
`build.sh`, shows the picked icon while quit.

Rule: A new Dock tile loses the runtime icon. Reapply it, and never cache an
empty icon image, which SwiftUI can return early at launch.

## 2026-11-02: Settings did not open

An animated tab change set the host's `sizingOptions` to `[]`. Settings opened
1 pt wide, and frame autosave preserved the bad size on later opens.

Rule: Keep `sizingOptions = [.preferredContentSize]` on the content-sized
Settings host. Check: the self-test verifies a 520 pt opening width.

## 2026-11-02: The self-test failed after a shortcut change

The default-shortcut check failed after the real app's shortcut changed.
Test runs did not save the shortcut but still read the saved value.
Fix: `Hotkey` starts from the default in test runs.

Rule: A test run neither reads nor writes a setting that a check depends on.

## 2026-11-02: A checkbox crashed the Settings window

A `.toggleStyle(.checkbox)` control caused a constraint-layout loop in the
content-sized Settings window, inside or outside the grid. `.fixedSize()` and
`.gridCellUnsizedAxes` did not help. Fix: use `.toggleStyle(.switch)`.

Rule: After a new control in Settings, run `tools/snap.sh` before you commit.
A layout loop shows only when the window opens.

## 2026-11-02: build.sh failed after an edit to a comment

SwiftPM did not relink after a comment-only edit, so `build.sh` mistook a newer
source timestamp for a failed build. Fix: rebuild when the binary looks older,
and fail only when that build prints an error.

Rule: A check that compares file dates must allow a build that had nothing to do.

## 2026-11-02: Many adds at one spot put todos in the wrong order

After about 30 adds at one position, `save()` renumbered the cached `todos`
array before reload. It omitted the newly inserted todo, leaving its order
value inconsistent. Fix: fetch open todos from the store before renumbering.
Check: self-test "40 adds at one spot keep their order".

Rule: Code that runs inside a change reads the store, never an array that is
reloaded after the change.
