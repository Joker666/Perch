#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

/// The eight app icons, one per theme, drawn in code. Picking one in
/// Settings > Icon changes the Dock icon at once. The choice is applied
/// again at every launch. On iOS the icons are alternate app icons in the
/// bundle (iOS/Assets.xcassets), and iOS shows its own alert for a change.
enum AppIcons {
    #if os(macOS)
    static func apply(_ id: String) {
        // The bundle icon is Midnight. Other icons replace it while the app runs.
        NSApp.applicationIconImage = id == Theme.all[0].id && Bundle.main.bundleURL.pathExtension == "app"
            ? nil : image(for: Theme.named(id), size: 512)
    }

    static func image(for theme: Theme, size: CGFloat) -> NSImage {
        let renderer = ImageRenderer(content: AppIconView(theme: theme, size: size))
        renderer.scale = 2
        return renderer.nsImage ?? NSImage()
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
