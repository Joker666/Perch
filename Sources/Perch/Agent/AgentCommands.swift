import Foundation

/// Everything an agent can do in Perch. Add a command here and the CLI,
/// `help`, and the MCP tools all get it. Each `run` is on the main actor
/// with the app's model, like a button in the window.
enum AgentCommands {
    static let all: [AgentCommand] = [
        AgentCommand(name: "status", summary: "Show whether Perch runs and how many todos it has.",
                     example: "perch status --json", readOnly: true) { _, model in
            ["running": true, "open": model.todos.count, "completed": model.archived.count]
        },
    ]
}
