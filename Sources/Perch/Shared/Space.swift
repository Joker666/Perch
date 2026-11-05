import CoreGraphics

/// The spacing scale. Every padding, spacing, and size sits on a 4 pt grid.
///   APP_GRID=1 Perch     draw the grid, margins, and probes over the window
/// Snapshot mode also writes <page>-<mode>-layout.json, which tools/check-layout.swift checks.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
    /// Window and page margins.
    static let margin: CGFloat = 20
}
