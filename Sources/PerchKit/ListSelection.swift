import Foundation

/// A contiguous range of rows, anchored where it started. `cursor` is the end
/// the arrow keys move. With anchor == cursor it is one row.
public struct ListSelection<ID: Hashable>: Equatable {
    public var anchor: ID
    public var cursor: ID

    public init(_ id: ID) {
        anchor = id
        cursor = id
    }

    public init(anchor: ID, cursor: ID) {
        self.anchor = anchor
        self.cursor = cursor
    }

    public var isSingle: Bool { anchor == cursor }

    /// The selected ids in list order. Empty when the anchor or cursor left the list.
    public func ids(in list: [ID]) -> [ID] {
        guard let a = list.firstIndex(of: anchor), let c = list.firstIndex(of: cursor) else { return [] }
        return Array(list[min(a, c)...max(a, c)])
    }

    /// Moves the cursor one row. With `extend`, the anchor stays (Shift-arrow).
    /// Without it, the selection collapses to the new row. Stops at the ends.
    public func moved(by step: Int, extend: Bool, in list: [ID]) -> ListSelection {
        guard let c = list.firstIndex(of: cursor) else { return self }
        let next = list[max(0, min(list.count - 1, c + step))]
        return extend ? ListSelection(anchor: anchor, cursor: next) : ListSelection(next)
    }

    /// Shift-click: keeps the anchor and moves the cursor to `id`.
    public func extended(to id: ID) -> ListSelection {
        ListSelection(anchor: anchor, cursor: id)
    }
}

extension Array where Element: Hashable {
    /// The row to select after removing `removed`: the next row after the
    /// removed block, or the one before it when the block was at the end.
    public func neighbor(afterRemoving removed: Set<Element>) -> Element? {
        guard let last = lastIndex(where: removed.contains) else { return nil }
        if let after = self[(last + 1)...].first(where: { !removed.contains($0) }) { return after }
        return self[..<last].last { !removed.contains($0) }
    }
}
