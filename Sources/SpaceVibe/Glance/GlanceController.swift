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
/// - Countdown (spec `docs/specs/2026-11-19-limit-reset-countdown.md`, LC-R5 to LC-R8): with the switch on, the limits are
///   read every `GlanceLimitsFeed.readInterval`. While a window counts, a third panel, the pill, sits beside the strip
///   (`GlanceSlot.pillFrame`) and moves with it on a drag and a snap; hovering it opens the same list, which then ends with
///   the Limits group. The controller draws again on each change of the first clock and when the next window starts to count
///   (`GlanceCountdown.nextWake`), never more often than once a second, not at all with nothing counting soon, and not while
///   neither the strip nor the pill is visible on screen (the occlusion observers draw again when one is).
/// - Press (GW-R6): from the button going down on the strip until its click or drop has been handed on, no render runs
///   (`GlanceRenderGate`); the last one asked for runs right after. So a report never redraws the strip under a held press,
///   and the replayed press reaches the entry it went down on. A press whose release never comes is ended by
///   `GlanceLostRelease` or by the screen locking, sleeping or changing Space.
/// - Order: while the pointer is on the strip, the pill or the list (or the list is open), the entries keep the order they
///   were shown in (`GlanceEntries.keepingOrder`), so rows do not move under the pointer on each report.
@MainActor
final class GlanceController {
    static let shared = GlanceController()

    /// The app's shell, set once at launch: the click fallback focuses a session on its Activity page (GW6).
    var shell: ShellModel?
    /// The redesign's frame, set by `AppFrame` when it appears (only with `SPACEVIBE_REDESIGN=1`): a click that falls back to
    /// SpaceVibe then sets the frame's one route (AR5, GW6, LC-R7) instead of the v5 shell's.
    weak var frame: FrameRouter?

    private let preferences: GlancePreferences
    private let countdown: LimitsCountdownPreferences
    private let makeCore: @MainActor () -> any CoreService
    private let makeLimits: @MainActor () -> LimitsModel
    private let limitsReadInterval: Duration
    private let screens: @MainActor () -> [GlanceScreen]
    /// The surface and text tokens every widget view draws with (RD34): the redesign's only with its switch on.
    let tokens: GlanceTokens
    private(set) var feed: GlanceFeed?
    private(set) var limitsFeed: GlanceLimitsFeed?
    private var openMainWindow: () -> Void = {}
    private var surfaces: Surfaces?
    private var presence = PopoverPresence()
    private var settle: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    /// Set from the moment a press passes the threshold until the release.
    private var drag: Drag?
    /// The strip's move into its slot after a release; a render that wants the same frame leaves it running.
    private var snapMove: (target: CGRect, task: Task<Void, Never>)?
    /// The pill's frame with the strip's origin at zero, while a window counts; nil hides the pill.
    private var pillOffset: CGRect?
    /// The next draw the countdown asked for.
    private var tick: (wake: Date, task: Task<Void, Never>)?
    /// The pointer on the strip or on the pill: either one is the list's anchor (LC-R6).
    private var overStrip = false
    private var overPill = false
    private var overList = false
    /// Renders held back while a press on the strip is undecided or dragging.
    private var gate = GlanceRenderGate()
    /// Reads the button while a press is held, to end one whose release never came.
    private var pressWatch: Task<Void, Never>?
    /// The entries as last drawn, in the order they were drawn.
    private var drawn = GlanceEntries.empty

    /// `makeCore` and `makeLimits` are asked once, at `start`; the app's Go core and its one `LimitsModel` when nil.
    /// `limitsReadInterval`, `screens` and `surface` are for tests: the widget reads every `GlanceLimitsFeed.readInterval` and places
    /// itself on the connected screens.
    init(preferences: GlancePreferences? = nil, countdown: LimitsCountdownPreferences? = nil,
         makeCore: (@MainActor () -> any CoreService)? = nil, makeLimits: (@MainActor () -> LimitsModel)? = nil,
         limitsReadInterval: Duration = GlanceLimitsFeed.readInterval,
         screens: (@MainActor () -> [GlanceScreen])? = nil, surface: LaunchMode.Surface = LaunchMode.surface()) {
        tokens = .forSurface(surface)
        self.preferences = preferences ?? .shared
        self.countdown = countdown ?? .shared
        self.makeCore = makeCore ?? { AppEnvironment.shared.goCore }
        self.makeLimits = makeLimits ?? { AppEnvironment.shared.limits }
        self.limitsReadInterval = limitsReadInterval
        self.screens = screens ?? { GlanceScreen.connected() }
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
        guard Self.runs(in: mode, environment: environment) else { return }
        begin(openMainWindow: openMainWindow)
    }

