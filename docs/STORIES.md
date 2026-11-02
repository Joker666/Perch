# Perch stories

Reference frames: `docs/research/floatydo-reference.md`. Tags: [unit] and [self] are checked in code (`swift test` or `tools/selftest.sh`), [snap] in snapshots, [manual] by hand. Snapshot pages: `panel`, `panel-editing`, `panel-selection`, `archive`, `settings-theme`, `settings-shortcuts`, `settings-icon`, `settings-about`, each in the default theme (Midnight) and one light theme (Matcha).

## M1 Core loop

### S-001 See my todos in a floating panel
As the user, I open Perch and see a small rounded panel with my todos that stays above other windows.
Screens: panel
Acceptance:
- [snap] A borderless panel, 400 pt wide, corner radius 16, traffic lights top left, List, Archive, and Settings buttons top right, no title text.
- [snap] Each todo is a 36 pt row with an 18 pt hollow circle and one line of text with an ellipsis.
- [snap] Three filler rows show below the last todo, with circles that fade out.
- [manual] The panel floats above other apps and shows on every Space.
UX:
- Flow: launch, menu bar Show Perch, or the global shortcut -> panel shows at its saved place -> List view
- Surface: panel (a tool kept open beside the work)
- States: empty shows only the 3 filler rows (the first one says nothing; clicking it adds a todo); too much: long text truncates with the full text in a tooltip
- Words: tooltips "Show your todos (⌘1)", "Show completed todos (⌘2)", "Change the theme, font, and icon (⌘,)"
- Access: VoiceOver reads each row as "<text>, todo" with a Complete action; toolbar buttons have labels List, Archive, Settings
Status: done

### S-002 Add a todo by clicking a filler row
As the user, I click the first filler row and type a todo.
Screens: panel-editing
Depends: S-001
Acceptance:
- [snap] The new row shows a caret and the highlight.
- [unit] Ending the edit with text saves a Todo at the end of the list. Ending it with no text saves nothing.
- [self] The panel grows by one row height.
UX:
- Flow: click a filler row or press ⌘N -> new row with caret -> type -> Return saves and opens the next row, Escape saves and stops
- Surface: inline row (changes one value on screen)
- States: an empty edit that ends saves nothing, with no message
- Words: no placeholder text, as in the reference; VoiceOver "New todo"
- Access: ⌘N adds from anywhere in the panel
Status: done

### S-003 Insert a todo below with Return
As the user, I press Return while I edit a row, and a new empty row opens right below it.
Depends: S-002
Acceptance:
- [unit] The new todo's order is between the current row and the next one.
- [self] The caret moves to the new row.
- [unit] Return on an empty row ends editing and removes that row.
UX:
- Flow: editing a row -> Return -> empty row below with caret -> Return again on the empty row ends editing
- Surface: inline row
- States: none beyond the empty row
- Words: none on screen; Edit menu "Undo Add Todo"
- Access: keyboard only by design
Status: done

### S-004 Edit a todo in place
As the user, I click a todo's text and change it.
Depends: S-001
Acceptance:
- [self] The text field is in the row, not in a sheet. Escape ends the edit and keeps the text.
- [unit] Clearing all the text and ending the edit deletes the todo.
UX:
- Flow: click the text, or select and press Return -> caret at the end -> type -> Return or Escape or click away saves
- Surface: inline row
- States: empty text on save deletes the todo, Command-Z brings it back
- Words: Edit menu "Undo Edit Todo", "Undo Delete Todo"
- Access: VoiceOver "Edit todo text"
Status: done

### S-005 Complete a todo
As the user, I click a todo's circle to mark it done.
Depends: S-001
Acceptance:
- [snap] The circle shows a check and a line sweeps across the text in 0.25 s.
- [self] The row collapses in 0.35 s and the panel shrinks.
- [unit] The todo gets isCompleted and completedAt, and shows in the Archive.
UX:
- Flow: click the circle, or select and press ⌘Return -> check and strikethrough -> row collapses -> todo is in the Archive
- Surface: inline (the circle is the control)
- States: done feedback is the check and the sweep in the same frame; Command-Z restores
- Words: circle tooltip "Complete this todo (⌘↩)"; Edit menu "Undo Complete Todo"
- Access: Reduce Motion replaces the sweep and collapse with a fade; VoiceOver action "Complete"
Status: done

### S-006 Panel height fits the content
As the user, I never resize the panel to see my todos. It grows and shrinks on its own.
Depends: S-001
Acceptance:
- [unit] Height = title bar + rows × 36 + 3 fillers × 36 + padding.
- [manual] When I drag the bottom edge, the panel springs back to the fitted height. Width changes stay (320 to 520 pt).
UX:
- Flow: any add, delete, or complete -> panel height animates to fit (0.22 s)
- Surface: panel
- States: never shows a scroll bar until the panel reaches the screen height, then scrolls
- Words: none
- Access: Reduce Motion sets the height with no spring
Status: done

