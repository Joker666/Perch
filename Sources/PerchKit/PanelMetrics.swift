import Foundation

/// Sizes of the floating panel. The panel's height always fits its rows.
public struct PanelMetrics: Equatable, Sendable {
    public static let fillerCount = 3
    /// Height of the empty Archive's "Nothing completed yet", in rows.
    public static let emptyArchiveRows = 2
    public static let minWidth = 320.0
    public static let maxWidth = 520.0
    public static let defaultWidth = 400.0
    /// Space above the title bar.
    public static let topInset = 4.0
    public static let titlebarHeight = 36.0
    public static let contentTopPadding = 4.0
    public static let contentBottomPadding = 16.0

    public var fontSize: Double

    public init(fontSize: Double) {
        self.fontSize = fontSize
    }

    /// 36 pt at the default 14 pt text. Grows with the text.
    public var rowHeight: Double { (fontSize + 22).rounded() }
    /// 18 pt at 14 pt text.
    public var circleSize: Double { (fontSize + 4).rounded() }

    /// The height that shows `rows` rows (todos plus fillers) with no scrolling.
    public func height(rows: Int) -> Double {
        Self.topInset + Self.titlebarHeight + Self.contentTopPadding
            + Double(rows) * rowHeight + Self.contentBottomPadding
    }

    /// The fitted height, capped so the panel stays on screen. Past the cap the list scrolls.
    public func height(rows: Int, maxHeight: Double) -> Double {
        min(height(rows: rows), max(height(rows: 1), maxHeight))
    }

    public static func clampWidth(_ width: Double) -> Double {
        min(maxWidth, max(minWidth, width))
    }

    /// Rubber band: how far the panel follows a drag past its allowed size.
    /// Small drags follow at about half speed, long ones level off at `limit`.
    public static func rubberBand(_ overshoot: Double, limit: Double = 60) -> Double {
        let sign = overshoot < 0 ? -1.0 : 1.0
        let distance = abs(overshoot)
        return sign * limit * (1 - 1 / (distance * 0.55 / limit + 1))
    }
}