    /// Tests only: `start` without the launch gate, which refuses every test run (`SPACEVIBE_TEST=1`). The app never calls
    /// it; a test passes a fake core and throwaway preferences, and screens off every display.
    func startSkippingLaunchGateForTests(openMainWindow: @escaping () -> Void = {}) {
        begin(openMainWindow: openMainWindow)
    }

    /// Tests only: true while the strip, the pill or the list is ordered in.
    var isShowingForTests: Bool {
        guard let surfaces else { return false }
        return surfaces.strip.isVisible || surfaces.pill.isVisible || surfaces.list.isVisible
    }

    private func begin(openMainWindow: @escaping () -> Void) {
        guard feed == nil else { return }
        feed = GlanceFeed(core: makeCore())
        limitsFeed = GlanceLimitsFeed(limits: makeLimits(), interval: limitsReadInterval)
        self.openMainWindow = openMainWindow
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        })
        // A press cannot outlive the screen locking or sleeping, or the Space changing: its release may never reach the strip.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancelPress() }
            })
        }
        observers.append(DistributedNotificationCenter.default().addObserver(forName: Self.screenLocked, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelPress() }
        })
        follow()
        sync()
    }

    private static let screenLocked = Notification.Name("com.apple.screenIsLocked")

    // MARK: State

    /// Re-armed after every change: Observation reports one change per registration.
    private func follow() {
        guard let feed else { return }
        withObservationTracking {
            _ = preferences.isEnabled
            _ = preferences.placement
            _ = feed.entries
            _ = feed.failure
            _ = limitsFeed?.results
            _ = countdown.weeklyLead
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
            if limitsFeed?.isRunning == false { limitsFeed?.start() }
            render()
        } else {
            // `stop()` clears the feed, which is a change: call it only once, or it would wake this method again.
            if feed.isRunning { feed.stop() }
            if limitsFeed?.isRunning == true { limitsFeed?.stop() }
            hide()
        }
    }

    private var route: GlanceClickRoute {
        .live { [weak self] itemID in self?.showActivity(itemID) }
    }

    /// LC-R7: SpaceVibe forward, its main window open, Limits with that window current.
    private func showLimits(_ window: GlanceCountdownWindow) {
        NSApp.activate()
        openMainWindow()
        if routeIntoFrame(.limits(windowID: window.id)) { return }
        guard let limits = limitsFeed?.limits else { return }
        shell?.openLimits(windowID: window.id, in: limits)
    }

    /// GW6: SpaceVibe forward, its main window open, Activity at that session.
    private func showActivity(_ itemID: String) {
        NSApp.activate()
        openMainWindow()
        if routeIntoFrame(.activity(itemID: itemID)) { return }
        shell?.openActivity(sessionItemID: itemID)
    }

    /// Where a click that falls back to SpaceVibe lands.
    enum Destination: Equatable {
        /// The Limits page with that Window selected (`cli:windowID`, LC-R7).
        case limits(windowID: String)
        /// The Activity page with that session selected (`cli:sessionID`, GW6).
        case activity(itemID: String)
    }

    /// Sets the redesign frame's one route (AR5) when the frame is there; false leaves the click to the v5 shell.
    @discardableResult
    func routeIntoFrame(_ destination: Destination) -> Bool {
        guard let frame else { return false }
        switch destination {
        case .limits(let windowID): frame.go(to: .window(windowID))
        case .activity(let itemID): frame.go(to: .session(itemID))
        }
        return true
    }

    // MARK: Panels

    /// `snap`: the strip moves into its slot instead of jumping there (a release).
    /// While a press on the strip is held, the render is noted and runs when the press is over (`GlanceRenderGate`); a drag's
    /// overlays still follow new entries.
    private func render(snap: Bool = false) {
        guard gate.admit(snap: snap) else {
            if let drag { refresh(drag) }
            return
        }
        guard preferences.isEnabled, let feed,
              let placed = GlancePlacement.resolve(preferences.placement, screens: screens())
        else {
            hide()
            return
        }
        let surfaces = self.surfaces ?? makeSurfaces()
        let onScreen = surfaces.strip.isVisible && surfaces.strip.occlusionState.contains(.visible)
        let route = route
        let now = Date()
        let counting = GlanceCountdown.counting(limitsFeed?.results ?? [], now: now, weeklyLead: countdown.weeklyLead)
        drawn = holdsOrder ? feed.entries.keepingOrder(of: drawn) : feed.entries

        surfaces.stripHost.rootView = GlanceStripView(strip: GlanceStrip(entries: drawn, slot: placed.slot), isOnScreen: onScreen,
                                                      failure: feed.failure, tokens: tokens, open: { route.open($0) })
        let stripSize = Self.whole(surfaces.stripHost.fittingSize)
        layoutPill(counting.first, now: now, slot: placed.slot, stripSize: stripSize)
        defer { armTick() }
        let stripFrame = placed.slot.frame(for: stripSize, in: placed.screen.visibleFrame)
        if snap {
            move(surfaces.strip, to: stripFrame)
        } else if snapMove?.target != stripFrame {
            // No move, or one toward a frame this render no longer wants: the strip goes straight to its frame.
            stopSnap()
            Self.show(surfaces.strip, at: stripFrame)
        }
        placePill()
        // A snap placed at once (Reduce Motion, or released in its slot) ends here; a stepped one reads it when it lands.
        if snap, snapMove == nil { readAnchorHover() }

        guard presence.isOpen else {
            surfaces.list.orderOut(nil)
            return
        }
        let entries = drawn.all
        let note = feed.failure ?? GlanceWording.noSession
        func list(width: CGFloat?, rowsHeight: CGFloat?, limits: [GlanceCountdownWindow] = counting) -> GlanceListView {
            GlanceListView(entries: entries, note: note, failure: feed.failure, width: width, rowsHeight: rowsHeight, isOnScreen: onScreen,
                           hint: { route.destination(of: $0) }, open: { route.open($0) },
                           limits: limits, now: now, openLimit: { [weak self] in self?.showLimits($0) }, tokens: tokens)
        }
        // The list's own size first, unscrolled; a bare sentence wider than a list wraps at the list's width.
        surfaces.measureHost.rootView = list(width: nil, rowsHeight: nil)
        var natural = Self.whole(surfaces.measureHost.fittingSize)
        var width: CGFloat?
        let bare = entries.isEmpty && counting.isEmpty
        if bare, natural.width > Metrics.Glance.listWidth {
            width = Metrics.Glance.listWidth
            surfaces.measureHost.rootView = list(width: width, rowsHeight: nil)
            natural = Self.whole(surfaces.measureHost.fittingSize)
        } else if bare {
            width = natural.width
        }
        let wanted = CGSize(width: natural.width, height: min(natural.height, Metrics.Glance.listMaxHeight))
        // The list opens from the strip and the pill together, so it never covers the pill.
        let anchor = pillOffset.map { stripFrame.union($0.offsetBy(dx: stripFrame.minX, dy: stripFrame.minY)) } ?? stripFrame
        let listFrame = placed.slot.listFrame(for: wanted, widgetFrame: anchor, in: placed.screen.visibleFrame)
        let scrolls = !entries.isEmpty && listFrame.height < natural.height
        var rowsHeight: CGFloat?
        if scrolls {
            // The pinned Limits group keeps its height; the session rows get the rest.
            var group: CGFloat = 0
            if !counting.isEmpty {
                surfaces.measureHost.rootView = list(width: width, rowsHeight: nil, limits: [])
                group = natural.height - Self.whole(surfaces.measureHost.fittingSize).height
            }
            rowsHeight = max(0, listFrame.height - 2 * Metrics.Glance.listPadding - group)
        }
        surfaces.listHost.rootView = list(width: width, rowsHeight: rowsHeight)
        Self.show(surfaces.list, at: listFrame)
    }

    private func hide() {
        endDrag()
        // The press ends with the widget; nothing held back is drawn.
        gate = GlanceRenderGate()
        stopPressWatch()
        surfaces?.strip.cancelPointer()
        stopSnap()
        stopTick()
        settle?.cancel()
        presence = PopoverPresence()
        overStrip = false
        overPill = false
        overList = false
        drawn = .empty
        pillOffset = nil
        surfaces?.strip.orderOut(nil)
        surfaces?.pill.orderOut(nil)
        surfaces?.list.orderOut(nil)
    }

    // MARK: Countdown

    /// Draws the pill for the window that resets first and keeps its frame beside a strip of `stripSize` in `slot`; with no
    /// window counting, the pill leaves (LC-R5).
    private func layoutPill(_ window: GlanceCountdownWindow?, now: Date, slot: GlanceSlot, stripSize: CGSize) {
        guard let surfaces else { return }
        guard let window else {
            pillOffset = nil
            surfaces.pill.orderOut(nil)
            // A panel ordered out under the pointer reports no exit: the pointer has left the pill all the same.
            if overPill { anchorHover(pill: false) }
            return
        }
        surfaces.pillHost.rootView = GlanceCountdownPillView(window: window, now: now, axis: slot.axis, tokens: tokens,
                                                             open: { [weak self] in self?.showLimits($0) })
        let size = Self.whole(surfaces.pillHost.fittingSize)
        pillOffset = slot.pillFrame(for: size, beside: CGRect(origin: .zero, size: stripSize))
    }

    /// The pill beside the strip where the strip is now: after a render, on each step of a drag and of a snap.
    private func placePill() {
        guard let surfaces else { return }
        guard let pillOffset, surfaces.strip.isVisible else {
            surfaces.pill.orderOut(nil)
            return
        }
        Self.show(surfaces.pill, at: pillOffset.offsetBy(dx: surfaces.strip.frame.minX, dy: surfaces.strip.frame.minY))
    }

    /// Schedules the next draw the countdown needs (`GlanceCountdown.nextWake`): the next clock change while a window counts,
    /// the start of the next countdown otherwise, nothing with no window ahead. A wake already set for that moment stays.
    private func armTick() {
        guard preferences.isEnabled, isOnScreen, let limitsFeed,
              let wake = GlanceCountdown.nextWake(limitsFeed.results, now: Date(), weeklyLead: countdown.weeklyLead) else {
            stopTick()
            return
        }
        if let tick, abs(tick.wake.timeIntervalSince(wake)) < GlanceCountdown.wakeSlack { return }
        stopTick()
        let task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, wake.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            tick = nil
            render()
        }
        tick = (wake, task)
    }

    private func stopTick() {
        tick?.task.cancel()
        tick = nil
    }

    /// The strip or the pill is ordered in and not covered (GW-R11: nothing redraws for a widget nobody can see).
    private var isOnScreen: Bool {
        guard let surfaces else { return false }
        return [surfaces.strip, surfaces.pill].contains { $0.isVisible && $0.occlusionState.contains(.visible) }
    }

    /// The pointer is on the strip, the pill or the list, or the list is open: the rows keep their order.
    private var holdsOrder: Bool { overStrip || overPill || overList || presence.isOpen }

    /// The pointer entered or left the strip or the pill; the list's anchor is both together.
    private func anchorHover(strip: Bool? = nil, pill: Bool? = nil) {
        let before = overStrip || overPill
        if let strip { overStrip = strip }
        if let pill { overPill = pill }
        let inside = overStrip || overPill
        if inside != before { pointer(.anchorHover(inside)) }
    }

    /// The pointer entered or left the anchor (the strip or the pill) or the list (`surface`).
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
        made.stripHost.onPointer = { [weak self] inside in self?.anchorHover(strip: inside) }
        made.pillHost.onPointer = { [weak self] inside in self?.anchorHover(pill: inside) }
        made.listHost.onPointer = { [weak self] inside in
            self?.overList = inside
            self?.pointer(.surfaceHover(inside))
        }
        made.strip.drag = GlanceDragHandlers(holding: { [weak self] in self?.holding($0) },
                                             began: { [weak self] in self?.beginDrag(at: $0) },
                                             moved: { [weak self] in self?.dragMoved(to: $0) },
                                             ended: { [weak self] in self?.dragEnded(at: $0) },
                                             cancelled: { [weak self] in self?.dragCancelled() })
        for panel in [made.strip, made.pill] {
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: panel,
                                                                    queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.render() }
            })
        }
        surfaces = made
        return made
    }

    // MARK: Press

    /// The button went down on the strip (true) or the press is over (false), after its click or drop was handed on.
    private func holding(_ held: Bool) {
        if held {
            gate.hold()
            watchPress()
        } else {
            stopPressWatch()
            if let snap = gate.release() { render(snap: snap) }
        }
    }

    /// Reads the left button every `GlanceLostRelease.checkInterval` while a press is held, and ends the press once its
    /// release is surely lost.
    private func watchPress() {
        stopPressWatch()
        pressWatch = Task { [weak self] in
            var lost = GlanceLostRelease()
            while !Task.isCancelled {
                try? await Task.sleep(for: GlanceLostRelease.checkInterval)
                guard !Task.isCancelled else { return }
                if lost.observe(leftButtonDown: NSEvent.pressedMouseButtons & 1 != 0) {
                    self?.cancelPress()
                    return
                }
            }
        }
    }

    private func stopPressWatch() {
        pressWatch?.cancel()
        pressWatch = nil
    }

    /// Ends a held press or a drag with no click and no drop; the strip goes back to its saved slot.
    private func cancelPress() {
        surfaces?.strip.cancelPointer()
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
        let session = GlanceDragSession(screens: screens(), sizes: stripSizes(), pointer: start, stripFrame: startFrame)
        let made = Drag(start: start, startFrame: startFrame, session: session)
        drag = made
        // An ordered-out list reports no exit; the strip and the pill are read from the pointer (no list opens mid-drag).
        overList = false
        readAnchorHover()
        draw(made)
    }

    private func dragMoved(to pointer: CGPoint) {
        guard let drag, let surfaces else { return }
        surfaces.strip.setFrameOrigin(drag.session.stripOrigin(at: pointer))
        placePill()
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

    /// A drag whose release never came: nothing is saved, and the strip moves back into its slot.
    private func dragCancelled() {
        guard drag != nil else { return }
        endDrag()
        render(snap: true)
    }

    /// Reads whether the pointer is on the strip or the pill from the frames, and tells the list. A tracking area reports
    /// no exit when its panel moves away under a still pointer, so after a drag and its snap the last report can be stale.
    private func readAnchorHover() {
        guard let surfaces else { return }
        let mouse = NSEvent.mouseLocation
        overStrip = surfaces.strip.isVisible && surfaces.strip.frame.contains(mouse)
        overPill = surfaces.pill.isVisible && surfaces.pill.frame.contains(mouse)
        pointer(.anchorHover(overStrip || overPill))
    }

    /// The overlays leave the screen; nothing is saved.
    private func endDrag() {
        guard let drag else { return }
        self.drag = nil
        for overlay in drag.overlays.values { overlay.panel.orderOut(nil) }
    }

    /// A render during a drag: the screens or the entries changed, so the slots are measured and drawn again.
    private func refresh(_ drag: Drag) {
        let screens = self.screens(), sizes = stripSizes()
        guard screens != drag.session.screens || sizes != drag.session.sizes else { return }
        drag.session = GlanceDragSession(screens: screens, sizes: sizes, pointer: drag.start, stripFrame: drag.startFrame)
        drag.target = drag.session.target(at: NSEvent.mouseLocation)
        draw(drag)
    }

    /// One overlay per screen of the session, over its visible frame; overlays of screens that left are removed. The strip
    /// and the pill are ordered back above them.
    private func draw(_ drag: Drag) {
        var added = false
        for screen in drag.session.screens {
            let overlay = drag.overlays[screen.id] ?? {
                added = true
                return Drag.Overlay()
            }()
            drag.overlays[screen.id] = overlay
            overlay.host.rootView = GlanceDropSlots(outlines: drag.session.outlines(on: screen, target: drag.target),
                                                    canvas: screen.visibleFrame.size, tokens: tokens)
            if overlay.panel.frame != screen.visibleFrame { overlay.panel.setFrame(screen.visibleFrame, display: true) }
            if !overlay.panel.isVisible { overlay.panel.orderFrontRegardless() }
        }
        let current = Set(drag.session.screens.map(\.id))
        for (id, overlay) in drag.overlays where !current.contains(id) {
            overlay.panel.orderOut(nil)
            drag.overlays[id] = nil
        }
        if added {
            if surfaces?.pill.isVisible == true { surfaces?.pill.orderFrontRegardless() }
            surfaces?.strip.orderFrontRegardless()
        }
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
                self?.placePill()
                if progress >= 1 { break }
                try? await Task.sleep(for: .seconds(Metrics.Glance.snapFrame))
            }
            guard !Task.isCancelled, let self else { return }
            snapMove = nil
            Self.show(panel, at: frame)
            placePill()
            readAnchorHover()
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
        let pill = GlancePanel()
        let list = GlancePanel()
        let stripHost = GlanceHostingView(rootView: GlanceStripView(strip: GlanceStrip(entries: .empty, slot: .defaultSlot), isOnScreen: false,
                                                                    open: { _ in }))
        let listHost = GlanceHostingView(rootView: Surfaces.blankList)
        /// Nil until a window counts.
        let pillHost = GlanceHostingView<GlanceCountdownPillView?>(rootView: nil)
        let measureHost = NSHostingView(rootView: Surfaces.blankList)
        let measureStrip = NSHostingView(rootView: GlanceStripView(strip: GlanceStrip(entries: .empty, slot: .defaultSlot), isOnScreen: false,
                                                                   open: { _ in }))

        private static var blankList: GlanceListView {
            GlanceListView(entries: [], note: "", isOnScreen: false, hint: { _ in "" }, open: { _ in })
        }

        init() {
            strip.contentView = stripHost
            pill.contentView = pillHost
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
