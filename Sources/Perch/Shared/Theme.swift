#if os(macOS)
import AppKit
#else
import UIKit
#endif
import PerchKit
import QuartzCore
import SwiftUI

/// One color theme for the panel and the Settings window. Every other color
/// comes from `text` at a set opacity, so a theme is three colors.
///   APP_THEME=matcha Perch     run with another theme
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    /// The panel background.
    let surface: UInt32
    /// The selected row.
    let highlight: UInt32
    /// Text, circles, and icons.
    let text: UInt32
    /// The darker, more saturated color behind the panel on the swatch and the app icon.
    let deep: UInt32
    let isDark: Bool

    var surfaceColor: Color { Color(hex: surface) }
    var highlightColor: Color { Color(hex: highlight) }
    var textColor: Color { Color(hex: text) }
    var deepColor: Color { Color(hex: deep) }

    /// The swatch in Settings.
    var swatch: Color { surfaceColor }
    #if os(macOS)
    var appearance: NSAppearance? { NSAppearance(named: isDark ? .darkAqua : .aqua) }
    #endif
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    static let all: [Theme] = [
        Theme(id: "midnight", name: "Midnight", surface: 0x14141F, highlight: 0x454554, text: 0xFFFFFF, deep: 0x262636, isDark: true),
        Theme(id: "navy", name: "Navy", surface: 0x1B2130, highlight: 0x3E475C, text: 0xFFFFFF, deep: 0x2A354E, isDark: true),
        Theme(id: "forest", name: "Forest", surface: 0x1F2724, highlight: 0x3A4943, text: 0xFFFFFF, deep: 0x2A4F41, isDark: true),
        Theme(id: "plum", name: "Plum", surface: 0x2A1E28, highlight: 0x523E47, text: 0xFFFFFF, deep: 0x492844, isDark: true),
        Theme(id: "pool", name: "Pool", surface: 0xDCEFFC, highlight: 0xB6D9F0, text: 0x092539, deep: 0x8DACC2, isDark: false),
        Theme(id: "blossom", name: "Blossom", surface: 0xF2D1E1, highlight: 0xE9B7CF, text: 0x240313, deep: 0xCFA6BA, isDark: false),
        Theme(id: "matcha", name: "Matcha", surface: 0xCFDDB5, highlight: 0xBAC99F, text: 0x1E2E00, deep: 0x809952, isDark: false),
        Theme(id: "sand", name: "Sand", surface: 0xE6E0D6, highlight: 0xD3CBBE, text: 0x41392B, deep: 0xC8C0B2, isDark: false),
    ]

    static func named(_ id: String) -> Theme { all.first { $0.id == id } ?? all[0] }
}

/// The font designs people pick in Settings > Theme.
enum TodoFont: String, CaseIterable, Identifiable {
    case system, rounded, serif, monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    #if os(macOS)
    func nsFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        let design: NSFontDescriptor.SystemDesign? = switch self {
        case .system: nil
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
        guard let design, let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
    #endif
}

/// Color tokens for views. Never hard-code a color or opacity in a view.
enum Palette {
    private static var theme: Theme { Prefs.shared.theme }

    static var surface: Color { theme.surfaceColor }
    static var highlight: Color { theme.highlightColor }
    static var text: Color { theme.textColor }
    static var secondaryText: Color { theme.textColor.opacity(0.72) }
    static var tertiaryText: Color { theme.textColor.opacity(0.45) }
    static var strikethrough: Color { theme.textColor.opacity(0.6) }
    static var circle: Color { theme.textColor.opacity(0.5) }
    static var toolbarIcon: Color { theme.textColor.opacity(0.6) }
    static var divider: Color { theme.textColor.opacity(0.12) }
    static var control: Color { theme.textColor.opacity(0.1) }
    static var inactiveLight: Color { theme.textColor.opacity(0.18) }

    /// Filler circles fade out row by row.
    static func filler(_ index: Int) -> Color {
        theme.textColor.opacity([0.22, 0.14, 0.07][min(index, 2)])
    }
}

/// Timing from the reference app. Views use these, never literal durations.
enum Motion {
    static let completionSweep = 0.25
    static let completionSettle = 0.6
    static let collapse = Animation.smooth(duration: 0.35)
    static let dragReorder = Animation.smooth(duration: 0.16)
    static let hover = Animation.easeOut(duration: 0.14)
    /// The panel's height change, on the reference app's snappy curve.
    static let resize = 0.22
    static let resizeCurve = CAMediaTimingFunction(controlPoints: 0.19, 1, 0.22, 1)
    /// The panel springs back after a drag past its size.
    static let springBack = 0.35
    static let springBackCurve = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.1)
    /// The check that pops into a completed todo's circle.
    static let check = Animation.spring(duration: 0.3, bounce: 0.4)
    /// The panel appears at 98% of its size and springs out from its center,
    /// with one small overshoot. Measured from the reference app.
    static let appearScale = 0.98
    static let appear = Spring(response: 0.23, dampingFraction: 0.6)
    /// The panel hides by shrinking back to 98% and fading out, faster than it
    /// appears. The reference app hides at once. This keeps that quickness.
    static let hide = 0.12
    static let hideScale = 0.98
    /// Ease-in: slow at first, then gone. Takes and gives progress from 0 to 1.
    static func hideCurve(_ t: Double) -> Double { t * t }
}

/// Fixed sizes of the panel's parts, from the reference app.
enum PanelStyle {
    static let rowInset: CGFloat = 12
    static let highlightInset: CGFloat = 8
    static let rowCornerRadius: CGFloat = 10
    static let textInset: CGFloat = 8
    static let toolbarButton: CGFloat = 28
    static let toolbarIcon: CGFloat = 14
    static let trafficLightLeading: CGFloat = 16
    static let trafficLightSpacing: CGFloat = 8
    static let titlebarTrailing: CGFloat = 10
    /// Around the 18 pt circle, for the reference app's 24 pt hit area.
    static let circleHitPadding: CGFloat = 3
    static let radioSize: CGFloat = 18
    static let keycapRadius: CGFloat = 6
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

#if os(macOS)
extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#endif
