import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// Records every Stop and refuses the sessions the test names, with a 409 sentence like the core's.
private final class StopFakeCore: UnservedCore, @unchecked Sendable {
    private let lock = NSLock()
    private var _stopped: [String] = []
    var refuse: Set<String> = []

    var stopped: [String] { lock.withLock { _stopped } }

    override func activityStop(cli: CoreCLI, id: String) async throws -> CoreStopResult {
        lock.withLock { _stopped.append("\(cli.rawValue):\(id)") }
        if refuse.contains(id) { throw CoreError("The process could not be checked again, so nothing was sent to it.", status: 409) }
        return CoreStopResult(exited: true)
    }
}

/// The redesign's Activity page (RB-R7): what each state shows, that the hero equals the sidebar, the grouping by CLI, the
/// session glyph set, which rows Stop takes, the Stop write and its refusals, Show Terminal without a host app, and the
/// Failures tab.
@Suite("Activity page")
@MainActor
struct ActivityPageTests {
    private let now = FrameTestData.now

    private func session(_ id: String, cli: CoreCLI = .claude, state: CoreSessionState, project: String? = "web",
                         lastWrite: Double? = nil, pid: Int = 100, title: String? = nil, tool: CoreActivityTool? = nil,
                         cost: Double? = nil, reason: String = "") -> CoreActivitySession {
        var s = FrameTestData.session(id, cli: cli, state: state)
        s.project = project
        s.lastWriteAgoMs = lastWrite
        s.pid = pid
        s.ageMs = 14 * 60_000
        s.currentTool = tool
        s.cost = cost.map { CoreActivityCost(usd: $0, estimated: true) }
        s.stateReason = reason
        if let title { s.title = title }
        return s
    }

    private func failure(_ key: String, cli: CoreCLI = .claude, kind: CoreFailureKind = .command, title: String = "pnpm lint",
                         count: Int = 1, exit: Int? = 1, last: String? = "2027-01-15T07:00:00.000Z", laterPass: String? = nil,
                         reason: String = "Lint errors in 3 files") -> CoreActivityFailure {
        CoreActivityFailure(kind: kind, cli: cli, key: key, title: title, count: count, exit: exit, reason: reason,
                            projects: ["web"], sessions: 2, first: nil, last: last, laterPass: laterPass,
                            hook: kind == .hook ? CoreActivityHookRef(hash: "h", event: "PostToolUse") : nil)
    }

