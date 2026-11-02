import AppKit
import SwiftUI
import PerchKit

/// Owns the floating panel: shows and hides it, keeps its height fitted to
/// the rows, springs back after a resize, and routes keys when no row is
/// being typed in.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static private(set) var shared: PanelController!

    let model: AppModel
    let panel: FloatingPanel
    private var keyMonitor: Any?
    /// The width people chose by dragging. The height always follows the rows.
    private var width: CGFloat

    init(model: AppModel) {
        self.model = model
        let defaults = UserDefaults.standard
        width = PanelMetrics.clampWidth(defaults.object(forKey: "panel.width") as? Double ?? PanelMetrics.defaultWidth)
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 300))
        super.init()
        Self.shared = self

        let host = NSHostingView(rootView: PanelView().environment(model))
        host.sizingOptions = []
        panel.contentView = host
        panel.undo = model.undoManager
        panel.delegate = self
        panel.setFrame(NSRect(origin: savedOrigin(), size: NSSize(width: width, height: fittedHeight())), display: false)
        track()
        installKeyMonitor()
    }

    // MARK: Showing

    var isVisible: Bool { panel.isVisible }

    func show() {
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        model.panelVisible = true
    }

    /// Shows the panel without taking the keyboard from the front app (the agent CLI's `open`).
    func reveal() {
        panel.orderFrontRegardless()
        model.panelVisible = true
    }

    func hide() {
        model.commitEditing()
        panel.orderOut(nil)
        model.panelVisible = false
    }

    /// Show and Hide in the menus. Opening a menu takes the keyboard from the
    /// panel, so this goes by visibility only, like the menu item's title.
    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    /// The global shortcut: hides the panel when it has the keyboard, otherwise
    /// shows it with a new todo ready for typing. Hiding drops an empty new row.
    func quickAdd() {
        if panel.isVisible && panel.isKeyWindow { hide(); return }
        newTodo()
    }

    /// New Todo in the menu bar menu: always shows the panel and starts a todo.
    func newTodo() {
        show()
        if model.editingID == nil { model.add() }
    }

    // MARK: Height

    private func maxHeight() -> CGFloat {
        let screen = panel.screen ?? NSScreen.main
        return (screen?.visibleFrame.height ?? 800) - 40
    }

    private func rowCount() -> Int {
        switch model.mode {
        case .list: model.todos.count + PanelMetrics.fillerCount
        case .archive: max(model.archived.count, PanelMetrics.emptyArchiveRows)
        }
    }

    private func fittedHeight() -> CGFloat {
        PanelMetrics(fontSize: Prefs.shared.fontSize).height(rows: rowCount(), maxHeight: maxHeight())
    }

    /// Re-fits the panel whenever the rows, mode, font size, or radius change.
    private func track() {
        withObservationTracking {
            _ = rowCount()
            _ = Prefs.shared.fontSize
            _ = Prefs.shared.radius
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.fit(animated: true)
                self?.track()
            }
        }
    }

    /// Sets the fitted height with the top edge fixed, so rows grow downward.
    func fit(animated: Bool) {
        guard !panel.inLiveResize else { return }
        let frame = fittedFrame()
        guard frame != panel.frame else { panel.invalidateShadow(); return }
        if animated && panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            animate(to: frame, duration: Motion.resize, curve: Motion.resizeCurve)
        } else {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
        }
    }

    /// The fitted height at the chosen width, with the top edge where it is now.
    private func fittedFrame() -> NSRect {
        var frame = panel.frame
        let height = fittedHeight()
        frame.origin.y = frame.maxY - height
        frame.size = NSSize(width: width, height: height)
        return frame
    }

    private func animate(to frame: NSRect, duration: Double, curve: CAMediaTimingFunction) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = curve
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.invalidateShadow() }
        }
    }

    // MARK: Resizing with a rubber band

    func windowWillResize(_ sender: NSWindow, to size: NSSize) -> NSSize {
        let fitted = fittedHeight()
        var result = size
        if size.width < PanelMetrics.minWidth {
            result.width = PanelMetrics.minWidth + PanelMetrics.rubberBand(size.width - PanelMetrics.minWidth)
        } else if size.width > PanelMetrics.maxWidth {
            result.width = PanelMetrics.maxWidth + PanelMetrics.rubberBand(size.width - PanelMetrics.maxWidth)
        }
        result.height = fitted + PanelMetrics.rubberBand(size.height - fitted)
        return result
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        width = PanelMetrics.clampWidth(panel.frame.width)
        save()
        animate(to: fittedFrame(), duration: Motion.springBack, curve: Motion.springBackCurve)
    }

    func windowDidMove(_ notification: Notification) {
        save()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.panelIsKey = true
    }

    func windowDidResignKey(_ notification: Notification) {
        model.panelIsKey = false
        model.commitEditing()
    }

    /// The green button: the widest panel, or back to the default width.
    func toggleWidth() {
        width = width < PanelMetrics.maxWidth ? PanelMetrics.maxWidth : PanelMetrics.defaultWidth
        save()
        fit(animated: true)
    }

    // MARK: Position

    private func savedOrigin() -> NSPoint {
        let defaults = UserDefaults.standard
        if !Store.isOverridden, let x = defaults.object(forKey: "panel.x") as? Double,
           let top = defaults.object(forKey: "panel.top") as? Double {
            let point = NSPoint(x: x, y: top - fittedHeight())
            if NSScreen.screens.contains(where: { $0.visibleFrame.contains(NSPoint(x: x + 40, y: top - 20)) }) {
                return point
            }
        }
        // First launch: the top right corner of the main screen.
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: visible.maxX - width - 24, y: visible.maxY - 24 - fittedHeight())
    }

    private func save() {
        guard !Store.isOverridden else { return }
        let defaults = UserDefaults.standard
        defaults.set(Double(width), forKey: "panel.width")
        defaults.set(Double(panel.frame.minX), forKey: "panel.x")
        defaults.set(Double(panel.frame.maxY), forKey: "panel.top")
    }

    // MARK: Keys when no row is being typed in

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel, !(self.panel.firstResponder is NSText) else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// Up, Down, Shift, Return, Delete, and Escape on the panel. Command keys go to the menus.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.contains(.command), !flags.contains(.control) else { return false }
        let shift = flags.contains(.shift)
        switch Int(event.keyCode) {
        case 125: shift ? model.extendSelection(step: 1) : model.moveCursor(step: 1)
        case 126: shift ? model.extendSelection(step: -1) : model.moveCursor(step: -1)
        case 36, 76:
            if case .selection(let s) = model.focus, model.mode == .list {
                model.beginEditing(s.cursor)
            } else if model.focus == .none, model.mode == .list {
                model.add()
            }
        case 51, 117: model.deleteSelected()
        case 53:
            if model.focus == .none { hide() } else { model.focus = .none }
        default: return false
        }
        return true
    }
}

