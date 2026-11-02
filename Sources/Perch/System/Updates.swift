import Foundation
import Sparkle

/// Auto updates with Sparkle. The feed is site/appcast.xml on the project
/// site (SUFeedURL in Info.plist). Test, snapshot, and unbundled runs never
/// check, so they cannot show an update window.
@MainActor
enum Updates {
    private static var controller: SPUStandardUpdaterController?

    static var isAvailable: Bool { controller != nil }

    static func start() {
        guard !Store.isOverridden, Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    static func check() {
        controller?.checkForUpdates(nil)
    }
}
