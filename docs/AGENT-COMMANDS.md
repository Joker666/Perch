# Agent commands

What an agent can do in Perch through `perch <noun> <verb>` and `perch mcp`. Each command runs in the running app, through the same model method as the window, so the panel updates live. Every data change registers Undo, so Edit > Undo takes back what an agent did.

| Command | Mark | Undo | Story | What it does |
| --- | --- | --- | --- | --- |
| `status` | read | | S-001, S-014 | Running, panel shown, List or Archive, todo counts, what Edit > Undo would take back, the themes and the appearance mode, global shortcut, iCloud sync on or off |
| `todos list` | read | | S-001, S-014 | Open todos in list order, or `--archived` for completed ones. `--search`, `--limit`, `--offset` |
| `todos show <id>` | read | | S-001 | One todo |
| `todos add --text` | write | yes | S-002, S-003 | Add a todo at the end, or `--after <id>`. The help asks for a short action that starts with a verb, about 60 characters or less |
| `todos update <id> --text` | write | yes | S-004 | Change a todo's text |
| `todos complete <id>` | write | yes | S-005, S-011 | Complete a todo. It moves to the Archive |
| `todos restore <id>` | write | yes | S-015 | Move a completed todo back to the end of the List |
| `todos move <id> --to <position>` | write | yes | S-012, S-013 | Move an open todo to a position, 1 for the top |
| `todos delete <id>` | destructive | yes | S-010 | Delete a todo. Only reports what it would do until `--yes` |
| `archive clear` | destructive | yes | S-016 | Delete every completed todo. Only reports until `--yes` |
| `open <list\|archive>` | write | | S-001, S-014, S-022 | Show the panel with the List or the Archive |
| `hide` | write | | S-022 | Hide the panel |
| `theme set <name> [--for light\|dark]` | write | | S-017, S-032 | Use one of the 8 themes. `--for` sets the theme for that macOS appearance |

Not commands: font, font size, radius, app icon, sound, and the global shortcut stay in Settings. They are personal taste, and agents gain little from them.
