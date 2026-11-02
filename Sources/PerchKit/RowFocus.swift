import Foundation

/// Where the keyboard is in the panel: nowhere, typing in one row, or a selection of rows.
public enum RowFocus<ID: Hashable>: Equatable {
    case none
    case editing(ID)
    case selection(ListSelection<ID>)

    /// The row being typed in.
    public var editingID: ID? {
        if case .editing(let id) = self { id } else { nil }
    }

    /// The highlighted rows in list order. `ids` are the rows on the page.
    public func selectedIDs(in ids: [ID]) -> [ID] {
        switch self {
        case .none: []
        case .editing(let id): [id]
        case .selection(let s): s.ids(in: ids)
        }
    }
}

/// Keyboard and click rules for the panel's rows. `ids` are the rows on the
/// page, in order. Each rule returns where the keyboard goes next. `AppModel`
/// ends the edit where its method says so, then applies the result.
public enum FocusRules {
    /// Up or Down while typing, and Backspace in an empty row (step -1):
    /// the row to type in next. nil at the ends, or when `id` is not on the page.
    public static func neighbor<ID: Hashable>(of id: ID, step: Int, in ids: [ID]) -> ID? {
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + step) else { return nil }
        return ids[index + step]
    }

    /// Up or Down with no row typing. From nothing, Down goes to the first row
    /// and Up to the last. A List row starts typing. An Archive row is selected.
    public static func cursor<ID: Hashable>(from focus: RowFocus<ID>, step: Int, in ids: [ID], isList: Bool) -> RowFocus<ID>? {
        let target: ID? = switch focus {
        case .none: step > 0 ? ids.first : ids.last
        case .editing(let id): id
        case .selection(let s): s.moved(by: step, extend: false, in: ids).cursor
        }
        guard let target else { return nil }
        return isList ? .editing(target) : .selection(ListSelection(target))
    }

    /// Shift-Up and Shift-Down. A typed row becomes the anchor. `focus` is the
    /// focus before the edit ended, and `ids` the rows after it ended, without
    /// a new row that was left empty. nil when there is nothing to select.
    public static func extending<ID: Hashable>(_ focus: RowFocus<ID>, step: Int, in ids: [ID]) -> RowFocus<ID>? {
        switch focus {
        case .none:
            guard let first = step > 0 ? ids.first : ids.last else { return nil }
            return .selection(ListSelection(first))
        case .editing(let id):
            guard ids.contains(id) else { return nil }
            return .selection(ListSelection(id).moved(by: step, extend: true, in: ids))
        case .selection(let s):
            return .selection(s.moved(by: step, extend: true, in: ids))
        }
    }

    /// Click and Shift-click on `id`. Shift-click selects from the typed row
    /// or the selection's anchor. A click types in a List row and selects an Archive row.
    public static func click<ID: Hashable>(_ id: ID, extend: Bool, from focus: RowFocus<ID>, isList: Bool) -> RowFocus<ID> {
        if extend {
            let anchor: ID? = switch focus {
            case .none: nil
            case .editing(let row): row
            case .selection(let s): s.anchor
            }
            return .selection(ListSelection(anchor ?? id).extended(to: id))
        }
        return isList ? .editing(id) : .selection(ListSelection(id))
    }

    /// After rows are completed or deleted: the next row is selected, or the
    /// one before when the removed rows were at the end.
    public static func afterRemoving<ID: Hashable>(_ removed: Set<ID>, from ids: [ID]) -> RowFocus<ID> {
        ids.neighbor(afterRemoving: removed).map { .selection(ListSelection($0)) } ?? .none
    }
}
