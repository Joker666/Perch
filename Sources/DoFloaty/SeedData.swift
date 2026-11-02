import Foundation
import SwiftData
import DoFloatyKit

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an empty
/// store with open and completed todos, short and long. Todos have only
/// text, so the seed sets nothing a person cannot type.
@MainActor
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        let context = model.container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<Todo>())) ?? 0) == 0 else { return }
        let open = [
            "Reply to Maya about Friday",
            "Book the dentist",
            "Finish the landing page",
            "Renew passport before the trip to Lisbon in June",
            "Water the plants",
            "Buy oat milk",
        ]
        for (index, text) in open.enumerated() {
            context.insert(Todo(text: text, order: Double(index) * TodoOrder.step))
        }
        let done = ["Send invoice 42", "Call the bank", "Pick up the dry cleaning"]
        for (index, text) in done.enumerated() {
            let todo = Todo(text: text, order: 0)
            todo.isCompleted = true
            todo.completedAt = Date.now.addingTimeInterval(Double(-index) * 3_600)
            context.insert(todo)
        }
        try? context.save()
        model.reload()
    }
}
