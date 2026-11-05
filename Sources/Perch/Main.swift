import Foundation

/// Starts the CLI when there is a command after the app's name, else the app.
/// `--cloudkit-schema` makes the iCloud schema and quits (CloudKitSchema.swift).
/// `--ios-icons <dir>` and `--dock-icons <dir>` write the theme icons and quit (IconExport.swift).
@main
enum Main {
    static func main() {
        if CloudKitSchema.requested { exit(CloudKitSchema.run()) }
        if IconExport.requested { exit(IconExport.run()) }
        if let code = AgentCLI.runIfRequested() { exit(code) }
        PerchApp.main()
    }
}
