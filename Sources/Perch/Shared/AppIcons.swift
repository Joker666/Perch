#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

/// The eight app icons, one per theme, drawn in code. On the Mac the picked icon
/// replaces the Dock icon while Perch runs. On iOS they are alternate icons in
/// iOS/Icons.xcassets, and iOS asks before it changes the icon.
enum AppIcons {
    #if os(macOS)
    /// Drawn once per theme, because Perch applies the icon again each time it becomes active.
    private static var drawn: [String: NSImage] = [:]
    /// How many times Perch set the Dock icon. The self-test reads it.
    private(set) static var applied = 0

    /// Sets the Dock icon. A new Dock tile shows the bundle icon again, so Perch also
    /// calls this on activation. The notification updates the Dock tile plug-in (DockTile/).
    static func apply(_ id: String) {
        applied += 1
        // The bundle icon is Midnight. Other icons replace it while the app runs.
        if id == Theme.all[0].id && Bundle.main.bundleURL.pathExtension == "app" {
            NSApp.applicationIconImage = nil
        } else if let image = drawn[id] ?? rendered(Theme.named(id)) {
            drawn[id] = image
            NSApp.applicationIconImage = image
        }
        DistributedNotificationCenter.default().postNotificationName(changed, object: nil, deliverImmediately: true)
    }

    /// Tells the Dock tile plug-in to read the icon choice again.
    static let changed = Notification.Name("com.rafi.perch.iconChanged")

    static func image(for theme: Theme, size: CGFloat) -> NSImage {
        let renderer = ImageRenderer(content: AppIconView(theme: theme, size: size))
        renderer.scale = 2
        return renderer.nsImage ?? NSImage()
    }

    /// The Dock-size icon, or nil when SwiftUI cannot draw yet. An empty image would
    /// show a blank Dock tile, and the cache would keep it.
    private static func rendered(_ theme: Theme) -> NSImage? {
        let image = image(for: theme, size: 512)
        return image.representations.isEmpty || image.size.width == 0 ? nil : image
    }
    #else
    /// The alternate icon's name in the asset catalog, or nil for the primary (Midnight) icon.
    static func alternateName(_ id: String) -> String? {
        id == Theme.all[0].id ? nil : "AppIcon-\(id)"
    }

    static func apply(_ id: String) {
        let name = alternateName(id)
        guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name)
    }
    #endif
}

/// A rounded square in the theme's deep color with a checked box in the panel color.
struct AppIconView: View {
    let theme: Theme
    let size: CGFloat
    /// iOS icons fill the whole square, and iOS rounds the corners itself.
    var fullBleed = false

    var body: some View {
        // The macOS icon grid: the body fills about 80% of the canvas.
        let body = fullBleed ? size : size * 0.805
        ZStack {
            RoundedRectangle(cornerRadius: fullBleed ? 0 : body * 0.225, style: .continuous)
                .fill(LinearGradient(colors: [theme.deepColor.mix(with: .white, by: 0.12), theme.deepColor],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: body, height: body)
                .shadow(color: .black.opacity(fullBleed ? 0 : 0.25), radius: size * 0.02, y: size * 0.01)
            RoundedRectangle(cornerRadius: body * 0.16, style: .continuous)
                .fill(theme.surfaceColor)
                .frame(width: body * 0.56, height: body * 0.56)
                .shadow(color: .black.opacity(0.18), radius: size * 0.015, y: size * 0.008)
            Image(systemName: "checkmark")
                .font(.system(size: body * 0.3, weight: .heavy))
                .foregroundStyle(theme.textColor)
        }
        .frame(width: size, height: size)
    }
}
