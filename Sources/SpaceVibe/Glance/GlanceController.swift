import AppKit
import Observation
import SwiftUI

/// Runs the session glance widget (spec `docs/specs/2026-11-19-session-glance-widget.md`): its feed, its two panels (the strip
/// and the hover list) and the switch in Settings. One per run, started once at launch by the app delegate; it lives as long
/// as the process, so closing the main window leaves the widget on screen (GW17, GW-R9).
///
/// - Switch (GW-R10): on, the feed subscribes and the strip shows; off, the feed ends (the core stops polling for it) and both
///   panels leave the screen.
/// - Placement (GW-R7): the saved slot on its screen, resolved again whenever the screens change.
/// - Hover (GW-R5): the pointer on the strip opens the list after `Metrics.Popover.openDelay`; leaving both closes it after
///   `closeDelay`, so the pointer can cross the gap (`PopoverPresence`). A closed list is ordered out, so it takes no click
///   (GW-R8). Esc cannot close it: a key press reaches a window only when it is key, the panels never are (GW-R8), and a
///   global key monitor needs the Input Monitoring permission.
/// - Motion (GW-R11): the working ring turns only while the strip is visible on screen.
/// - Drag (GW13, GW-R7): a press on the strip that moves past `Metrics.Glance.dragThreshold` drags it (`GlancePanel.drag`,
///   `GlancePointerTracker`). The list closes and stays closed, the strip follows the pointer, and each connected screen
///   gets a click-through overlay with its 8 slots, the one `GlanceSlot.nearest` picks highlighted. The release saves that
///   slot, removes the overlays and moves the strip into it (`snapDuration`, none under Reduce Motion).
@MainActor
final class GlanceController {
    static let shared = GlanceController()

    /// The app's shell, set once at launch: the click fallback focuses a session on its Activity page (GW6).
    var shell: ShellModel?

    private let preferences: GlancePreferences
    private let makeCore: @MainActor () -> any CoreService
    private var feed: GlanceFeed?
    private var openMainWindow: () -> Void = {}
    private var surfaces: Surfaces?
    private var presence = PopoverPresence()
    private var settle: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    /// Set from the moment a press passes the threshold until the release.
    private var drag: Drag?
    /// The strip's move into its slot after a release; a render that wants the same frame leaves it running.
    private var snapMove: (target: CGRect, task: Task<Void, Never>)?

    /// `makeCore` is asked once, at `start`; the app's Go core when nil.
    init(preferences: GlancePreferences? = nil, makeCore: (@MainActor () -> any CoreService)? = nil) {
        self.preferences = preferences ?? .shared
        self.makeCore = makeCore ?? { AppEnvironment.shared.goCore }
    }

    /// True in a normal launch without `SPACEVIBE_TEST=1`: the gallery, headless shots and every test never show the live
    /// widget, and never open its subscription.
    nonisolated static func runs(in mode: LaunchMode, environment: [String: String]) -> Bool {
        guard case .normal = mode else { return false }
        return environment[CoreEnvironment.testFlag] != "1"
    }

