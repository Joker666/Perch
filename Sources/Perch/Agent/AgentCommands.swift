import AppKit
import Foundation
import PerchKit

/// Everything an agent can do (docs/AGENT-COMMANDS.md). The CLI, `help`, and the
/// MCP tools all read this list. Each `run` calls the same model method as the
/// window, on the main actor. `undoable` changes go to Edit > Undo.
enum AgentCommands {
    static let all: [AgentCommand] = [
        AgentCommand(name: "status", summary: "Show whether the panel is shown, List or Archive, todo counts, what Edit > Undo would take back, the themes, the global shortcut, and whether the todos sync with iCloud and get its pushes.",
                     example: "perch status --json", readOnly: true) { _, model in
            ["running": true, "panelShown": model.panelVisible, "page": model.mode.rawValue,
             "open": model.todos.count, "completed": model.archived.count,
             "theme": Prefs.shared.theme.id, "themeMode": Prefs.shared.themeMode.rawValue,
             "lightTheme": Prefs.shared.lightThemeID, "darkTheme": Prefs.shared.darkThemeID,
             "undo": model.undoManager.canUndo ? model.undoManager.undoMenuItemTitle : "nothing to undo",
             "shortcut": Hotkey.shared.combo.map { KeyNames.display($0) } ?? "off",
             "iCloud": Store.syncs ? "on" : "off", "iCloudPush": model.iCloudPush]
        },
        AgentCommand(name: "todos list", summary: "List open todos in list order, or completed ones with --archived.",
                     params: [.init(name: "archived", kind: .boolean, help: "completed todos, newest first"),
                              .init(name: "search", help: "only todos whose text contains this"),
                              .init(name: "limit", kind: .integer, help: "at most this many (default 50)"),
                              .init(name: "offset", kind: .integer, help: "skip this many, for the next page")],
                     example: "perch todos list --limit 10 --json", readOnly: true) { args, model in
            var todos = try args.bool("archived") == true ? model.archived : model.todos
            if let text = args.string("search") { todos = todos.filter { $0.text.localizedStandardContains(text) } }
            let limit = try args.int("limit", default: 50)
            let offset = try args.int("offset", default: 0)
            let page = todos.dropFirst(offset).prefix(limit)
            var result: JSONObject = ["todos": page.map { $0.agentJSON(in: model) }, "total": todos.count]
            if offset + page.count < todos.count { result["nextOffset"] = offset + page.count }
            return result
        },
        AgentCommand(name: "todos show", summary: "Show one todo, open or completed.",
                     params: [idParam], example: "perch todos show 3f2a9c1e --json", readOnly: true) { args, model in
            try find(try args.required("id"), in: model).agentJSON(in: model)
        },
        AgentCommand(name: "todos add", summary: "Add a todo at the end of the List, or after another todo. \(todoStyle)",
                     params: [.init(name: "text", required: true, help: "the todo: a short action that starts with a verb"),
                              .init(name: "after", help: "the id of the open todo to put it after")],
                     example: "perch todos add --text \"Call the dentist\" --json", undoable: true) { args, model in
            let after = try args.string("after").map { try openTodo($0, in: model).uuid }
            guard let todo = model.add(text: try args.required("text"), after: after) else {
                throw AgentError.invalid("--text cannot be empty. Example: perch todos add --text \"Buy milk\"")
            }
            return todo.agentJSON(in: model)
        },
        AgentCommand(name: "todos update", summary: "Change a todo's text. \(todoStyle)",
                     params: [idParam, .init(name: "text", required: true, help: "the new text: a short action that starts with a verb")],
                     example: "perch todos update 3f2a9c1e --text \"Call the dentist at 9\" --json", undoable: true) { args, model in
            let todo = try find(try args.required("id"), in: model)
            let text = try args.required("text")
            guard TodoText.clean(text) != nil else { throw AgentError.invalid("--text cannot be empty. To remove a todo, run `perch todos delete`") }
            let changed = model.rename(todo.uuid, to: text)
            return ["changed": changed, "todo": todo.agentJSON(in: model)]
        },
        AgentCommand(name: "todos complete", summary: "Complete a todo. It moves to the Archive.",
                     params: [idParam], example: "perch todos complete 3f2a9c1e --json", undoable: true) { args, model in
            let todo = try find(try args.required("id"), in: model)
            guard !todo.isCompleted else { return ["changed": false, "todo": todo.agentJSON(in: model)] }
            model.complete([todo.uuid], animated: false)
            return ["changed": true, "todo": todo.agentJSON(in: model)]
        },
        AgentCommand(name: "todos restore", summary: "Move a completed todo back to the end of the List.",
                     params: [idParam], example: "perch todos restore 3f2a9c1e --json", undoable: true) { args, model in
            let todo = try find(try args.required("id"), in: model)
            guard todo.isCompleted else { return ["changed": false, "todo": todo.agentJSON(in: model)] }
            model.restore([todo.uuid])
            return ["changed": true, "todo": todo.agentJSON(in: model)]
        },
        AgentCommand(name: "todos move", summary: "Move an open todo to a position in the List, 1 for the top.",
                     params: [idParam, .init(name: "to", kind: .integer, required: true, help: "the new position, 1 for the top")],
                     example: "perch todos move 3f2a9c1e --to 1 --json", undoable: true) { args, model in
            let todo = try openTodo(try args.required("id"), in: model)
            let position = try args.int("to", default: 0)
            guard (1...max(1, model.todos.count)).contains(position) else {
                throw AgentError.usage("--to must be from 1 to \(model.todos.count)")
            }
            let current = model.todos.firstIndex { $0.uuid == todo.uuid } ?? 0
            let target = position - 1
            guard target != current else { return ["changed": false, "todo": todo.agentJSON(in: model)] }
            model.move([todo.uuid], to: TodoOrder.destination(from: current, to: target))
            return ["changed": true, "todo": todo.agentJSON(in: model)]
        },
        AgentCommand(name: "todos delete", summary: "Delete a todo. Without --yes it only shows what it would delete.",
                     params: [idParam], example: "perch todos delete 3f2a9c1e --yes --json",
                     destructive: true, undoable: true) { args, model in
            let todo = try find(try args.required("id"), in: model)
            let shown = todo.agentJSON(in: model)
            guard args.confirmed else { return ["deleted": false, "wouldDelete": shown, "hint": "add --yes to delete it"] }
            model.delete([todo.uuid])  // the window's code, so Edit > Undo brings it back
            return ["deleted": true, "todo": shown]
        },
        AgentCommand(name: "archive clear", summary: "Delete every completed todo. Without --yes it only shows how many.",
                     example: "perch archive clear --yes --json", destructive: true, undoable: true) { args, model in
            let count = model.archived.count
            guard args.confirmed else { return ["deleted": 0, "wouldDelete": count, "hint": "add --yes to delete them"] }
            model.clearArchive()
            return ["deleted": count]
        },
        AgentCommand(name: "open", summary: "Show the panel with the List or the Archive, without taking the keyboard.",
                     params: [.init(name: "page", required: true, positional: true, help: "list or archive")],
                     example: "perch open archive") { args, model in
            let name = try args.required("page")
            guard let page = PanelMode(rawValue: name) else {
                throw AgentError.usage("no page \"\(name)\". Pages: list, archive")
            }
            model.mode = page
            PanelController.shared.reveal()
            return ["page": page.rawValue, "panelShown": true]
        },
        AgentCommand(name: "hide", summary: "Hide the panel.", example: "perch hide") { _, model in
            PanelController.shared.hide()
            return ["panelShown": model.panelVisible]
        },
        AgentCommand(name: "theme set", summary: "Use one of the 8 themes. Without --for it changes the theme on screen now.",
                     params: [.init(name: "name", required: true, positional: true,
                                    help: Theme.all.map(\.id).joined(separator: ", ")),
                              .init(name: "for", help: "light or dark: the theme for that macOS appearance, used with Match System")],
                     example: "perch theme set pool --for light") { args, _ in
            let name = try args.required("name").lowercased()
            guard let theme = Theme.all.first(where: { $0.id == name || $0.name.lowercased() == name }) else {
                throw AgentError.usage("no theme \"\(name)\". Themes: \(Theme.all.map(\.id).joined(separator: ", "))")
            }
            let appearance = try args.string("for").map { value in
                guard let appearance = ThemeChoice.Appearance(rawValue: value.lowercased()) else {
                    throw AgentError.usage("--for must be light or dark")
                }
                return appearance
            }
            let prefs = Prefs.shared
            prefs.themeChoice.set(theme.id, for: appearance, systemIsDark: prefs.systemIsDark)
            return ["theme": prefs.theme.id, "themeMode": prefs.themeMode.rawValue,
                    "lightTheme": prefs.lightThemeID, "darkTheme": prefs.darkThemeID]
        },
    ]

