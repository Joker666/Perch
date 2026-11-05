# Fix log

Bugs that were hard to find, and the rule each one taught. Newest first.

## 2026-11-04: The picked app icon went back to Midnight

Rafi picked the Pool icon, and the Dock showed Midnight again later. Perch set
the icon only on the running process (`NSApp.applicationIconImage`), at launch
and when picked. Anything that makes a new Dock tile shows the bundle icon: a
new build or a Sparkle update over the running app, a Dock restart, and the new
"Show Perch in Dock" switch. While Perch is quit, the Dock showed the bundle icon too.
Fix: Perch applies the icon again when it becomes active and after the Dock
switch. A Dock tile plug-in (`DockTile/`, built by build.sh) shows the picked
icon while Perch is quit. The drawn icons are cached, but never an empty image,
which SwiftUI can return early at launch.
While testing, the Dock listed Perch with a blank tile after many reinstalls.
`killall Dock` fixed it. That was the Dock's state, not Perch.

Rule: A runtime Dock icon is lost whenever the Dock makes a new tile. Apply it
again on activation, and never cache an image that did not draw.

## 2026-11-02: Settings did not open

Rafi reported that Settings did not open. The window was open but 1 pt wide.
An animated tab change had set the Settings host's `sizingOptions` to `[]`, so
SwiftUI no longer gave the window a size. The frame autosave ("Settings") then
stored the zero-width frame, and every later open used it.
Fix: the host is back on `sizingOptions = [.preferredContentSize]`, and the
self-test checks that the window opens 520 pt wide.

Rule: The Settings window takes its size from its content. Never turn off
`.preferredContentSize` on its host, because the autosave keeps a bad frame.

## 2026-11-02: The self-test failed after Rafi changed his shortcut

"The global shortcut starts as ⌃⌥Space" failed after the shortcut was set to
⌥Space in the real app. Test runs never saved the shortcut, but they still read
the saved one from the real app's settings.
Fix: in a test run, `Hotkey` starts from the default and never reads the saved shortcut.

Rule: A test run neither reads nor writes a setting that a check depends on.

## 2026-11-02: A checkbox crashed the Settings window

A SwiftUI checkbox (`.toggleStyle(.checkbox)`) in Settings > Theme crashed
Perch with "more Update Constraints in Window passes than there are views in
the window". The Settings window takes its height from its content. Plain text
in the same row worked, and the checkbox crashed inside the grid and outside it.
`.fixedSize()` and `.gridCellUnsizedAxes` did not help. Found by `tools/snap.sh`.
Fix: a small switch (`.toggleStyle(.switch)`) works.

Rule: After a new control in Settings, run `tools/snap.sh` before you commit. A layout loop shows only when the window opens.

## 2026-11-02: build.sh failed after an edit to a comment

After an edit that changed only a comment, SwiftPM did not relink the binary,
because the compiled code was the same. build.sh saw a source file newer than
the binary and reported a failed build. Found while adding a `// grid: ok` note.
Fix: when the binary looks older, build.sh builds again, and fails only when
that build prints an error.

Rule: A check that compares file dates must allow a build that had nothing to do.

## 2026-11-02: Many adds at one spot put todos in the wrong order

After about 30 adds in one place (Return in the middle of the List, or
`perch todos add --after`), new todos went to the wrong position. `save()`
renumbered the cached `todos` array, which every caller reloads only after
saving. The todo just added was not in it, so it kept its old order value
while the others got new ones. Found during the 2026-11-02 architecture review.
Fix: `save()` fetches the open todos again before it checks and renumbers them.
Check: self-test "40 adds at one spot keep their order".

Rule: Code that runs inside a change reads the store, never an array that is
reloaded after the change.
