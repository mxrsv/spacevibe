import AppKit
import Foundation
import Observation
import ObjectiveC

/// The redesign Activity page's own view state and its actions (plan AR3: page state never lives in the store). The tab,
/// the `All CLIs` pick, the ticks, the dismissed failures, the open Stop alert, and when the latest report arrived. Writes
/// go through `FrameWrites` only (AR4); the one write here is Stop, through `FrameWrite.stop`, which calls `activity.stop`
/// (S-R6: only `activity.Stop` signals a process). Stop has no Undo; the page confirms first (RD-R16).
///
/// One instance lives as long as the frame's `FrameModel` (`ActivityPageState.of(_:)`), so the tab and the dismissals survive
/// a visit to another page, as v5's dismissals last the session (G13); ticks and the alert do not.
@MainActor
@Observable
final class ActivityPageState {
    var tab: ActivityTable = .sessions
    /// The `All CLIs` menu: nil for all.
    var scope: String?
    var isScopeMenuOpen = false
    private(set) var ticked: Set<String> = []
    /// Failures the user dismissed, by `ActivityFailureItem.dismissKey`: a dismissal holds until the same failure fails again.
    private(set) var dismissed: Set<String> = []
    /// The sessions the open Stop alert names; empty when it is closed.
    private(set) var stopTargets: [ActivitySessionRow] = []
    /// The other tab's selection, put back when the user returns to it.
    @ObservationIgnored private var parkedSelection: [ActivityTable: String] = [:]

    /// When the report on screen arrived: the ages in it are as of then (the store keeps no time).
    @ObservationIgnored private var seenReport: CoreActivityReport?
    @ObservationIgnored private var seenAt = Date()