### S-007 Todos survive a restart
As the user, I quit and reopen, and my todos and their order are the same.
Depends: S-002
Acceptance:
- [unit] Todos persist in SwiftData and load sorted by order.
- [manual] The panel position and width persist.
Status: done

## M2 Keyboard and order

### S-008 Move the selection with the arrow keys
As the user, I press Up and Down to move the highlight between todos, and Return to edit the selected one.
Screens: panel-selection
Depends: S-004
Acceptance:
- [self] Down from the last todo moves to the first filler row, which starts a new todo on Return.
- [snap] The selected row has the theme highlight.
Status: done

### S-009 Select several todos with Shift
As the user, I press Shift-Up or Shift-Down to extend the selection, or Shift-click a row.
Screens: panel-selection
Depends: S-008
Acceptance:
- [snap] Every selected row shows the highlight.
- [unit] The selection is a contiguous range anchored at the first row.
Status: done

### S-010 Delete selected todos and undo it
As the user, I press Delete to remove the selected todos, and Command-Z to bring them back.
Depends: S-009
Acceptance:
- [unit] Delete removes all selected todos. Undo puts them back in the same places.
- [self] The panel shrinks and grows to match.
Status: done

### S-011 Complete the selected todos from the keyboard
As the user, I press Command-Return to complete the selected todos.
Depends: S-005, S-009
Acceptance:
- [unit] Every selected todo is completed. Command-Z undoes it.
Status: done

### S-012 Reorder a todo by dragging
As the user, I drag a todo up or down and the other rows slide out of the way.
Depends: S-001
Acceptance:
- [manual] Rows move in 0.16 s while I drag. The dragged row keeps its highlight.
- [unit] Dropping writes the new order.
Status: done

### S-013 Reorder with the keyboard
As the user, I press Command-Option-Up or Command-Option-Down to move the selected todos.
Depends: S-009
Acceptance:
- [unit] The selected block moves one row and keeps its selection.
Status: done

## M3 Archive

### S-014 See completed todos in the Archive
As the user, I click the Archive button and see my completed todos, newest first.
Screens: archive
Depends: S-005
Acceptance:
- [snap] Checked circles, dimmed text with a strikethrough. The Archive button is the active one.
- [snap] With no completed todos, the panel shows "Nothing completed yet" in secondary text.
Status: done

### S-015 Restore a completed todo
As the user, I click a checked circle in the Archive and the todo goes back to the end of my list.
Depends: S-014
Acceptance:
- [unit] isCompleted is false, completedAt is nil, order is last.
Status: done

### S-016 Clear the Archive
As the user, I choose Clear Archive and every completed todo is deleted after I confirm.
Depends: S-014
Acceptance:
- [self] A confirmation alert names how many todos it deletes. Command-Z undoes it.
Status: done

## M4 Customize

### S-017 Pick a theme
As the user, I pick one of 8 color swatches in Settings > Theme and the panel changes at once.
Screens: settings-theme
Acceptance:
- [snap] The swatch capsule shows Midnight, Navy, Forest, Plum, Pool, Blossom, Matcha, Sand. The chosen one has a dot.
- [snap] The panel and the Settings window both use the theme colors.
Status: done

### S-018 Pick a font
As the user, I pick System, Rounded, Serif, or Monospaced in Settings > Theme.
Screens: settings-theme
Acceptance:
- [snap] The panel text uses the chosen design. Reset returns to System.
Status: done

### S-019 Change the font size
As the user, I drag the Font Size slider (11 to 18 pt, with ticks) and the rows update.
Screens: settings-theme
Acceptance:
- [snap] The value label shows "14 pt" by default. Row height scales with the size. Reset returns to 14.
Status: done

### S-020 Change the corner radius
As the user, I drag the Radius slider (0 to 24 px) and the panel corners update.
Screens: settings-theme
Acceptance:
- [snap] The value label shows "16 px" by default. Reset returns to 16.
Status: done

### S-021 Pick an app icon
As the user, I pick one of the 8 theme icons in Settings > Icon.
Screens: settings-icon
Acceptance:
- [snap] Each row has a radio circle, the icon, its name, and "Current icon" under the active one.
- [manual] The Dock icon changes at once (NSApp.applicationIconImage) and after a restart.
Status: done

## M5 System

### S-022 Show and hide from the menu bar
As the user, I click the checkmark icon in the menu bar to show or hide the panel, add a todo, open Settings, or quit.
Acceptance:
- [manual] The menu has Show Perch / Hide Perch, New Todo, Settings…, Quit Perch.
Status: done

### S-023 Show and hide with a global shortcut
As the user, I press Control-Option-Space anywhere to show the panel and focus a new todo, and press it again to hide it.
Screens: settings-shortcuts
Acceptance:
- [manual] Works when another app is frontmost.
- [snap] Settings > Shortcuts lists the global shortcut and the in-panel keys.
Status: done

### S-024 About tab
As the user, I open Settings > About and see the icon, name, and version, and check for updates.
Screens: settings-about
Acceptance:
- [snap] Icon, "Perch", "Version <tag> (<build>)", a one-line credit, and Check for Updates.
Status: done

