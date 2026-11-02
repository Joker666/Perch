import Foundation

/// Todos sort by a Double. A new todo between two others gets the midpoint,
/// so an insert or a move writes one row, not the whole list.
public enum TodoOrder {
    /// Gap between todos after `renumbered`, and for a todo added at an end.
    public static let step = 1024.0

    /// An order value between `before` and `after`. Either can be nil for the
    /// start or the end of the list.
    public static func between(_ before: Double?, _ after: Double?) -> Double {
        switch (before, after) {
        case let (b?, a?): (b + a) / 2
        case let (b?, nil): b + step
        case let (nil, a?): a - step
        case (nil, nil): 0
        }
    }

    /// True when two neighbors are so close that the next midpoint would lose precision.
    public static func isCrowded(_ orders: [Double]) -> Bool {
        zip(orders, orders.dropFirst()).contains { abs($1 - $0) < 1e-6 }
    }

    /// Fresh, evenly spaced values for `count` todos.
    public static func renumbered(count: Int) -> [Double] {
        (0..<count).map { Double($0) * step }
    }

    /// The list after moving the items at `indices` so they land before the
    /// item now at `destination` (or at the end when `destination == items.count`).
    /// The moved items keep their relative order. Same rule as `Array.move(fromOffsets:toOffset:)`.
    public static func moving<T>(_ items: [T], indices: IndexSet, to destination: Int) -> [T] {
        let moved = indices.map { items[$0] }
        var rest: [T] = []
        var insertAt = 0
        for (index, item) in items.enumerated() where !indices.contains(index) {
            if index < destination { insertAt += 1 }
            rest.append(item)
        }
        rest.insert(contentsOf: moved, at: insertAt)
        return rest
    }

    /// The `destination` for `moving` that puts the item at `from` at index `to`.
    /// A move down lands before the item after `to`, because `to` shifts up.
    public static func destination(from: Int, to: Int) -> Int {
        to > from ? to + 1 : to
    }
}
