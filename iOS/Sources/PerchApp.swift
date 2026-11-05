import SwiftUI
import UIKit

/// The one model every screen shares. It is the same `AppModel` as on the Mac
/// (Sources/Perch/Shared), so add, edit, complete, undo, and sync work the same.
@MainActor
enum Shared {
    static let model = AppModel(container: Store.makeContainer())
}

@main
struct PerchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(Shared.model)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        SeedData.insertIfRequested(into: Shared.model)
        // iCloud tells the app about changes from other devices with a silent push.
        if Store.syncs {
            Shared.model.iCloudPush = "waiting"
            application.registerForRemoteNotifications()
            Shared.model.reloadOnSync()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Shared.model.iCloudPush = "on"
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Shared.model.iCloudPush = "failed: \(error.localizedDescription)"
    }
}