    /// Shows the widget when the switch is on, and follows the switch, the slot, the screens and the feed from then on. A
    /// second call does nothing. `openMainWindow` opens or raises the main window (the app delegate's).
    func start(mode: LaunchMode, environment: [String: String] = ProcessInfo.processInfo.environment,
               openMainWindow: @escaping () -> Void) {
        guard feed == nil, Self.runs(in: mode, environment: environment) else { return }
        feed = GlanceFeed(core: makeCore())
        self.openMainWindow = openMainWindow
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        })
        follow()
        sync()
    }

    // MARK: State

    /// Re-armed after every change: Observation reports one change per registration.
    private func follow() {
        guard let feed else { return }
        withObservationTracking {
            _ = preferences.isEnabled
            _ = preferences.placement
            _ = feed.entries
            _ = feed.failure
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.sync()
                self?.follow()
            }
        }
    }

    private func sync() {
        guard let feed else { return }
        if preferences.isEnabled {
            if !feed.isRunning { feed.start() }
            render()
        } else {
            // `stop()` clears the feed, which is a change: call it only once, or it would wake this method again.
            if feed.isRunning { feed.stop() }
            hide()
        }
    }

    private var route: GlanceClickRoute {
        .live { [weak self] itemID in self?.showActivity(itemID) }
    }

    /// GW6: SpaceVibe forward, its main window open, Activity at that session.
    private func showActivity(_ itemID: String) {
        NSApp.activate()
        openMainWindow()
        shell?.openActivity(sessionItemID: itemID)
    }

    // MARK: Panels

    /// `snap`: the strip moves into its slot instead of jumping there (a release).
    private func render(snap: Bool = false) {
        guard preferences.isEnabled, let feed,
              let placed = GlancePlacement.resolve(preferences.placement, screens: GlanceScreen.connected())
        else {
            hide()
            return
        }
        let surfaces = self.surfaces ?? makeSurfaces()
        let onScreen = surfaces.strip.isVisible && surfaces.strip.occlusionState.contains(.visible)
        let route = route

        surfaces.stripHost.rootView = GlanceStripView(strip: GlanceStrip(entries: feed.entries, slot: placed.slot), isOnScreen: onScreen,
                                                      open: { route.open($0) })
        let stripSize = Self.whole(surfaces.stripHost.fittingSize)
        if let drag {
            // The strip is under the pointer: new entries change its content and size, never its origin.
            Self.show(surfaces.strip, at: CGRect(origin: surfaces.strip.frame.origin, size: stripSize))
            surfaces.list.orderOut(nil)
            refresh(drag)
            return
        }
        let stripFrame = placed.slot.frame(for: stripSize, in: placed.screen.visibleFrame)
        if snap {
            move(surfaces.strip, to: stripFrame)
        } else if snapMove?.target != stripFrame {
            // No move, or one toward a frame this render no longer wants: the strip goes straight to its frame.
            stopSnap()
            Self.show(surfaces.strip, at: stripFrame)
        }

        guard presence.isOpen else {
            surfaces.list.orderOut(nil)
            return
        }
        let entries = feed.entries.all
        let note = feed.failure ?? GlanceWording.noSession
        func list(width: CGFloat?, rowsHeight: CGFloat?) -> GlanceListView {
            GlanceListView(entries: entries, note: note, width: width, rowsHeight: rowsHeight, isOnScreen: onScreen,
                           hint: { route.destination(of: $0) }, open: { route.open($0) })
        }
        // The list's own size first, unscrolled; a sentence wider than a list wraps at the list's width.
        surfaces.measureHost.rootView = list(width: nil, rowsHeight: nil)
        var natural = Self.whole(surfaces.measureHost.fittingSize)
        var width: CGFloat?
        if entries.isEmpty, natural.width > Metrics.Glance.listWidth {
            width = Metrics.Glance.listWidth
            surfaces.measureHost.rootView = list(width: width, rowsHeight: nil)
            natural = Self.whole(surfaces.measureHost.fittingSize)
        } else if entries.isEmpty {
            width = natural.width
        }
        let wanted = CGSize(width: natural.width, height: min(natural.height, Metrics.Glance.listMaxHeight))
        let listFrame = placed.slot.listFrame(for: wanted, widgetFrame: stripFrame, in: placed.screen.visibleFrame)
        let scrolls = !entries.isEmpty && listFrame.height < natural.height
        surfaces.listHost.rootView = list(width: width,
                                          rowsHeight: scrolls ? max(0, listFrame.height - 2 * Metrics.Glance.listPadding) : nil)
        Self.show(surfaces.list, at: listFrame)
    }

    private func hide() {
        endDrag()
        stopSnap()
        settle?.cancel()
        presence = PopoverPresence()
        surfaces?.strip.orderOut(nil)
        surfaces?.list.orderOut(nil)
    }

    /// The pointer entered or left the strip (`anchor`) or the list (`surface`).
    private func pointer(_ event: PopoverPresence.Event) {
        // The pointer rides on the strip during a drag: the list stays closed (GW-R7).
        guard drag == nil else { return }
        switch presence.handle(event) {
        case .none: break
        case .changed: render()
        case .settle(let delay):
            settle?.cancel()
            settle = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                let wasOpen = presence.isOpen
                presence.settle()
                if presence.isOpen != wasOpen { render() }
            }
        }
    }

    private func makeSurfaces() -> Surfaces {
        let made = Surfaces()
        made.stripHost.onPointer = { [weak self] inside in self?.pointer(.anchorHover(inside)) }
        made.listHost.onPointer = { [weak self] inside in self?.pointer(.surfaceHover(inside)) }
        made.strip.drag = GlanceDragHandlers(began: { [weak self] in self?.beginDrag(at: $0) },
                                             moved: { [weak self] in self?.dragMoved(to: $0) },
                                             ended: { [weak self] in self?.dragEnded(at: $0) })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: made.strip,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        })
        surfaces = made
        return made
    }

    // MARK: Drag

    private func beginDrag(at start: CGPoint) {
        endDrag()
        guard preferences.isEnabled, let surfaces, surfaces.strip.isVisible else { return }
        settle?.cancel()
        presence = PopoverPresence()
        surfaces.list.orderOut(nil)
        stopSnap()
        let startFrame = surfaces.strip.frame
        let session = GlanceDragSession(screens: GlanceScreen.connected(), sizes: stripSizes(), pointer: start, stripFrame: startFrame)
        let made = Drag(start: start, startFrame: startFrame, session: session)
        drag = made
        draw(made)
    }

    private func dragMoved(to pointer: CGPoint) {
        guard let drag, let surfaces else { return }
        surfaces.strip.setFrameOrigin(drag.session.stripOrigin(at: pointer))
        let target = drag.session.target(at: pointer)
        guard target != drag.target else { return }
        drag.target = target
        draw(drag)
    }

    /// Saves the nearest slot (GW-R7) and moves the strip into it. A release on the slot it came from saves the same
    /// placement, which changes nothing observable, so the move is started here and not left to `follow()`.
    private func dragEnded(at pointer: CGPoint) {
        guard let drag else { return }
        endDrag()
        drag.session.drop(at: pointer, into: preferences)
        render(snap: true)
    }

    /// The overlays leave the screen; nothing is saved.
    private func endDrag() {
        guard let drag else { return }
        self.drag = nil
        for overlay in drag.overlays.values { overlay.panel.orderOut(nil) }
    }

    /// A render during a drag: the screens or the entries changed, so the slots are measured and drawn again.
    private func refresh(_ drag: Drag) {
        let screens = GlanceScreen.connected(), sizes = stripSizes()
        guard screens != drag.session.screens || sizes != drag.session.sizes else { return }
        drag.session = GlanceDragSession(screens: screens, sizes: sizes, pointer: drag.start, stripFrame: drag.startFrame)
        drag.target = drag.session.target(at: NSEvent.mouseLocation)
        draw(drag)
    }

    /// One overlay per screen of the session, over its visible frame; overlays of screens that left are removed. The strip
    /// is ordered back above them.
    private func draw(_ drag: Drag) {
        var added = false
        for screen in drag.session.screens {
            let overlay = drag.overlays[screen.id] ?? {
                added = true
                return Drag.Overlay()
            }()
            drag.overlays[screen.id] = overlay
            overlay.host.rootView = GlanceDropSlots(outlines: drag.session.outlines(on: screen, target: drag.target),
                                                    canvas: screen.visibleFrame.size)
            if overlay.panel.frame != screen.visibleFrame { overlay.panel.setFrame(screen.visibleFrame, display: true) }
            if !overlay.panel.isVisible { overlay.panel.orderFrontRegardless() }
        }
        let current = Set(drag.session.screens.map(\.id))
        for (id, overlay) in drag.overlays where !current.contains(id) {
            overlay.panel.orderOut(nil)
            drag.overlays[id] = nil
        }
        if added { surfaces?.strip.orderFrontRegardless() }
    }

    /// The widget's size in each axis with the current entries, for the slots' outlines.
    private func stripSizes() -> GlanceStripSizes {
        guard let feed, let surfaces else { return GlanceStripSizes(horizontal: .zero, vertical: .zero) }
        func size(_ axis: GlanceAxis) -> CGSize {
            let slot = GlanceSlot.allCases.first { $0.axis == axis } ?? GlanceSlot.defaultSlot
            surfaces.measureStrip.rootView = GlanceStripView(strip: GlanceStrip(entries: feed.entries, slot: slot), isOnScreen: false,
                                                             open: { _ in })
            return Self.whole(surfaces.measureStrip.fittingSize)
        }
        return GlanceStripSizes(horizontal: size(.horizontal), vertical: size(.vertical))
    }

    /// The release: the strip takes its slot's size at once (its content already has the slot's axis), then moves into the
    /// slot along `GlanceSnap`, eased out, without overshoot (FE-M1). Under Reduce Motion it is placed at once. The move is
    /// stepped here rather than by the window animator, so it is the same task a test can wait on.
    private func move(_ panel: GlancePanel, to frame: CGRect) {
        stopSnap()
        let from = CGRect(origin: panel.frame.origin, size: frame.size)
        Self.show(panel, at: from)
        guard from != frame, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            Self.show(panel, at: frame)
            return
        }
        let task = Task { [weak self] in
            let clock = ContinuousClock()
            let begin = clock.now
            let duration = Duration.seconds(Metrics.Glance.snapDuration)
            while !Task.isCancelled {
                let progress = min(1, (clock.now - begin) / duration)
                panel.setFrameOrigin(GlanceSnap.origin(from: from.origin, to: frame.origin, progress: progress))
                if progress >= 1 { break }
                try? await Task.sleep(for: .seconds(Metrics.Glance.snapFrame))
            }
            guard !Task.isCancelled, let self else { return }
            snapMove = nil
            Self.show(panel, at: frame)
        }
        snapMove = (frame, task)
    }

    private func stopSnap() {
        snapMove?.task.cancel()
        snapMove = nil
    }

    private static func show(_ panel: GlancePanel, at frame: CGRect) {
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
        panel.invalidateShadow()
    }

    /// Whole points, so the window never cuts a fraction of its content.
    private static func whole(_ size: CGSize) -> CGSize {
        CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    /// The two panels, their content, and an off-screen view that measures the list before it is placed.
    @MainActor
    private final class Surfaces {
        let strip = GlancePanel()
        let list = GlancePanel()
        let stripHost = GlanceHostingView(rootView: GlanceStripView(strip: GlanceStrip(entries: .empty, slot: .defaultSlot), isOnScreen: false,
                                                                    open: { _ in }))
        let listHost = GlanceHostingView(rootView: Surfaces.blankList)
        let measureHost = NSHostingView(rootView: Surfaces.blankList)
        let measureStrip = NSHostingView(rootView: GlanceStripView(strip: GlanceStrip(entries: .empty, slot: .defaultSlot), isOnScreen: false,
                                                                   open: { _ in }))

        private static var blankList: GlanceListView {
            GlanceListView(entries: [], note: "", isOnScreen: false, hint: { _ in "" }, open: { _ in })
        }

        init() {
            strip.contentView = stripHost
            list.contentView = listHost
        }
    }

    /// A drag in progress: where it started, the geometry, the highlighted slot and one overlay per screen.
    @MainActor
    private final class Drag {
        let start: CGPoint
        let startFrame: CGRect
        var session: GlanceDragSession
        var target: GlancePlacement.Resolved?
        var overlays: [GlanceScreenID: Overlay] = [:]

        init(start: CGPoint, startFrame: CGRect, session: GlanceDragSession) {
            self.start = start
            self.startFrame = startFrame
            self.session = session
            target = session.target(at: start)
        }

        /// A screen's click-through layer and its slots.
        @MainActor
        final class Overlay {
            let panel = GlancePanel.dropOverlay()
            let host = NSHostingView(rootView: GlanceDropSlots(outlines: [], canvas: .zero))

            init() {
                // The panel is the screen's visible frame; the content never sizes it.
                host.sizingOptions = []
                panel.contentView = host
            }
        }
    }
}