    /// The page's input from a snapshot, through the same `FrameWorld` the sidebar reads.
    private func input(_ sessions: [CoreActivitySession], failures: [CoreActivityFailure] = [], registry: [CoreRegistryCLI] = FrameTestData.registry,
                       loading: Set<FrameSource> = [], failed: Set<FrameSource> = [], source: FrameSourceState? = .ready,
                       hasReport: Bool = true) -> ActivityPageInput {
        var snapshot = FrameTestData.snapshot(FrameTestData.loadout(), registry: registry)
        snapshot.activity = hasReport ? CoreActivityReport(sessions: sessions, failures: failures, files: [], unmeasurable: [],
                                                          stats: CoreActivityStats(logs: 1, truncated: 0)) : nil
        let world = FrameWorld(snapshot: snapshot, now: now)
        return ActivityPageInput(clis: world.clis, sessions: world.sessions, failures: failures, hasReport: hasReport, source: source,
                                 figure: world.figure(for: .activity, loading: loading, failed: failed), now: now,
                                 calendar: Self.utc)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: Hero and sidebar

    @Test("the hero is the waiting count when a session waits, else the running count, and equals the sidebar")
    func heroEqualsSidebar() {
        let waiting = ActivityPageData(input([session("a", state: .running), session("b", state: .waiting), session("c", cli: .codex, state: .running)]))
        #expect(waiting.hero.figure == .value("1", unit: nil) && waiting.hero.label == "waiting for you")
        let running = ActivityPageData(input([session("a", state: .running), session("c", cli: .codex, state: .running), session("d", state: .idle)]))
        #expect(running.hero.figure == .value("2", unit: nil) && running.hero.label == "running")
        let none = ActivityPageData(input([]))
        #expect(none.hero.figure == .value("0", unit: nil) && none.hero.label == "sessions live")

        for sessions in [[session("b", state: .waiting)], [session("a", state: .running), session("x", state: .ended)], []] {
            var snapshot = FrameTestData.snapshot(FrameTestData.loadout())
            snapshot.activity = FrameTestData.activity(sessions)
            let world = FrameWorld(snapshot: snapshot, now: now)
            let sidebar = FrameSidebarValue(figure: world.figure(for: .activity, loading: [], failed: []), page: .activity)
            guard case .value(let hero, _) = ActivityPageData(input(sessions)).hero.figure else { Issue.record("no figure"); continue }
            #expect(sidebar.text == hero)
        }
    }

    @Test("reading, unreadable, a stale reading and a fresh one are told apart; the hero never shows a made-up zero")
    func phases() {
        let reading = ActivityPageData(input([], loading: [.activity], source: .loading, hasReport: false))
        #expect(reading.phase == .reading && reading.hero.figure == .scanning)
        let unreadable = ActivityPageData(input([], failed: [.activity], source: .failed("The core restarted."), hasReport: false))
        #expect(unreadable.phase == .unreadable("The core restarted.") && unreadable.hero.figure == .unmeasurable)
        let stale = ActivityPageData(input([session("a", state: .running)], source: .failed("The core restarted.")))
        #expect(stale.phase == .ready(staleReason: "The core restarted.") && stale.hero.figure == .value("1", unit: nil))
        #expect(ActivityPageData(input([])).phase == .ready(staleReason: nil))
    }

    // MARK: Grouping

    @Test("sessions group by CLI in registry order, waiting first, then running, idle, unmeasurable, ended")
    func groupedByCLI() {
        let data = ActivityPageData(input([
            session("e", state: .ended), session("u", cli: .codex, state: .unmeasurable), session("i", state: .idle),
            session("r", state: .running), session("w", state: .waiting), session("cr", cli: .codex, state: .running),
        ]))
        #expect(data.groups.map(\.cli.id) == ["claude", "codex"])
        #expect(data.groups[0].rows.map(\.session.id) == ["w", "r", "i", "e"])
        #expect(data.groups[1].rows.map(\.session.id) == ["cr", "u"])
        #expect(data.visibleIDs == ["claude:w", "claude:r", "claude:i", "claude:e", "codex:cr", "codex:u"])
    }

    @Test("at 10 CLIs only CLIs with a session get a group, in registry order, the same shape as at 2; the menu narrows to one")
    func tenCLIs() {
        let registry = FrameTestData.registry(count: 10)
        let sessions = [session("c", cli: .codex, state: .running), session("a", state: .waiting)]
        let data = ActivityPageData(input(sessions, registry: registry))
        #expect(registry.count == 10 && data.groups.map(\.cli.id) == ["claude", "codex"])
        var narrowed = input(sessions, registry: registry)
        narrowed.scope = "codex"
        let one = ActivityPageData(narrowed)
        #expect(one.groups.map(\.cli.id) == ["codex"])
        // The hero still counts every shown CLI, as the sidebar does.
        #expect(one.hero.figure == .value("1", unit: nil) && one.hero.label == "waiting for you")
        narrowed.scope = "cli4"
        #expect(ActivityPageData(narrowed).isSessionsEmpty)
    }

    // MARK: Rows

    @Test("the glyph set is SessionStateGlyph's: done is idle with a log write in the last 10 minutes, ended has none")
    func glyphs() {
        let rows = ActivityPageData(input([
            session("r", state: .running), session("w", state: .waiting), session("d", state: .idle, lastWrite: 9 * 60_000),
            session("i", state: .idle, lastWrite: 11 * 60_000), session("n", state: .idle), session("u", state: .unmeasurable),
            session("e", state: .ended, lastWrite: 8 * 60_000),
        ])).sessionRows
        let glyph = Dictionary(uniqueKeysWithValues: rows.map { ($0.session.id, $0.glyph) })
        #expect(glyph["r"] == .working && glyph["w"] == .waiting && glyph["d"] == .done && glyph["i"] == .idle)
        #expect(glyph["n"] == .idle && glyph["u"] == .unmeasurable)
        #expect(glyph["e"] == .some(nil))
        #expect(rows.first { $0.session.id == "d" }?.stateWord == "Done")
        // Time since the report moves a done session to idle.
        let later = ActivitySessionRow(session("d", state: .idle, lastWrite: 9 * 60_000), cliName: "Claude", elapsedMs: 2 * 60_000)
        #expect(later.glyph == .idle)
    }

    @Test("a row says No project for a session without one, puts the state's reason first, and never shows a cost of 0")
    func rowWords() {
        let waiting = ActivitySessionRow(session("w", state: .waiting, project: nil, cost: 0.64, reason: "Waiting for approval"),
                                         cliName: "Claude Code", elapsedMs: 0)
        #expect(waiting.subLine == "Waiting for approval · No project · $0.64 est.")
        #expect(waiting.facts.first { $0.key == "Project" }?.value == "No project")
        let running = ActivitySessionRow(session("r", state: .running, project: "", tool: CoreActivityTool(name: "Bash", target: "pnpm test"),
                                                 reason: "Running a shell command."), cliName: "Claude Code", elapsedMs: 0)
        #expect(running.subLine == "No project · Cost unmeasurable")
        #expect(running.tool == "Bash pnpm test" && running.toolBlock == "Bash\npnpm test")
        #expect(running.ageCell == "14 min")
        let ended = ActivitySessionRow(session("e", state: .ended, lastWrite: 8 * 60_000), cliName: "Claude Code", elapsedMs: 0)
        #expect(ended.ageCell == "8 min ago" && ended.inspectorAge == "ended 8 min ago" && ended.toolPlaceholder.isEmpty)
        #expect(ended.facts.first { $0.key == "Process" }?.value == "Exited")
        let unknown = ActivitySessionRow(session("u", state: .unmeasurable), cliName: "Codex", elapsedMs: 0)
        #expect(unknown.toolPlaceholder == "Unknown" && unknown.noToolNote.hasPrefix("Unknown:"))
    }

    // MARK: Ticks and Stop

    @Test("Stop takes only ticked rows that are shown, live and stoppable; the head box and the toolbar title follow them")
    func picks() {
        var base = input([
            session("a", state: .running), session("b", state: .waiting), session("e", state: .ended),
            session("pid:7:unknown", cli: .codex, state: .running), session("c", cli: .codex, state: .idle),
        ])
        base.ticked = ["claude:a", "claude:e", "codex:pid:7:unknown", "codex:c"]
        let data = ActivityPageData(base)
        #expect(data.stoppableIDs == ["claude:b", "claude:a", "codex:c"])
        #expect(data.picks.map(\.id) == ["claude:a", "codex:c"])
        #expect(data.headerCheck == .mixed && data.primaryTitle == "Stop 2…" && data.primaryHelp == "Stop 2 sessions…")
        var hidden = base
        hidden.scope = "claude"
        #expect(ActivityPageData(hidden).picks.map(\.id) == ["claude:a"])
        var failures = base
        failures.tab = .failures
        #expect(ActivityPageData(failures).primaryTitle == nil)
        var none = base
        none.ticked = []
        #expect(ActivityPageData(none).primaryTitle == nil && ActivityPageData(none).headerCheck == .off)
    }

    @Test("the row action is Stop…, destructive, on S, and off for an ended row or one the core cannot name again")
    func rowActions() {
        let model = FrameModel(core: StopFakeCore(), toasts: ToastCenter(announce: false))
        let context = ActivityPageContext(model: model, state: ActivityPageState())
        let rows = ActivityPageData(input([session("a", state: .running), session("e", state: .ended),
                                           session("pid:7:unknown", cli: .codex, state: .running)])).sessionRows
        let actions = rows.map { context.actions(for: $0) }
        #expect(actions.allSatisfy { $0.map(\.title) == ["Stop…"] && $0[0].isDestructive && $0[0].shortcut == FrameShortcut("s", modifiers: []) })
        #expect(actions.map { $0[0].isEnabled } == [true, false, false])
        #expect(actions.allSatisfy { FrameRowAction.conflicts(in: $0).isEmpty })
        // RD46 / RD-R9: the selected row's Stop… keeps its red tint (the destructive push button).
        #expect(actions[0][0].buttonKind == .destructive)
    }

    @Test("the alert names exactly what was asked, capped at 5 with and N more; a row that cannot stop is left out")
    func stopAlert() {
        let state = ActivityPageState()
        let rows = ActivityPageData(input((0..<7).map { session("s\($0)", state: .running, pid: 1000 + $0) } + [session("e", state: .ended)])).sessionRows
        state.requestStop(rows)
        #expect(state.stopTargets.count == 7 && state.isStopAlertOpen)
        let text = ActivityPageData.stopText(state.stopTargets)
        #expect(text.title == "Stop 7 sessions?" && text.lines.count == 6 && text.lines.last == "and 2 more sessions")
        #expect(text.confirmTitle == "Stop 7 Sessions" && text.message.contains("This can’t be undone."))
        state.cancelStop()
        #expect(!state.isStopAlertOpen)
        state.requestStop([rows.last!])
        #expect(!state.isStopAlertOpen)
    }

    @Test("one Stop goes through FrameWrite.stop and toasts the pid without Undo; ticks of stopped rows clear")
    func stopOne() async {
        let core = StopFakeCore()
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts)
        let state = ActivityPageState()
        let row = ActivityPageData(input([session("a", state: .running, pid: 48211)])).sessionRows[0]
        state.toggleTick(row.id)
        state.requestStop([row])
        await state.confirmStop(writes: model.writes)?.value
        #expect(core.stopped == ["claude:a"])
        #expect(toasts.current?.message == "Stopped pid 48211. This can't be undone." && toasts.current?.action == nil)
        #expect(state.ticked.isEmpty && !state.isStopAlertOpen)
        // Cancel stops nothing.
        state.requestStop([row])
        state.cancelStop()
        #expect(state.confirmStop(writes: model.writes) == nil && core.stopped.count == 1)
    }

