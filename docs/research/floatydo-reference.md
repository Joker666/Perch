# FloatyDo reference notes

Sources: floatydo.com (HTML and CSS), the launch thread by @raffichill (6 demo videos, Apr 9 2026), and the Mac App Store listing (v1.4.0). FloatyDo is not installed on this Mac, so these notes come from video frames and the landing page CSS. We use our own name (Perch), our own icons, and SF Symbols. We do not copy FloatyDo assets.

## Pitch

A miniature todo list with as few features and as much craft as possible. Keyboard-first, lightweight, customizable. It floats in a corner of the screen. For quick daily todos, not for projects or scheduling.

## Main window (the floating list)

- Small panel, about 400 pt wide (min 320, max 520). It floats above other windows.
- Big corner radius (default 16 px, adjustable in Settings up to about 18).
- Title bar: traffic lights on the left. Three toolbar buttons on the right: List (active todos), Archive (completed todos), Settings (gear).
- No window title text.
- Rows: 36 pt high, an 18 pt hollow circle, then the text in one line with ellipsis. Text inset 8 pt. Row highlight inset 8 pt from the panel edges, corner radius 10.
- Below the last todo there are always 3 "filler" rows: hollow circles only, fading (opacity 0.5, 0.4, 0.3 for the circles). Clicking a filler row starts a new todo.
- The height of the window always fits the content (todos + fillers). Adding a row grows the window. Removing a row shrinks it.
- The user can drag the window edges. Width changes stay. Height snaps back to fit the content with a rubber-band spring (the thread says this is from Things). Content clips while the user drags it too small.

## Input and keyboard logic

- Click a row to edit its text in place (caret visible, row highlighted).
- Return on a row inserts a new empty row directly below it and moves the caret there.
- Return on an empty row ends editing (empty rows are removed).
- Up and Down arrows move the selection between rows.
- Shift+Up and Shift+Down extend the selection (several rows highlighted at once).
- Delete on a selection removes those rows. Undo brings them back.
- Click the circle to complete a todo. The circle shows a check, the text gets a strikethrough sweep (0.25 s), then the row collapses (0.35 s) and the window shrinks. The completed todo goes to the Archive.
- Drag a row to reorder. Other rows slide out of the way (0.16 s). The dragged row keeps its highlight.

## Archive view

- The Archive toolbar button swaps the list for completed todos: checked circles, text struck through and dimmed.
- The selected row stays highlighted. A completed todo can be restored (uncheck).

## Settings window

Separate standard window titled with the app name. Toolbar tabs with icons: Theme, Shortcuts, Icon, About. The Settings window takes the active theme colors too.

Theme tab:

- Background: a capsule with 8 color swatches. The selected swatch shows a dot.
- Font: popup (System, Rounded, Serif/New York, Monospaced) with Reset.
- Font Size: slider with tick marks, value label in pt (default 14 pt), Reset.
- Radius: slider, value label in px (default 16 px), Reset.

Icon tab: a list of app icons, one per theme (names seen: Blossom, Matcha, Sand, Pool). Each row has a radio circle, the icon, the name, and "CURRENT ICON" under the active one. Footer: "Restart to apply the selected icon."

Shortcuts tab: not visible in the videos. We will list the in-app keys and a global shortcut to show or hide the panel.

About tab: not visible. We will show icon, name, version, and credits.

## Menu bar

A checkmark-in-a-box icon in the menu bar (visible in every video).

## Themes (from the landing page CSS)

| Theme | Surface (window) | Highlight (row) | Text | Page/swatch |
| --- | --- | --- | --- | --- |
| Midnight (theme1) | #14141F | #454554 | #FFFFFF | #262636 |
| Navy (theme2) | #1B2130 | #3E475C | #FFFFFF | #2A354E |
| Forest (theme3) | #1F2724 | #3A4943 | #FFFFFF | #2A4F41 |
| Plum (theme4) | #2A1E28 | #523E47 | #FFFFFF | #492844 |
| Pool (theme5) | #DCEFFC | #B6D9F0 | #092539 | #8DACC2 |
| Blossom (barbie) | #F2D1E1 | #E9B7CF | #240313 | #CFA6BA |
| Matcha | #CFDDB5 | #BAC99F | #1E2E00 | #809952 |
| Sand (nasaOrange) | #E6E0D6 | #D3CBBE | #41392B | #C8C0B2 |

Derived colors per theme, all from the text color: secondary text 72% opacity, selection overlay 15%, strikethrough 60%, circle border 22%, filler circle 6% (the app uses the text color at 22% fading by row), caret 95%.

## Motion (from the CSS)

- Completion sweep 0.25 s, check swap delay 0.1 s, settle 0.6 s.
- Row collapse 0.35 s, reflow 0.22 s, drag reorder 0.16 s, hover fade 0.14 s.
- Easing: snappy cubic-bezier(.175, .885, .32, 1.1), smooth cubic-bezier(.19, 1, .22, 1).

## Out of scope for the Mac clone (for now)

- iPhone app and iCloud sync (added in later versions).
- In-app purchases.
