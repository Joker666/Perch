---
name: perch
description: Drive the Perch app on this Mac from the shell with the `perch` command: list, add, change, complete, reorder, and delete the user's todos, and show or hide the floating panel. Use when the user asks about their todos or today's list, wants to add or change one, or names Perch.
---

# Perch

`perch` runs commands in the Perch app, a small floating todo list. Changes
show in its panel at once. If Perch is closed, the command opens it in the
background.

## Rules

- Always add `--json` and read the JSON. Exit 0 is ok. Otherwise read
  `error.code` and `error.message`, and do what the message says.
- Write a todo like a person does: a short action that starts with a verb,
  about 60 characters or less ("Send Kiran the Slack draft"). Leave out
  background, ids, and links. The panel shows one short line per todo.
- Find ids with `perch todos list --json`, or `--search`. An id is 8 characters.
- Destructive commands (`todos delete`, `archive clear`) only report what
  they would do. Show the user that report and ask before you run them
  again with `--yes`.
- Every change can be undone in Perch with Edit > Undo. `perch status --json`
  says what Undo would take back.
- To try something without real data, add `APP_STORE=/tmp/perch-test.store`
  in front of the command.

## Main commands

| Command | Does |
| --- | --- |
| `perch status --json` | Panel shown, List or Archive, counts, what Undo would take back |
| `perch todos list [--archived] [--search T] [--limit N] --json` | Open todos in order, or completed ones |
| `perch todos add --text T [--after ID] --json` | Add a todo at the end, or after another |
| `perch todos complete ID --json` | Complete a todo. It moves to the Archive |
| `perch todos update ID --text T --json` | Change a todo's text |
| `perch todos move ID --to N --json` | Move an open todo to position N, 1 for the top |
| `perch open list` or `perch open archive` | Show the panel without taking the keyboard |

Everything else: `perch help`, and `perch help <command>` for its options.
