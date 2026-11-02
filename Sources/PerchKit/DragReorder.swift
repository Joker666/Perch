import Foundation

/// A row being dragged to a new place in the List, as plain numbers.
public struct DragReorder: Equatable, Sendable {
    /// The dragged row's index when the drag began.
    public var from: Int
    /// How far the pointer moved down. Negative is up.
    public var translation: Double
    public var rowHeight: Double
    public var count: Int

    public init(from: Int, translation: Double, rowHeight: Double, count: Int) {
        self.from = from
        self.translation = translation
        self.rowHeight = rowHeight
        self.count = count
    }

    /// The index the dragged row lands on if the drag ends now.
    public var target: Int {
        max(0, min(count - 1, from + Int((translation / rowHeight).rounded())))
    }

    /// How far the row at `index` moves. The dragged row follows the pointer,
    /// and the rows it passes move one row the other way to make room.
    public func offset(at index: Int) -> Double {
        if index == from { return translation }
        if from < index, index <= target { return -rowHeight }
        if target <= index, index < from { return rowHeight }
        return 0
    }

    /// The `destination` for `TodoOrder.moving` when the drag ends.
    public var destination: Int { TodoOrder.destination(from: from, to: target) }
}
