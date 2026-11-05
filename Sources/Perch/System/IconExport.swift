import AppKit
import SwiftUI

/// Writes the theme icons as PNG files, from the same drawing as the icon in
/// Settings (AppIconView). The first theme is the bundle icon, so it is left out.
///   Perch --ios-icons iOS/Icons.xcassets      the iOS alternate icons (tools/make_ios_icons.sh)
///   Perch --dock-icons <dir>                  icon-<theme>.png for the Dock tile plug-in (build.sh)
enum IconExport {
    static var requested: Bool { CommandLine.arguments.contains("--ios-icons") || CommandLine.arguments.contains("--dock-icons") }

    static func run() -> Int32 {
        CommandLine.arguments.contains("--dock-icons") ? dockIcons() : iosIcons()
    }

    /// Mac icons with the macOS icon grid and shadow, 1024 px for the Dock's largest size.
    private static func dockIcons() -> Int32 {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--dock-icons"), index + 1 < args.count else {
            print("usage: Perch --dock-icons <dir>")
            return 2
        }
        let dir = URL(fileURLWithPath: args[index + 1])
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for theme in Theme.all.dropFirst() {
                let renderer = ImageRenderer(content: AppIconView(theme: theme, size: 512))
                renderer.scale = 2
                guard let image = renderer.cgImage,
                      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: dir.appending(path: "icon-\(theme.id).png"))
            }
            return 0
        } catch {
            print("dock-icons failed: \(error)")
            return 1
        }
    }

    private static func iosIcons() -> Int32 {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--ios-icons"), index + 1 < args.count else {
            print("usage: Perch --ios-icons <Icons.xcassets>")
            return 2
        }
        let catalog = URL(fileURLWithPath: args[index + 1])
        let contents = #"{"images":[{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}"#
        do {
            try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
            try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to: catalog.appending(path: "Contents.json"))
            // The first theme is the primary icon, the Icon Composer file in Icon/.
            for theme in Theme.all.dropFirst() {
                let set = catalog.appending(path: "AppIcon-\(theme.id).appiconset")
                try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
                try Data(contents.utf8).write(to: set.appending(path: "Contents.json"))
                try png(theme).write(to: set.appending(path: "icon.png"))
            }
            print("wrote \(Theme.all.count - 1) icons to \(catalog.path)")
            return 0
        } catch {
            print("ios-icons failed: \(error)")
            return 1
        }
    }

    /// 1024 pt, opaque: the App Store refuses an icon with an alpha channel.
    private static func png(_ theme: Theme) throws -> Data {
        let size = 1024
        let renderer = ImageRenderer(content: AppIconView(theme: theme, size: CGFloat(size), fullBleed: true))
        renderer.scale = 1
        guard let image = renderer.cgImage,
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let opaque = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: opaque).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}
