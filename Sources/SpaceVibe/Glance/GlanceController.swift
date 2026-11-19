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

    private func render() {
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
        let stripFrame = placed.slot.frame(for: Self.whole(surfaces.stripHost.fittingSize), in: placed.screen.visibleFrame)
        Self.show(surfaces.strip, at: stripFrame)

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
        settle?.cancel()
        presence = PopoverPresence()
        surfaces?.strip.orderOut(nil)
        surfaces?.list.orderOut(nil)
    }

    /// The pointer entered or left the strip (`anchor`) or the list (`surface`).
    private func pointer(_ event: PopoverPresence.Event) {
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
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: made.strip,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        })
        surfaces = made
        return made
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

        private static var blankList: GlanceListView {
            GlanceListView(entries: [], note: "", isOnScreen: false, hint: { _ in "" }, open: { _ in })
        }

        init() {
            strip.contentView = stripHost
            list.contentView = listHost
        }
    }
}
