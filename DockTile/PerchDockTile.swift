import AppKit

/// The Dock loads this plug-in while Perch is in the Dock but not running, and shows
/// the icon picked in Settings > Icon instead of the bundle icon. Perch writes the
/// choice to its defaults ("icon") and posts `com.rafi.perch.iconChanged`.
/// The icons are PNGs in this bundle, drawn by Perch (`Perch --dock-icons`).
@objc(PerchDockTilePlugIn)
final class PerchDockTilePlugIn: NSObject, NSDockTilePlugIn {
    private var observer: NSObjectProtocol?

    func setDockTile(_ dockTile: NSDockTile?) {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        observer = nil
        guard let dockTile else { return }
        show(in: dockTile)
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.rafi.perch.iconChanged"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.show(in: dockTile)
        }
    }

    /// The picked icon, or the bundle icon for Midnight or when the choice cannot be read.
    private func show(in dockTile: NSDockTile) {
        let domain = "com.rafi.perch" as CFString
        CFPreferencesAppSynchronize(domain)
        let id = CFPreferencesCopyAppValue("icon" as CFString, domain) as? String ?? ""
        if let url = Bundle(for: Self.self).url(forResource: "icon-\(id)", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            let view = NSImageView(image: image)
            view.imageScaling = .scaleProportionallyUpOrDown
            dockTile.contentView = view
        } else {
            dockTile.contentView = nil
        }
        dockTile.display()
    }
}
