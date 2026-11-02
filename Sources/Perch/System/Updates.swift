import Foundation
import Sparkle

/// Auto updates with Sparkle. The feed is site/appcast.xml on the project
/// site (SUFeedURL in Info.plist). Test, snapshot, and unbundled runs never
/// check, so they cannot show an update window.
@MainActor
enum Updates {
    private static var controller: SPUStandardUpdaterController?
    private static let rules = TagVersionRules()

    static var isAvailable: Bool { controller != nil }

    static func start() {
        guard !Store.isOverridden, Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: rules, userDriverDelegate: nil)
    }

    static func check() {
        controller?.checkForUpdates(nil)
    }
}

/// Offers an update only for a newer version tag. Sparkle compares build
/// numbers by default, and every build has a new one (a timestamp), so a
/// local build of 0.1.0 would be offered the released 0.1.0.
private final class TagVersionRules: NSObject, SPUUpdaterDelegate {
    func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let compare = SUStandardVersionComparator.default
        let newer = appcast.items.filter { item in
            item.minimumOperatingSystemVersionIsOK && item.maximumOperatingSystemVersionIsOK
                && compare.compareVersion(item.displayVersionString, toVersion: current) == .orderedDescending
        }
        let best = newer.max { compare.compareVersion($0.displayVersionString, toVersion: $1.displayVersionString) == .orderedAscending }
        return best ?? SUAppcastItem.empty()
    }
}
