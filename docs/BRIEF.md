# DoFloaty

A tiny floating todo list for the Mac, for people who still write their daily todos on paper. A one-to-one rebuild of FloatyDo.

Bundle id: `com.rafi.dofloaty`

## Replaces
FloatyDo, and the sticky note or piece of paper next to the keyboard.

## Main jobs
1. Write a todo fast, from the keyboard, in a small panel that floats above other windows.
2. Check off, reorder (drag), and delete todos without the mouse when you want.
3. Change the look every day: theme, font, size, corner radius, app icon.

## Data
- Todo: id, text, isCompleted, order, createdAt, completedAt.
- Settings (UserDefaults, not SwiftData): theme, font, font size, corner radius, icon, panel width and position.

## Shape
One floating panel (the list) plus a Settings window. A menu bar item. macOS 26 or later. Local data. Works offline. No accounts. (decided by the agent)

## System hooks
- Menu bar item with show/hide and quit.
- Global shortcut to show or hide the panel.
- Alternate app icons, picked in Settings.

## Reference
FloatyDo by Raffi Chilingaryan (floatydo.com). Notes in `docs/research/floatydo-reference.md`. Not installed here, so the reference is the launch videos and the landing page.

## Look
Own parts, like FloatyDo: a borderless rounded panel with 8 color themes (4 dark, 4 light), hollow circles, a row highlight, and spring motion. The Settings window uses standard Mac controls tinted by the active theme. We use our own icons and SF Symbols, not FloatyDo assets.

## Not in version one
- iPhone app and iCloud sync (later: iCloud sync).
- In-app purchases.
- Due dates, lists, tags, or notes on a todo.