/// A borderless panel above other windows, on every Space. The SwiftUI
/// content draws the rounded background, so the window itself is clear.
final class FloatingPanel: NSPanel {
    var undo: UndoManager?

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .resizable, .closable, .miniaturizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 200, height: 80)
        animationBehavior = .utilityWindow
        setAccessibilityTitle("Perch")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var undoManager: UndoManager? { undo }

    /// Perch's menu shortcuts work even while SwiftUI rebuilds the Edit menu (System/AppMenus.swift).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        super.performKeyEquivalent(with: event) || AppMenus.shared.performKeyEquivalent(event)
    }

    override func performClose(_ sender: Any?) {
        PanelController.shared.hide()
    }
}

/// Close, minimize, and zoom, drawn like the system buttons. Detached system
/// buttons cannot see a borderless panel's key state, so these are drawn here.
struct TrafficLights: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        HStack(spacing: PanelStyle.trafficLightSpacing) {
            light(0xFF5F57, "xmark", "Close", "Hide the panel (⌘W)") { PanelController.shared.hide() }
            light(0xFEBC2E, "minus", "Minimize", "Minimize the panel to the Dock") {
                PanelController.shared.panel.miniaturize(nil)
            }
            light(0x28C840, "plus", "Zoom", "Switch between the wide and the default width") {
                PanelController.shared.toggleWidth()
            }
        }
        .onHover { hovering = $0 }
    }

    private func light(_ color: UInt32, _ glyph: String, _ label: String, _ help: String,
                       action: @escaping () -> Void) -> some View {
        let active = model.panelIsKey || hovering
        return Button(action: action) {
            Circle()
                .fill(active ? Color(hex: color) : Palette.inactiveLight)
                .overlay { Circle().strokeBorder(.black.opacity(active ? 0.12 : 0), lineWidth: 0.5) } // grid: ok hairline edge like the system buttons
                .overlay {
                    Image(systemName: glyph)
                        .font(.system(size: 6.5, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.55))
                        .opacity(hovering ? 1 : 0)
                }
                .frame(width: 12, height: 12)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(label)
    }
}