    /// What finds the GUI app that hosts a session (RD36: `HostAppResolver`, no process started, no Automation permission),
    /// and what brings it forward. A test replaces both.
    @ObservationIgnored var hostApp: (Int) -> HostApp? = { HostAppResolver.hostApp(of: pid_t(clamping: $0)) }
    @ObservationIgnored var activateHost: (HostApp) -> Bool = { HostAppResolver.activate($0) }
    @ObservationIgnored var copyToPasteboard: (String) -> Void = { text in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    var isStopAlertOpen: Bool { !stopTargets.isEmpty }

    // MARK: Inputs

    /// The page's input from the frame's store and route.
    func input(model: FrameModel, now: Date = Date()) -> ActivityPageInput {
        let store = model.store
        let world = store.world(now: now)
        let report = store.snapshot.activity
        return ActivityPageInput(
            clis: world.clis, sessions: world.sessions, failures: report?.failures ?? [], hasReport: report != nil,
            source: store.states[.activity],
            figure: world.figure(for: .activity, loading: store.loading, failed: store.failedEmpty),
            tab: tab, scope: scope, dismissed: dismissed, ticked: ticked, selection: model.router.route.selection,
            elapsedMs: elapsedMs(for: report, now: now), now: now)
    }

    /// Milliseconds since `report` was first seen; a new report starts the count again.
    func elapsedMs(for report: CoreActivityReport?, now: Date) -> Double {
        if report != seenReport {
            seenReport = report
            seenAt = now
        }
        return max(0, now.timeIntervalSince(seenAt) * 1000)
    }

    // MARK: Tabs, scope, ticks

    /// Another tab: its own selection comes back, ticks clear (a tick never outlives the list it was made in).
    func show(_ next: ActivityTable, router: FrameRouter) {
        guard next != tab else { return }
        parkedSelection[tab] = router.route.selection
        tab = next
        ticked = []
        router.select(parkedSelection[next])
    }

    func setScope(_ next: String?) {
        scope = next
        ticked = []
        isScopeMenuOpen = false
    }

    func toggleTick(_ id: String) {
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    /// The head checkbox: ticks every stoppable row shown, or clears them when all are ticked.
    func toggleAll(_ data: ActivityPageData) {
        let ids = Set(data.stoppableIDs)
        ticked = data.headerCheck == .on ? ticked.subtracting(ids) : ticked.union(ids)
    }

    /// Leaving the page: ticks, the menu and the alert close.
    func pageLeft() {
        ticked = []
        isScopeMenuOpen = false
        stopTargets = []
    }

    // MARK: Stop

    /// Opens the alert for exactly `rows` (a row's `Stop…`, or the toolbar's ticked ones). Rows that cannot be stopped are
    /// left out; with none, nothing opens.
    func requestStop(_ rows: [ActivitySessionRow]) {
        stopTargets = rows.filter(\.canStop)
    }

    func cancelStop() { stopTargets = [] }

    /// The confirmed Stop. One session is one `FrameWrite.stop`; several are one write that stops each in turn through the
    /// same `FrameWrite.stop`, so the toast is one sentence (the mock: "Stopped 1 of 2 sessions. …"). Ticks of the stopped
    /// rows clear. The subscription then pushes the ended rows; nothing is shown as ended before the core says so (AR4).
    ///
    /// The targets are taken at once: the alert's binding clears them as it closes, after this runs.
    @discardableResult
    func confirmStop(writes: FrameWrites) -> Task<Void, Never>? {
        let targets = stopTargets
        stopTargets = []
        guard !targets.isEmpty else { return nil }
        ticked.subtract(targets.map(\.id))
        return Task { await writes.perform(Self.stopWrite(targets)) }
    }

    /// The write for `targets`. Pure apart from the core it is given, so a test runs it against a fake core.
    nonisolated static func stopWrite(_ targets: [ActivitySessionRow]) -> FrameWrite {
        let label = ActivityPageData.stoppedLabel(targets)
        if targets.count == 1 {
            return FrameWrite.stop(cli: targets[0].session.cli, sessionID: targets[0].session.id, label: label)
        }
        let steps = targets.map { (pid: $0.session.pid, write: FrameWrite.stop(cli: $0.session.cli, sessionID: $0.session.id, label: label)) }
        return FrameWrite(control: Self.stopManyControl, label: label, touches: [.activity]) { core in
            var refused: [(pid: Int, reason: String)] = []
            for step in steps {
                do { _ = try await step.write.run(core) } catch { refused.append((step.pid, (error as? CoreError)?.message ?? CoreError.unexpectedMessage)) }
            }
            if let sentence = ActivityPageData.partialStop(total: steps.count, refused: refused) { throw CoreError(sentence, status: 409) }
            return .done
        }
    }

    /// The pending key of the toolbar's Stop (one row's Stop is pending under `FrameWrite.stop`'s own key).
    nonisolated static let stopManyControl = "stop:many"

    nonisolated static func stopControl(_ row: ActivitySessionRow) -> String {
        "stop:\(row.session.cli.rawValue):\(row.session.id)"
    }

    // MARK: Show Terminal, copy, dismiss

    /// RD36: the app that runs the session, or nil (tmux, screen, ssh, a dead parent), which disables the button.
    func host(of row: ActivitySessionRow) -> HostApp? {
        row.isLive ? hostApp(row.session.pid) : nil
    }

    func showTerminal(_ row: ActivitySessionRow, toasts: ToastCenter) {
        guard let app = host(of: row) else {
            toasts.show(Self.noHost, tone: .danger)
            return
        }
        if activateHost(app) {
            toasts.show("Brought \(app.name ?? "the app that runs this session") to the front.")
        } else {
            toasts.show("\(app.name ?? "The terminal app") could not be brought to the front: it is no longer running.", tone: .danger)
        }
    }

    static let noHost = "Terminal app not found"

    func copySessionID(_ row: ActivitySessionRow, toasts: ToastCenter) {
        copyToPasteboard(row.session.id)
        toasts.show("Copied the session id.")
    }

    /// The whole command, never a cut one (the core cuts titles at 120 characters; v5 rule).
    func copyCommand(_ row: ActivityFailureRow, toasts: ToastCenter) {
        guard !row.item.isCut else {
            toasts.show("That command is longer than \(ActivityFailureTitle.limit) characters and SpaceVibe only has its start, so it was not copied.")
            return
        }
        copyToPasteboard(row.failure.title)
        toasts.show("Copied the command.")
    }

    /// Hides a failure until SpaceVibe quits or it fails again. Not a write to any file: its Undo stays on its own toast
    /// (GLOSSARY Undo).
    func dismiss(_ row: ActivityFailureRow, toasts: ToastCenter, router: FrameRouter) {
        let before = dismissed
        dismissed.insert(row.item.dismissKey)
        if router.route.selection == row.id { router.select(nil) }
        toasts.show("Dismissed until SpaceVibe quits. It comes back if it fails again.", sessionUndo: false, undo: { [weak self] in
            self?.dismissed = before
            toasts.show("Restored the failed command.")
        })
    }
}

extension ActivityPageState {
    private static var key: UInt8 = 0

    /// The one page state of this frame: made on first use and kept with the `FrameModel`, which owns every other part of the
    /// frame. (A page-state slot on `FrameModel` itself would replace this; it is the shared model's to add.)
    static func of(_ model: FrameModel) -> ActivityPageState {
        if let state = objc_getAssociatedObject(model, &key) as? ActivityPageState { return state }
        let state = ActivityPageState()
        objc_setAssociatedObject(model, &key, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }
}
