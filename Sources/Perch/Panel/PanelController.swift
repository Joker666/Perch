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
    /// The panel's full-size frame while it appears or hides. Nil at rest.
    private var restingFrame: NSRect?
    /// Where the panel sits, also while it springs in or fades out. Settings opens beside it.
    var homeFrame: NSRect { restingFrame ?? panel.frame }
    private enum Transition { case appearing, hiding }
    private var transition: Transition?
    private var transitionStart: CFTimeInterval = 0
    private var transitionLink: CADisplayLink?
    /// 2% of the spring's travel is under a pixel, since the panel only grows by 2%.
    private static let appearDuration = Motion.appear.settleTime(tolerance: 0.02)

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
        panel.setFrame(fittedFrame(), display: false)
        track()
        installKeyMonitor()
    }

    // MARK: Showing

    /// A panel that is fading out counts as hidden.
    var isVisible: Bool { panel.isVisible && transition != .hiding }

    func show() {
        NSApp.activate()
        appearIfHidden()
        panel.makeKeyAndOrderFront(nil)
        model.panelVisible = true
    }

    /// Shows the panel without taking the keyboard from the front app (the agent CLI's `open`).
    func reveal() {
        appearIfHidden()
        panel.orderFrontRegardless()
        model.panelVisible = true
    }

    func hide() {
        model.commitEditing()
        finishAppear()
        model.panelVisible = false
        guard isVisible else { return }
        beginHide()
    }

    /// Show and Hide in the menus. Opening a menu takes the keyboard from the
    /// panel, so this goes by visibility only, like the menu item's title.
    func toggle() {
        if isVisible { hide() } else { show() }
    }

    /// The global shortcut: hides the panel when it has the keyboard, otherwise
    /// shows it with a new todo ready for typing. Hiding drops an empty new row.
    func quickAdd() {
        if isVisible && panel.isKeyWindow { hide(); return }
        newTodo()
    }

    /// New Todo in the menu bar menu: always shows the panel and starts a todo.
    func newTodo() {
        if !isVisible {
            // Finish a pending hide before preparing the next appearance. The
            // spring must start with the new row's height and settled contents.
            finishHide()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if model.editingID == nil { model.add() }
                fit(animated: false)
                panel.contentView?.layoutSubtreeIfNeeded()
            }
        }
        show()
        if model.editingID == nil { model.add() }
    }

    // MARK: Appearing and hiding

    var isAppearing: Bool { transition == .appearing }
    var isHiding: Bool { transition == .hiding }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Brings back a panel that is fading out, or springs in a hidden one.
    private func appearIfHidden() {
        finishHide()
        if !panel.isVisible { beginAppear() }
    }

    /// Puts the panel at `Motion.appearScale` of its fitted frame. Each display
    /// frame then moves it along `Motion.appear` to the full size.
    private func beginAppear() {
        guard !reduceMotion else { return }
        let frame = fittedFrame()
        restingFrame = frame
        panel.setFrame(WindowPlacement.scaled(frame, from: Motion.appearScale, progress: 0), display: false)
        start(.appearing)
    }

    /// Shrinks the panel to `Motion.hideScale` and fades it out, then orders it out.
    private func beginHide() {
        guard !reduceMotion else {
            panel.orderOut(nil)
            return
        }
        restingFrame = panel.frame
        start(.hiding)
    }

    private func start(_ kind: Transition) {
        transition = kind
        transitionStart = CACurrentMediaTime()
        transitionLink?.invalidate()
        let link = panel.displayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        transitionLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let frame = restingFrame, let transition else { return }
        let elapsed = link.targetTimestamp - transitionStart
        switch transition {
        case .appearing:
            guard elapsed < Self.appearDuration else { finishAppear(); return }
            let progress = Motion.appear.value(at: elapsed)
            panel.setFrame(WindowPlacement.scaled(frame, from: Motion.appearScale, progress: progress), display: true)
        case .hiding:
            guard elapsed < Motion.hide else { finishHide(); return }
            let gone = Motion.hideCurve(elapsed / Motion.hide)
            panel.setFrame(WindowPlacement.scaled(frame, from: Motion.hideScale, progress: 1 - gone), display: true)
            panel.alphaValue = 1 - gone
        }
        panel.invalidateShadow()
    }

    private func stop() -> NSRect? {
        transitionLink?.invalidate()
        transitionLink = nil
        transition = nil
        defer { restingFrame = nil }
        return restingFrame
    }

    /// Ends the spring at the resting frame. The self-test calls it to skip ahead.
    func finishAppear() {
        guard isAppearing, let frame = stop() else { return }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
        save()
    }

    /// Orders the panel out and puts it back at full size and opacity for the
    /// next show. The self-test calls it to skip ahead.
    func finishHide() {
        guard isHiding, let frame = stop() else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.setFrame(frame, display: false)
        save()
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

    /// Sets the fitted height with the top edge fixed, so rows grow downward,
    /// until the panel reaches the Dock. Then the panel moves up. While the
    /// panel appears or hides, the new frame becomes its full-size frame.
    func fit(animated: Bool) {
        guard !panel.inLiveResize else { return }
        let frame = fittedFrame()
        if restingFrame != nil { restingFrame = frame; return }
        guard frame != panel.frame else { panel.invalidateShadow(); return }
        if animated && panel.isVisible && !reduceMotion {
            animate(to: frame, duration: Motion.resize, curve: Motion.resizeCurve)
        } else {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
        }
    }

    /// The fitted height at the chosen width, with the top edge where it is now,
    /// moved up when that would put rows under the Dock or off the screen.
    func fittedFrame() -> NSRect {
        var frame = restingFrame ?? panel.frame
        let height = fittedHeight()
        frame.origin.y = frame.maxY - height
        frame.size = NSSize(width: width, height: height)
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return frame }
        return WindowPlacement.keptOnScreen(frame, in: visible)
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
        guard !Store.isOverridden, restingFrame == nil else { return }
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
        animationBehavior = .none // PanelController animates the show and the hide
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
