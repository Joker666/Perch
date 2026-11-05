import AppKit
import SwiftUI

/// Writes the theme icons as PNG files, from the same drawing as the icon in
/// Settings (AppIconView). The first theme is the bundle icon, so it is left out.
///   Perch --ios-icons iOS/Icons.xcassets      the iOS alternate icons (tools/make_ios_icons.sh)
///   Perch --dock-icons <dir>                  icon-<theme>.png for the Dock tile plug-in (build.sh)
enum IconExport {
    private static let modes = ["--ios-icons", "--dock-icons"]
    private static var mode: String? { modes.first { CommandLine.arguments.contains($0) } }

    static var requested: Bool { mode != nil }

    static func run() -> Int32 {
        let args = CommandLine.arguments
        guard let mode, let index = args.firstIndex(of: mode), index + 1 < args.count else {
            print("usage: Perch --ios-icons <Icons.xcassets> | --dock-icons <dir>")
            return 2
        }
        let dir = URL(fileURLWithPath: args[index + 1])
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if mode == "--dock-icons" { try dockIcons(in: dir) } else { try iosIcons(in: dir) }
            return 0
        } catch {
            print("\(mode) failed: \(error)")
            return 1
        }
    }

    /// Mac icons with the macOS icon grid and shadow, 1024 px for the Dock's largest size.
    private static func dockIcons(in dir: URL) throws {
        for theme in Theme.all.dropFirst() {
            try png(AppIconView(theme: theme, size: 512), scale: 2, opaque: false)
                .write(to: dir.appending(path: "icon-\(theme.id).png"))
        }
    }

    /// Full-bleed iOS icons, 1024 px, each in its own app icon set.
    private static func iosIcons(in catalog: URL) throws {
        let contents = #"{"images":[{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}"#
        try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to: catalog.appending(path: "Contents.json"))
        for theme in Theme.all.dropFirst() {
            let set = catalog.appending(path: "AppIcon-\(theme.id).appiconset")
            try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: set.appending(path: "Contents.json"))
            try png(AppIconView(theme: theme, size: 1024, fullBleed: true), scale: 1, opaque: true)
                .write(to: set.appending(path: "icon.png"))
        }
        print("wrote \(Theme.all.count - 1) icons to \(catalog.path)")
    }

    /// The view as a PNG. `opaque` drops the alpha channel: the App Store refuses an icon with one.
    private static func png(_ view: some View, scale: CGFloat, opaque: Bool) throws -> Data {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard var image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        if opaque {
            guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { throw CocoaError(.fileWriteUnknown) }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let flat = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
            image = flat
        }
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
