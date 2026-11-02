import CoreGraphics

/// Where a window goes so that all of it shows, and its frame while it scales.
public enum WindowPlacement {
    /// `frame` moved the shortest distance that puts it inside `visible`, the
    /// screen without the menu bar and the Dock. A frame larger than `visible`
    /// keeps its top and left edges on screen. AppKit coordinates: y goes up.
    public static func keptOnScreen(_ frame: CGRect, in visible: CGRect) -> CGRect {
        var moved = frame
        if moved.maxX > visible.maxX { moved.origin.x = visible.maxX - moved.width }
        if moved.minX < visible.minX { moved.origin.x = visible.minX }
        if moved.minY < visible.minY { moved.origin.y = visible.minY }
        if moved.maxY > visible.maxY { moved.origin.y = visible.maxY - moved.height }
        return moved
    }

    /// `frame` scaled about its center, by `start` at progress 0 and by 1 at progress 1.
    public static func scaled(_ frame: CGRect, from start: Double, progress: Double) -> CGRect {
        let scale = start + (1 - start) * progress
        let width = frame.width * scale, height = frame.height * scale
        return CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
    }
}