    private static let idParam = AgentCommand.Param(name: "id", required: true, positional: true,
                                                     help: "the todo's id (the first 8 characters are enough)")

    /// The panel shows one short line per todo, so agents write todos the way people do.
    static let todoStyle = "Write each todo the way people do: a short action that starts with a verb, about 60 characters or less, such as \"Send Kiran the Slack draft\". Leave out background, ids, and links. The person knows the context."

    /// A todo, open or completed, by its id or the start of it.
    static func find(_ id: String, in model: AppModel) throws -> Todo {
        let all = model.todos + model.archived
        let matches = all.filter { $0.agentID.hasPrefix(id.lowercased()) }
        guard let todo = matches.first else { throw AgentError.notFound("no todo with id \(id). Run `perch todos list`") }
        guard matches.count == 1 else { throw AgentError.usage("\(matches.count) todos start with \(id). Give more characters") }
        return todo
    }

    /// An open todo: moving or placing after needs one that is still in the List.
    static func openTodo(_ id: String, in model: AppModel) throws -> Todo {
        let todo = try find(id, in: model)
        guard !todo.isCompleted else {
            throw AgentError.invalid("todo \(id) is completed. Run `perch todos restore \(id)` first")
        }
        return todo
    }
}

extension Todo {
    /// A stable id for agents: lowercase, without dashes.
    var agentID: String { uuid.uuidString.lowercased().replacingOccurrences(of: "-", with: "") }

    @MainActor
    func agentJSON(in model: AppModel) -> JSONObject {
        var json: JSONObject = ["id": String(agentID.prefix(8)), "text": text, "completed": isCompleted,
                                "createdAt": JSON.date(createdAt)]
        if let position = model.todos.firstIndex(where: { $0.uuid == uuid }) { json["position"] = position + 1 }
        if let completedAt { json["completedAt"] = JSON.date(completedAt) }
        return json
    }
}