    @Test("several Stops are one write and one toast; a partial refusal is the partial toast naming what stopped and what did not")
    func stopMany() async {
        let core = StopFakeCore()
        core.refuse = ["b"]
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts)
        let rows = ActivityPageData(input([session("a", state: .running, pid: 48211), session("b", state: .waiting, pid: 47990)])).sessionRows
        let ok = await model.writes.perform(ActivityPageState.stopWrite(rows))
        // Something stopped, so it is never shown as a refusal (RB-V1 finding 6).
        #expect(ok && Set(core.stopped) == ["claude:a", "claude:b"])
        #expect(toasts.current?.tone == .partial && toasts.current?.action == nil)
        #expect(toasts.current?.message
            == "Stopped 1 of 2 sessions: pid 48211. Not stopped: pid 47990. The process could not be checked again, so nothing was sent to it.")
        // Every one refused is the refusal.
        core.refuse = ["a", "b"]
        #expect(await model.writes.perform(ActivityPageState.stopWrite(rows)) == false)
        let refusal = toasts.current?.message ?? ""
        #expect(toasts.current?.tone == .danger && refusal == "Stopped 0 of 2 sessions. Not stopped: pid 47990 and pid 48211. "
                + "pid 47990: The process could not be checked again, so nothing was sent to it.")
        core.refuse = []
        #expect(await model.writes.perform(ActivityPageState.stopWrite(rows)))
        #expect(toasts.current?.message == "Stopped 2 sessions. This can't be undone." && toasts.current?.action == nil)
    }

    // MARK: Show Terminal

    @Test("Show Terminal brings the host app forward; with no host app the button says Terminal app not found and is off")
    func showTerminal() {
        let toasts = ToastCenter(announce: false)
        let state = ActivityPageState()
        let row = ActivityPageData(input([session("a", state: .waiting, pid: 4242)])).sessionRows[0]
        var activated: [pid_t] = []
        state.hostApp = { $0 == 4242 ? HostApp(pid: 77, bundleIdentifier: "com.example.term", name: "Term") : nil }
        state.activateHost = { activated.append($0.pid); return true }
        #expect(state.host(of: row)?.pid == 77)
        state.showTerminal(row, toasts: toasts)
        #expect(activated == [77] && toasts.current?.message == "Brought Term to the front.")
        state.hostApp = { _ in nil }
        #expect(state.host(of: row) == nil)
        state.showTerminal(row, toasts: toasts)
        #expect(activated == [77] && toasts.current?.message == "Terminal app not found")
        let ended = ActivityPageData(input([session("e", state: .ended)])).sessionRows[0]
        state.hostApp = { _ in HostApp(pid: 1, bundleIdentifier: nil, name: nil) }
        #expect(state.host(of: ended) == nil)
    }

    // MARK: Failures

    @Test("failures list most failures first, name a Hook by its script, word exit, sessions, days and a later pass")
    func failures() {
        var base = input([], failures: [
            failure("f2", count: 6, laterPass: "2027-01-15T07:30:00.000Z"),
            failure("f1", kind: .hook, title: "sh '$HOME/.claude/scripts/post-edit-format.sh'", count: 14, exit: 127),
            failure("f3", cli: .codex, title: "cargo test --workspace", count: 3, exit: nil, last: "2027-01-14T07:00:00.000Z"),
        ])
        base.tab = .failures
        let data = ActivityPageData(base)
        #expect(data.failures.map(\.failure.key) == ["f1", "f2", "f3"])
        #expect(data.failures[0].title == "post-edit-format.sh" && data.failures[0].countText == "14×")
        #expect(data.failures[0].kindLine == "Hook · PostToolUse · Claude")
        #expect(data.failures[1].subLine == "exit 1 · 2 sessions · today · Passed later today · Lint errors in 3 files")
        #expect(data.failures[2].subLine.hasPrefix("no exit code · 2 sessions · yesterday"))
        #expect(data.failures[2].kindLine == "Command · Codex")
        #expect(data.visibleIDs == data.failures.map(\.id))
        base.dismissed = [data.failures[0].item.dismissKey]
        #expect(ActivityPageData(base).failures.map(\.failure.key) == ["f2", "f3"])
    }

    @Test("Dismiss hides a failure with its own Undo; Copy Command refuses a command the core cut")
    func dismissAndCopy() {
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: StopFakeCore(), toasts: toasts)
        let state = ActivityPageState()
        var copied: [String] = []
        state.copyToPasteboard = { copied.append($0) }
        var base = input([], failures: [failure("f1", title: "pnpm lint")])
        base.tab = .failures
        let row = ActivityPageData(base).failures[0]
        model.router.select(row.id)
        state.dismiss(row, toasts: toasts, router: model.router)
        #expect(state.dismissed.contains(row.item.dismissKey) && model.router.route.selection == nil)
        #expect(toasts.current?.action?.title == "Undo")
        toasts.current?.action?.run()
        #expect(state.dismissed.isEmpty)
        state.copyCommand(row, toasts: toasts)
        #expect(copied == ["pnpm lint"] && toasts.current?.message == "Copied the command.")
        let cut = ActivityFailureRow(failure("f9", title: String(repeating: "x", count: 119) + "\u{2026}"), cliName: "Claude", now: now, calendar: Self.utc)
        state.copyCommand(cut, toasts: toasts)
        #expect(copied.count == 1 && toasts.current?.message.contains("only has its start") == true)
    }

    @Test("a failure without a reason has no stray separator, no empty Reason fact and no trailing comma (break-ui, RB-F3)",
          arguments: ["", "  ", "\n"])
    func emptyReason(reason: String) {
        let row = ActivityFailureRow(failure("f1", reason: reason), cliName: "Claude", now: now, calendar: Self.utc)
        #expect(row.reason == nil)
        #expect(row.subLine == "exit 1 · 2 sessions · today")
        #expect(!row.facts.map(\.key).contains("Reason"))
        #expect(row.facts.map(\.key) == ["Failed", "Sessions", "Last"])
        #expect(row.spoken == "pnpm lint, Claude, failed 1 time")
        let given = ActivityFailureRow(failure("f2"), cliName: "Claude", now: now, calendar: Self.utc)
        #expect(given.facts.map(\.key) == ["Failed", "Reason", "Sessions", "Last"] && given.spoken.hasSuffix(", Lint errors in 3 files"))
    }

    @Test("Copy Command says so when the command it copies had credentials masked (S-R3)")
    func copyMasked() {
        let toasts = ToastCenter(announce: false)
        let state = ActivityPageState()
        var copied: [String] = []
        state.copyToPasteboard = { copied.append($0) }
        var base = input([], failures: [failure("f1", title: "curl -H 'Authorization: Bearer •••' https://api.example.com")])
        base.tab = .failures
        state.copyCommand(ActivityPageData(base).failures[0], toasts: toasts)
        #expect(copied.count == 1 && toasts.current?.message == ToastText.copiedMasked)
    }

    // MARK: Page state

    @Test("switching tabs keeps each tab's own selection and clears ticks; leaving the page closes the alert")
    func tabs() {
        let model = FrameModel(core: StopFakeCore(), toasts: ToastCenter(announce: false), route: FrameRoute(page: .activity))
        let state = ActivityPageState()
        model.router.select("claude:a")
        state.toggleTick("claude:a")
        state.show(.failures, router: model.router)
        #expect(state.tab == .failures && model.router.route.selection == nil && state.ticked.isEmpty)
        model.router.select("claude:command:k")
        state.show(.sessions, router: model.router)
        #expect(model.router.route.selection == "claude:a")
        state.show(.failures, router: model.router)
        #expect(model.router.route.selection == "claude:command:k" && model.router.route.page == .activity)
        let row = ActivityPageData(input([session("a", state: .running)])).sessionRows[0]
        state.requestStop([row])
        state.pageLeft()
        #expect(!state.isStopAlertOpen)
    }

    @Test("the page state lives with the frame's model: one per model")
    func stateLivesWithModel() {
        let one = FrameModel(core: StopFakeCore(), toasts: ToastCenter(announce: false))
        let two = FrameModel(core: StopFakeCore(), toasts: ToastCenter(announce: false))
        #expect(ActivityPageState.of(one) === ActivityPageState.of(one))
        #expect(ActivityPageState.of(one) !== ActivityPageState.of(two))
    }

    @Test("ages move on from when a report was first seen, and start again with a new report")
    func elapsed() {
        let state = ActivityPageState()
        let report = FrameTestData.activity([session("a", state: .running)])
        #expect(state.elapsedMs(for: report, now: now) == 0)
        #expect(state.elapsedMs(for: report, now: now.addingTimeInterval(90)) == 90_000)
        #expect(state.elapsedMs(for: FrameTestData.activity([]), now: now.addingTimeInterval(120)) == 0)
    }

    @Test("the segmented control's arrow step stays inside its segments")
    func segmentStep() {
        let segments = ActivityTable.allCases.map { FrameSegment(id: $0.rawValue, title: $0.title) }
        #expect(FrameSegmentedControl.step(from: "sessions", by: 1, in: segments) == "failures")
        #expect(FrameSegmentedControl.step(from: "failures", by: 1, in: segments) == "failures")
        #expect(FrameSegmentedControl.step(from: "sessions", by: -1, in: segments) == "sessions")
        #expect(SkeletonRows.share(0) == 0.46 && SkeletonRows.share(3) == 0.85)
    }

    // MARK: RB-F2

    @Test("a session of a CLI the core cannot name groups under the registry CLI the input gives it; its id follows")
    func sessionCLIs() {
        let registry = FrameTestData.registry(count: 10)
        var page = input([session("a", state: .running), session("x", state: .idle, lastWrite: 60_000)], registry: registry)
        page.sessionCLIs = ["x": "cli4"]
        let data = ActivityPageData(page)
        #expect(data.groups.map(\.cli.id) == ["claude", "cli4"])
        #expect(data.groups[1].rows.map(\.id) == ["cli4:x"])
        #expect(data.groups[1].rows[0].cliName == registry.first { $0.id == "cli4" }?.name)
    }

    @Test("the shots: many shows other CLIs' groups, Failures pins the switch's tab, the partial Stop is the real partial toast")
    func shotStates() {
        let many = ActivityPageData(ActivityPageInput(
            clis: ActivityShotState.many.preview().clis, sessions: ActivityShotState.many.preview().sessions,
            sessionCLIs: ActivityShotState.many.preview().sessionCLIs, failures: [], hasReport: true, source: .ready,
            figure: ActivityShotState.many.preview().figure))
        #expect(many.groups.map(\.cli.id) == ["claude", "codex", "cursor", "copilot"])
        #expect(ActivityShotState.failures.preview().tab == .failures)
        let partial = ActivityShotState.writefail.toast
        #expect(partial?.tone == .partial)
        #expect(partial?.message == ActivityPageData.partialStop(stopped: [48211], refused: [(pid: 47990, reason: ActivityShotData.refusal)]))
        #expect(ActivityShotState.write.toast?.message == "Stopped pid 48211. This can't be undone.")
    }

    @Test("the first-row rule waits for a reading: before it the widget's session survives (RD44)")
    func firstRowWaitsForReading() {
        let reading = ActivityPageData(input([], source: .loading, hasReport: false))
        #expect(reading.isReading)
        let ready = ActivityPageData(input([session("a", state: .running)]))
        #expect(!ready.isReading)
        let router = FrameRouter(FrameRoute.session("claude:zzz"))
        router.keepSelection(onPage: .activity, among: ready.visibleIDs)
        #expect(router.route.selection == "claude:a")
    }

    @Test("Activity's session glyph is 16 and its CLI group heads are the quiet size (RD46)")
    func glyphAndHeadSize() {
        #expect(IconSize.control.points == 16)
        #expect(GroupHead<EmptyView>.Size.quiet.title == .quietMedium)
        #expect(GroupHead<EmptyView>.Size.quiet.insets == EdgeInsets(top: SpaceRole.step12, leading: SpaceRole.step12,
                                                                    bottom: SpaceRole.step6, trailing: SpaceRole.step12))
        #expect(GroupHead<EmptyView>.Size.regular.title == .bodyMedium)
    }
}
