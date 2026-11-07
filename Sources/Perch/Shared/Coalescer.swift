import Foundation

/// Runs `action` once per run loop turn, however many times `schedule` is
/// called before that turn. One iCloud merge sends several notifications, and
/// SwiftUI rebuilds a menu in bursts, so each burst shares one run.
@MainActor
final class Coalescer {
    private let action: () -> Void
    private var scheduled = false

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    func schedule() {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [self] in
            scheduled = false
            action()
        }
    }
}
