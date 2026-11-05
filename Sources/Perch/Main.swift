import Foundation

/// Starts the CLI when there is a command after the app's name, else the app.
/// `--cloudkit-schema` makes the iCloud schema and quits (CloudKitSchema.swift).
/// `--ios-icons <dir>` writes the iOS app's alternate icons and quits (IOSIcons.swift).
@main
enum Main {
    static func main() {
        if CloudKitSchema.requested { exit(CloudKitSchema.run()) }
        if IOSIcons.requested { exit(IOSIcons.run()) }
        if let code = AgentCLI.runIfRequested() { exit(code) }
        PerchApp.main()
    }
}
