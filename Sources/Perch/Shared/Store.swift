import Foundation
import SwiftData
#if os(macOS)
import Security
#endif

/// Where the data lives: ~/Library/Application Support/Perch/Perch.store, copied to
/// iCloud when the build has the iCloud entitlement (docs/ICLOUD.md).
enum Store {
    #if os(macOS)
    /// The iCloud container from the app's entitlements. build.sh adds them only when it
    /// has a provisioning profile with iCloud. Without them the todos stay on this Mac.
    static let iCloudContainer: String? = {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil)
        else { return nil }
        return (value as? [String])?.first
    }()
    #else
    /// iOS cannot read its own entitlements. Every iOS build is signed with iCloud
    /// (iOS/project.yml). The simulator without an iCloud account keeps the todos local.
    static let iCloudContainer: String? = "iCloud.com.rafi.perch"
    #endif

    /// True when this store syncs with iCloud. A test store never does.
    static var syncs: Bool { !isOverridden && iCloudContainer != nil }

    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "Perch", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Perch.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            // Never .automatic: it would sync any store, test stores too.
            let cloud: ModelConfiguration.CloudKitDatabase = if syncs, let id = iCloudContainer { .private(id) } else { .none }
            return try ModelContainer(for: Todo.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: cloud))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
