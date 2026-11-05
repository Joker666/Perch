# FloatyDo on iPhone: research for Perch iOS

Date: 2026-11-04. Sources: the App Store listing (id6760775568, iPhone, iPad, and
Mac pages, read in the browser), floatydo.com, and the FloatyDo TestFlight link.
The Mac notes are in `floatydo-reference.md`.

## What FloatyDo ships

- One App Store entry for iPhone, iPad, and Mac (universal purchase). Free, with
  "FloatyDo Lifetime" at $4.99 and a free trial. iOS 18 or later.
- Subtitle "Tiny todo widget". Pitch: write it down quickly and get it done today.
  For scheduling or detail, use a calendar or a project tool.
- "This iOS app pairs seamless with a keyboard-first macOS app." A review says it
  "syncs perfectly with my phone". The privacy label is "Data Not Collected", so
  there is no server of its own. The sync is almost certainly iCloud (CloudKit).
- floatydo.com still says "Join iOS waitlist". The site is older than the app.

### Version history

| Version | Date | Notes |
| --- | --- | --- |
| 1.0 | about 2026-08-20 | First iPhone release |
| 1.0.1 | 2026-08-22 | A completed draft could stay in the next new todo |
| 1.0.2 | 2026-08-26 | Bug fixes |
| 1.1.0 | 2026-09-13 | Timers per todo (Live Activities on iOS, menu bar countdown on Mac). Move todos to later dates |
| 1.2.0 | 2026-09-24 | Redesigned Live Activities |
| 1.3.0 | 2026-10-09 | Multi-select with a swipe, then move to Later or delete. Timer screen with a theme-colored water background and glass controls |
| 1.4.0 | 2026-10-30 | Bug fixes |

### Screens seen in the screenshots

- **List (iPhone):** the large title "FloatyDo", then one line per todo in the
  theme font, no separators. A new todo is a row at the end ("New todo"
  placeholder). The row in edit gets the highlight color and a clear (x) button.
  A "Done" capsule above the keyboard ends editing. The theme color fills the
  whole screen.
- **List (iPad):** the same list, with an open circle at the right end of each
  row. A small bottom bar on the left with three icons: List, Archive (tray), and
  Settings. A round "+" button at the bottom right.
- **Done page:** the title "Done". Completed todos, struck through, with a filled
  check circle at the right end.
- **Settings:** a sheet. "App Icon" grid with 9 icons (Default, Midnight, Emerald,
  Plum, Sky, Blossom, Matcha, Sand, Pool). The footer says "Made with <3 in
  Chicago & Nuremberg".
- Screenshot themes: Pool (light blue), Matcha (green), Blossom (pink), and a
  dark theme on iPad. So the iPhone app has the same 8 themes as the Mac.

## What Perch iOS should have

Version 1, the same as FloatyDo 1.0 and Perch on the Mac:

1. The List: add, edit in place, complete with the circle, delete with a swipe,
   reorder with a drag. Undo with shake and three-finger swipe.
2. The Archive ("Done"): restore and delete completed todos, clear all.
3. Settings sheet: the 8 themes, font, font size, app icon, About.
4. iCloud sync with the Mac app, in the same container. Turn on when the account
   is signed in. No sign-in of our own.
5. iPad: the same app, with the bottom bar and "+" button.

Later, in FloatyDo's order:

6. A Home Screen and Lock Screen widget with today's todos ("Tiny todo widget").
7. Later: move a todo to a later date. It comes back to the List on that day.
   This needs a new optional date on `Todo`.
8. Timers per todo, with a Live Activity on iOS and a menu bar countdown on Mac.
9. Multi-select with a swipe, then Later or Delete.

## Can one codebase serve both apps?

Yes, for most of the code. Today the app is 4,777 lines:

| Part | Lines | On iOS |
| --- | --- | --- |
| PerchKit (order, text, focus, spring, theme choice) | 460 | Shared as is. Window and key rules stay Mac only |
| `Todo` and `AppModel` (Models.swift) | 430 | Shared after a small split. It imports AppKit but uses almost nothing from it |
| Themes, Palette, Motion, Prefs (UI/Theme.swift, UI/Prefs.swift) | 254 | Shared after `NSColor` and `NSFont` become `Color` and `Font` |
| Panel, Settings window, menus, global shortcut, Sparkle, agent CLI and MCP, checks | about 3,600 | Mac only |
| iOS screens, widget | new | iOS only |

The most important shared part is the `Todo` model. The iCloud schema
(`CD_Todo`) comes from it. If both apps use the same model code and the same
container, `iCloud.com.rafi.perch`, the iPhone shows the Mac's todos with no
other work.

### What changes in the build

- SwiftPM builds the Mac app, but it cannot make an iOS app with a widget
  extension and iCloud entitlements. The iOS app needs an Xcode project.
- Plan: keep the Swift package for the shared code and the Mac app (`build.sh`
  does not change). Add `iOS/project.yml` for XcodeGen. It makes the Xcode
  project for the iOS app and the widget, which use the package's shared target.
  The generated `.xcodeproj` stays out of git. Install XcodeGen with Homebrew.
- Build and test on the iPhone 18 Pro simulator with `xcodebuild` (iOS 27.2 SDK
  is installed). The snapshot and self-test ideas work there too.
- The App ID `com.rafi.perch` is for all platforms, so the iPhone app can use it
  and its iCloud container. It needs two new profiles: iOS App Development (with
  your iPhone 16 Pro Max) and App Store.
- The iPhone app ships only through TestFlight and the App Store. That needs an
  App Store Connect record and app review. The Mac app stays on Developer ID and
  Sparkle.

## Decisions (Rafi, 2026-11-04)

1. Xcode project: XcodeGen `iOS/project.yml`. The generated project is not in git.
2. Bundle ID: the same `com.rafi.perch`, with the same iCloud container.
3. Version 1: items 1 to 5. No Home Screen widget.
4. Price: free, with no in-app purchase.
5. Shared code: files that both apps use live in `Sources/Perch/Shared/`. SwiftPM
   builds them into the Mac app, and the iOS target compiles the same files.
   Platform code uses `#if os(macOS)`.
