import CoreData
import Foundation
import SwiftData

/// Makes Perch's record types in the CloudKit Development environment, so the schema
/// can be deployed to Production (docs/ICLOUD.md). It syncs a store in /tmp, never the
/// real one, so the real todos never go to Development.
///   ICLOUD_ENV=Development APP_DIR=<dir> ./build.sh
///   APP_STORE=/tmp/Perch-schema.store <dir>/Perch.app/Contents/MacOS/Perch --cloudkit-schema
enum CloudKitSchema {
    static var requested: Bool { CommandLine.arguments.contains("--cloudkit-schema") }

    static func run() -> Int32 {
        guard Store.isOverridden, Store.url.path.hasPrefix("/tmp/") else {
            print("CLOUDKIT SCHEMA refused: set APP_STORE to a file in /tmp")
            return 1
        }
        guard let container = Store.iCloudContainer else {
            print("CLOUDKIT SCHEMA refused: this build has no iCloud entitlement. See docs/ICLOUD.md")
            return 1
        }
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [Todo.self]) else {
            print("CLOUDKIT SCHEMA failed: no Core Data model for Todo")
            return 1
        }
        let description = NSPersistentStoreDescription(url: Store.url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: container)
        description.shouldAddStoreAsynchronously = false
        let cloud = NSPersistentCloudKitContainer(name: "Perch", managedObjectModel: model)
        cloud.persistentStoreDescriptions = [description]
        var loadError: Error?
        cloud.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            print("CLOUDKIT SCHEMA failed: \(loadError)")
            return 1
        }
        do {
            try cloud.initializeCloudKitSchema()
            print("CLOUDKIT SCHEMA made in \(container). Deploy it to Production in the CloudKit Console.")
            return 0
        } catch {
            print("CLOUDKIT SCHEMA failed: \(error)")
            return 1
        }
    }
}