### S-028 Change the global shortcut
As the user, I click the shortcut in Settings > Shortcuts and press a new combination to show and hide Perch.
Screens: settings-shortcuts
Depends: S-023
Acceptance:
- [self] A new shortcut registers at once and is saved. Reset brings back ⌃⌥Space.
- [self] A key with no ⌘, ⌥, or ⌃ is refused, unless it is a function key.
- [self] A combination that is a Perch menu item, like ⌘N, is refused with the item's name.
- [manual] A combination another app owns is refused, and the old shortcut stays.
- [self] Escape cancels recording. Delete turns the shortcut off.
UX:
- Flow: Settings > Shortcuts -> click the shortcut -> "Press a shortcut" -> press keys -> the new shortcut shows, or a reason under it
- Surface: inline control (changes one value on screen)
- States: recording "Press a shortcut"; off "Off"; refused, with the reason in the caption; another app owns it
- Words: "Press a shortcut", "Reset", "Add ⌘, ⌥, or ⌃ to F, so it does not take the key from other apps."
- Access: VoiceOver "Show or hide Perch shortcut, ⌃⌥Space"
Status: done

### S-029 Get updates
As the user, I get a new version of Perch without going to the website.
Depends: S-024
Acceptance:
- [manual] Perch checks the appcast on its own, and Check for Updates in the Perch menu and Settings > About checks now.
- [manual] An update is offered only for a newer version tag. The update window shows the release notes, not a web page.
Status: done

### S-030 Let agents work with my todos
As the user, I ask Claude Code to list, add, or complete my todos, and the panel changes at once.
Acceptance:
- [self] Agent commands use the same model methods as the panel, with one undo step each.
- [manual] `check-agent-cli.sh` passes. One Edit > Undo takes back a delete made with `perch`.
- Commands: `docs/AGENT-COMMANDS.md`.
Status: done

## M6 Polish

### S-025 Context menu on a todo
As the user, I right-click a todo and choose Complete, Edit, or Delete.
Acceptance:
- [manual] Each item does the same as its key and shows the key in the menu.
Status: done

### S-026 Hover highlight
As the user, I hover a row and it shows a faint highlight (60% of the selection) that fades in 0.14 s.
Acceptance:
- [manual] Filler rows have no hover highlight.
Status: done

### S-027 Rubber band at the minimum size
As the user, I drag the panel narrower than 320 pt and it stretches with resistance, then springs back.
Depends: S-006
Acceptance:
- [manual] Release springs to the nearest allowed size with the snappy curve.
Status: done

### S-031 Hear a todo get completed
As the user, I complete a todo and hear a short click, like a key switch.
Screens: settings-theme
Acceptance:
- [self] Completing in the panel (circle, ⌘↩, or the context menu) plays the sound. An agent's `perch todos complete` plays none.
- [snap] Settings > Theme has a Sound switch, on by default. Its help says "Play a sound when you add or complete a todo".
- [manual] No sound when macOS has "Play user interface sound effects" off.
UX:
- Flow: click the circle -> check, click, and sweep together
- Surface: feedback only, no window
- Words: Settings label "Sound", and the switch's help "Play a sound when you add or complete a todo"
- Access: the sound adds to the check and the sweep, so nothing depends on hearing it
Status: done

### S-033 Hear a todo get added
As the user, I save a new todo and hear one quiet tick, different from the completion click.
Depends: S-031
Acceptance:
- [self] Saving a new todo with text in the panel (Return, Escape, or a click away) plays the add sound.
- [self] A new row left empty plays no sound. An agent's `perch todos add` plays none.
- [manual] The Sound switch in Settings > Theme turns off this sound and the completion sound.
Status: done

### S-032 Match the macOS appearance
As the user, I pick one theme for macOS Light and one for macOS Dark, and Perch switches with macOS.
Screens: settings-theme, settings-theme-system
Acceptance:
- [self] With Match System, Perch shows the Light theme when macOS is Light and the Dark theme when it is Dark, and its controls follow the theme.
- [self] With One Theme, macOS's appearance changes nothing.
- [unit] `perch theme set --for light|dark` changes that slot. Without `--for` it changes the theme on screen now.
- [snap] Settings > Theme has Appearance (One Theme, Match System). Match System shows Light and Dark swatch rows. All 8 themes are in each row.
- [manual] When macOS switches, also with Auto, Perch switches at once.
UX:
- Flow: Settings > Theme > Appearance > Match System -> pick a Light theme and a Dark theme
- Surface: inline control in the Theme tab
- States: One Theme (the theme as before); Match System (Light and Dark rows, defaults from the one theme)
- Words: "Appearance", "One Theme", "Match System", "Light", "Dark"; help "Use the Pool theme when macOS is Light"
- Access: the segmented control and each swatch have labels
Status: done

## Dropped
- iPhone app and iCloud sync: one user, one Mac for now (later: iCloud sync).
- In-app purchases: vendor only.
- Due dates, lists, tags, notes: FloatyDo leaves them out on purpose.
