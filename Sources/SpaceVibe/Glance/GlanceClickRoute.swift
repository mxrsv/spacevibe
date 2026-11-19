import AppKit

/// Where a click on a glance entry or list row goes (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW5, GW6,
/// GW-R6): the GUI app that hosts the session, brought forward; with no such app, or when macOS refuses to bring it
/// forward, SpaceVibe's Activity page at that session. It never signals and never starts a process (S-R4).
///
/// The three steps are injected so a test drives the decision without a window or a real process table.
@MainActor
struct GlanceClickRoute {
    enum Outcome: Equatable {
        case hostApp(HostApp)
        /// The Activity item id (`ActivitySessionItem.id`, the same as `GlanceEntry.id`).
        case activity(itemID: String)
    }

    /// The host app of a session pid, or nil (tmux, ssh, a dead parent).
    var hostApp: (Int) -> HostApp?
    /// Brings the app forward; false when macOS refused or the app is gone.
    var activate: (HostApp) -> Bool
    /// Brings SpaceVibe forward on Activity with that item current.
    var openActivity: (String) -> Void

    @discardableResult
    func open(_ entry: GlanceEntry) -> Outcome {
        if let app = hostApp(entry.pid), activate(app) { return .hostApp(app) }
        openActivity(entry.id)
        return .activity(itemID: entry.id)
    }

    /// The name the hovered row shows for where its click goes.
    func destination(of entry: GlanceEntry) -> String {
        guard let app = hostApp(entry.pid) else { return GlanceWording.activity }
        return app.name ?? app.bundleIdentifier ?? GlanceWording.activity
    }

    /// The live route: the in-process parent walk (`sysctl`, `NSRunningApplication`) and cooperative activation.
    static func live(openActivity: @escaping (String) -> Void) -> GlanceClickRoute {
        GlanceClickRoute(
            hostApp: { pid in pid_t(exactly: pid).flatMap { HostAppResolver.hostApp(of: $0) } },
            activate: { HostAppResolver.activate($0) },
            openActivity: openActivity
        )
    }
}
