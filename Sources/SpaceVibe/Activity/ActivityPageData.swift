import Foundation

/// The two tabs of the redesign's Activity page (the mock's `segCtl('act', …)`): Sessions and Failures. There is no Files tab
/// (D70, RD21): the core still reports edited files, the page does not show them.
enum ActivityTable: String, CaseIterable, Identifiable, Sendable {
    case sessions, failures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessions: "Sessions"
        case .failures: "Failures"
        }
    }
}

/// Where the activity source stands for the page (RD-R13): still reading with nothing to show, unreadable with nothing read
/// before, or a reading to show, with the core's sentence when the latest refresh failed and the last reading is kept.
enum ActivityPhase: Equatable, Sendable {
    case reading
    case unreadable(String)
    case ready(staleReason: String?)
}

/// What the page reads from the store, the page state and the clock: every input of `ActivityPageData`, so a test or a shot
/// can hand one over without a store.
struct ActivityPageInput: Sendable {
    /// The shown CLIs in registry order (`FrameWorld.clis`).
    var clis: [CoreRegistryCLI]
    /// `FrameWorld.sessions`: the report's sessions of the shown CLIs, ended ones included (the core keeps them 15 minutes).
    var sessions: [CoreActivitySession]
    /// The registry CLI of a session the core's `CoreCLI` cannot name, by session id (a shot's sessions of illustration CLIs,
    /// RD-R10 at ten CLIs). Every other session belongs to `session.cli`.
    var sessionCLIs: [String: String] = [:]
    var failures: [CoreActivityFailure]
    var hasReport: Bool
    /// The store's state of `.activity`; nil before the first read starts.
    var source: FrameSourceState?
    /// `FrameWorld.figure(for: .activity, …)`, the same value the sidebar shows (AR3).
    var figure: PageFigure
    var tab: ActivityTable = .sessions
    /// The `All CLIs` menu: nil for all, else a registry id.
    var scope: String?
    var dismissed: Set<String> = []
    var ticked: Set<String> = []
    /// The route's selection on the tab showing.
    var selection: String?
    /// Milliseconds since the report arrived: the ages in it are as of then.
    var elapsedMs: Double = 0
    var now = Date()
    var calendar = Calendar.current
    /// The toolbar's search (⌘F): both tabs keep only the rows it matches; the hero counts every session.
    var query = FrameSearchQuery("")
}

/// One session as the Sessions table shows it (the mock's `pageActivity` rows and `sessInspector`). Pure wording over the
/// core's session.
struct ActivitySessionRow: Identifiable, Equatable, Sendable {
    let session: CoreActivitySession
    /// The registry id of the session's CLI: `session.cli`, unless the input names another (`ActivityPageInput.sessionCLIs`).
    let cliID: String
    let cliName: String
    /// The `SessionStateGlyph` state: nil for an ended row, which has no glyph (the widget drops it, GW10).
    let glyph: GlanceState?
    /// The session's age and last write, moved on by the time since the report.
    let ageMs: Double?
    let lastWriteAgoMs: Double?

    init(_ session: CoreActivitySession, cliID: String? = nil, cliName: String, elapsedMs: Double) {
        self.session = session
        self.cliID = cliID ?? session.cli.rawValue
        self.cliName = cliName
        ageMs = session.ageMs.map { $0 + elapsedMs }
        lastWriteAgoMs = session.lastWriteAgoMs.map { $0 + elapsedMs }
        var moved = session
        moved.lastWriteAgoMs = lastWriteAgoMs
        glyph = GlanceState(moved)
    }

    /// The same shape as the glance widget's and the route's session id (`FrameRoute.session`).
    var id: String { "\(cliID):\(session.id)" }
    /// The session has a process (the mock's `LIVE`): every state but ended.
    var isLive: Bool { session.state != .ended }
    /// Stop needs a live process the core can name again: an id ending `:unknown` cannot authorize it (core-protocol.md).
    var canStop: Bool { isLive && !session.id.hasSuffix(":unknown") }
    var isWaiting: Bool { session.state == .waiting }

    /// The state in one word, for the glyph's label and the inspector: done is an idle session that wrote its log in the last
    /// 10 minutes (GW8).
    var stateWord: String {
        switch session.state {
        case .running: "Running"
        case .waiting: "Waiting"
        case .idle: glyph == .done ? "Done" : "Idle"
        case .ended: "Ended"
        case .unmeasurable: "Unmeasurable"
        }
    }

    /// The core's sentence, shown only where it is the point: a wait and a state SpaceVibe cannot read.
    var reason: String? {
        guard session.state == .waiting || session.state == .unmeasurable else { return nil }
        let text = session.stateReason.replacingOccurrences(of: "State unmeasurable: ", with: "")
        return text.isEmpty ? nil : text
    }

    /// RD-R17: a session with no project reads "No project", never empty.
    var project: String {
        guard let name = session.project, !name.isEmpty else { return "No project" }
        return name
    }

    /// The row's cost: an estimate, or why there is none (never $0).
    var costLine: String {
        if let cost = session.cost { return "\(NumberWording.money(cost.usd)) est." }
        return session.costNote ?? "Cost unmeasurable"
    }

    var inspectorCost: String {
        if let cost = session.cost { return "\(NumberWording.money(cost.usd)) (estimate, API-equivalent rates)" }
        return "Unmeasurable: \(session.costNote ?? "no price or no log")"
    }

    /// The quiet line under the title; the reason comes first, so a cut line keeps it.
    var subLine: String { [reason, project, costLine].compactMap { $0 }.joined(separator: " · ") }

    /// "Bash pnpm test", or nil with no open tool call.
    var tool: String? {
        guard let tool = session.currentTool else { return nil }
        return tool.target.isEmpty ? tool.name : "\(tool.name) \(tool.target)"
    }

    /// The Current tool cell without a tool: empty for an ended row, "Unknown" when the state cannot be read.
    var toolPlaceholder: String {
        switch session.state {
        case .ended: ""
        case .unmeasurable: "Unknown"
        default: "No tool running"
        }
    }

    /// The Age cell: "14 min"; an ended row "8 min ago" since its last write.
    var ageCell: String {
        if session.state == .ended { return lastWriteAgoMs.map { "\(ActivityFormat.span($0)) ago" } ?? "Ended" }
        return ageMs.map(ActivityFormat.span) ?? NumberWording.missing
    }

    var inspectorAge: String {
        if session.state == .ended { return lastWriteAgoMs.map { "ended \(ActivityFormat.span($0)) ago" } ?? "Ended" }
        return ageMs.map(ActivityFormat.span) ?? NumberWording.missing
    }

    /// The inspector's facts (the mock's `sessInspector` `.kv`).
    var facts: [InspectorFact] {
        [
            InspectorFact(key: "Project", value: project),
            InspectorFact(key: "State", value: [stateWord, reason].compactMap { $0 }.joined(separator: " · ")),
            InspectorFact(key: "Process", value: isLive ? String(session.pid) : "Exited"),
            InspectorFact(key: "Age", value: inspectorAge),
            InspectorFact(key: "Cost", value: inspectorCost),
        ]
    }

    /// The Current tool section: the call on two lines, or why there is none.
    var toolBlock: String? { session.currentTool.map { "\($0.name)\n\($0.target)" } }
    var noToolNote: String {
        session.state == .unmeasurable ? "Unknown: this CLI logs nothing while a tool runs." : "None running."
    }

    /// What VoiceOver reads for the row.
    var spoken: String { [session.title, stateWord, cliName, project].joined(separator: ", ") }

    /// The mock's order inside a CLI: waiting, running, idle, unmeasurable, ended.
    var rank: Int {
        switch session.state {
        case .waiting: 0
        case .running: 1
        case .idle: 2
        case .unmeasurable: 3
        case .ended: 4
        }
    }
}

/// The rows of one CLI (RD-R10: Activity is grouped by CLI at any CLI count).
struct ActivitySessionGroup: Identifiable, Equatable, Sendable {
    let cli: CLIIdentity
    let rows: [ActivitySessionRow]

    var id: String { cli.id }
}

/// One failed command or Hook as the Failures table shows it (the mock's `failT` and `failInspector`). Reuses the v5
/// `ActivityFailureItem` for its id, its dismissal key and the cut-title rule.
struct ActivityFailureRow: Identifiable, Equatable, Sendable {
    let item: ActivityFailureItem
    let cliName: String
    let lastDay: String
    let passedDay: String?

    init(_ failure: CoreActivityFailure, cliName: String, now: Date, calendar: Calendar) {
        item = ActivityFailureItem(failure: failure)
        self.cliName = cliName
        lastDay = DayWording.lastRan(daysAgo: ActivityPageData.daysAgo(failure.last, now: now, calendar: calendar))
        passedDay = failure.laterPass.map { "Passed later \(DayWording.lastRan(daysAgo: ActivityPageData.daysAgo($0, now: now, calendar: calendar)))" }
    }

    var id: String { item.id }
    var failure: CoreActivityFailure { item.failure }
    var isHook: Bool { failure.kind == .hook }
    /// A Hook is named by the script it runs (RD-R17, `HookLabel`); a command by itself.
    var title: String { isHook ? HookLabel.of(failure.title) : failure.title }
    var icon: FrameIcon { isHook ? .hooks : .terminalWindow }
    var exitText: String { failure.exit.map { "exit \($0)" } ?? "no exit code" }
    var countText: String { "\(NumberWording.count(failure.count))×" }

    /// The core's reason, nil when it gave none (or only white space): then no separator and no Reason line stand empty.
    var reason: String? {
        let text = failure.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : failure.reason
    }

    var subLine: String {
        [exitText, NumberWording.plural(failure.sessions, "session"), lastDay, passedDay, reason]
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// "Hook · PostToolUse · Claude Code", "Command · Codex".
    var kindLine: String {
        if isHook { return ["Hook", failure.hook?.event, cliName].compactMap { $0 }.joined(separator: " · ") }
        return "Command · \(cliName)"
    }

    var facts: [InspectorFact] {
        [
            InspectorFact(key: "Failed", value: NumberWording.plural(failure.count, "time") + (failure.exit.map { " · exit \($0)" } ?? "")),
            reason.map { InspectorFact(key: "Reason", value: $0) },
            InspectorFact(key: "Sessions", value: NumberWording.count(failure.sessions)),
            InspectorFact(key: "Last", value: [lastDay, passedDay].compactMap { $0 }.joined(separator: " · ")),
        ].compactMap { $0 }
    }

    var spoken: String {
        ([title, cliName, "failed \(NumberWording.plural(failure.count, "time"))"] + [reason].compactMap { $0 }).joined(separator: ", ")
    }
}

/// Everything the Activity page draws, derived once from `ActivityPageInput` (plan AR3: pure, page state is an input, the
/// store is never written). The hero reads the same `PageFigure` as the sidebar (waiting count when a session waits, else the
/// running count).
struct ActivityPageData: Sendable {
    let input: ActivityPageInput
    let phase: ActivityPhase
    let groups: [ActivitySessionGroup]
    let failures: [ActivityFailureRow]
    /// The search hides every row of the tab showing while it has some: "No sessions match" with Clear Search.
    let isSearchMiss: Bool

    init(_ input: ActivityPageInput) {
        self.input = input
        switch (input.hasReport, input.source) {
        case (true, .failed(let reason)): phase = .ready(staleReason: reason)
        case (true, _): phase = .ready(staleReason: nil)
        case (false, .failed(let reason)): phase = .unreadable(reason)
        case (false, _): phase = .reading
        }
        let names = Dictionary(input.clis.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let name = { (cli: CoreCLI) in names[cli.rawValue] ?? cli.label }
        // A CLI hidden in Settings › CLIs since it was picked reads as All CLIs, as the menu shows it.
        let scope = input.clis.contains { $0.id == input.scope } ? input.scope : nil
        let clis = input.clis.filter { scope == nil || $0.id == scope }

        let everyRow = input.sessions.map { session in
            let cliID = input.sessionCLIs[session.id] ?? session.cli.rawValue
            return ActivitySessionRow(session, cliID: cliID, cliName: names[cliID] ?? session.cli.label, elapsedMs: input.elapsedMs)
        }
        let rows = input.query.filter(everyRow) { row in
            [row.session.title, row.session.project, row.cliName, row.session.currentTool?.name, row.session.currentTool?.target]
        }
        groups = clis.compactMap { cli in
            let mine = rows.enumerated().filter { $0.element.cliID == cli.id }
                .sorted { ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset) }.map(\.element)
            return mine.isEmpty ? nil : ActivitySessionGroup(cli: CLIIdentity(id: cli.id, name: cli.name), rows: mine)
        }

        let shown = Set(clis.map(\.id))
        let everyFailure = input.failures.enumerated()
            .filter { shown.contains($0.element.cli.rawValue) }
            .map { (offset: $0.offset, row: ActivityFailureRow($0.element, cliName: name($0.element.cli), now: input.now, calendar: input.calendar)) }
            .filter { !input.dismissed.contains($0.row.item.dismissKey) }
            .sorted { ($0.row.failure.count, -$0.offset) > ($1.row.failure.count, -$1.offset) }
            .map(\.row)
        failures = input.query.filter(everyFailure) { row in
            [row.title, row.failure.title, row.failure.reason, row.cliName] + row.failure.projects
        }
        let hidden = switch input.tab {
        case .sessions: groups.isEmpty && everyRow.contains { row in clis.contains { $0.id == row.cliID } }
        case .failures: failures.isEmpty && !everyFailure.isEmpty
        }
        isSearchMiss = !input.query.isEmpty && hidden
    }

    /// No reading to show yet (the first read, or it failed with nothing read before).
    var isReading: Bool {
        if case .ready = phase { return false }
        return true
    }

    /// What the toolbar's search finds on the tab showing.
    var searchItems: String { input.tab == .sessions ? "sessions" : "failures" }

    // MARK: Hero

    /// The page's figure and its label (RD-R2: `1 waiting for you`, or the running count).
    var hero: (figure: PageHero.Figure, label: String) {
        let label = input.sessions.isEmpty ? "sessions live" : input.sessions.contains { $0.state == .waiting } ? "waiting for you" : "running"
        switch input.figure {
        case .pending: return (.scanning, label)
        case .count(let n, _): return (.value(NumberWording.count(n), unit: nil), label)
        case .failed, .unmeasurable, .notMeasured, .percentLeft, .bytes: return (.unmeasurable, "Unmeasurable")
        }
    }

    // MARK: Sessions

    var sessionRows: [ActivitySessionRow] { groups.flatMap(\.rows) }

    /// The rows in the order the arrow keys walk them, for the tab showing.
    var visibleIDs: [String] {
        switch input.tab {
        case .sessions: sessionRows.map(\.id)
        case .failures: failures.map(\.id)
        }
    }

    /// The rows a checkbox ticks: shown, live and stoppable (RD40: checkboxes exist because Stop is a bulk action).
    var stoppableIDs: [String] { sessionRows.filter(\.canStop).map(\.id) }

    /// The ticked rows Stop takes: only the ones shown and stoppable, so a tick hidden by the CLI menu never stops a session.
    var picks: [ActivitySessionRow] { sessionRows.filter { $0.canStop && input.ticked.contains($0.id) } }

    var headerCheck: CheckboxValue {
        CheckboxValue.header(ticked: stoppableIDs.filter(input.ticked.contains).count, total: stoppableIDs.count)
    }

    /// The toolbar's destructive button while rows are ticked: `Stop 2…`, short enough never to be cut in the 196 slot
    /// (RD52: "Stop 1,006"); the ellipsis stays, because a confirmation follows. The tooltip and VoiceOver say
    /// `primaryHelp`.
    var primaryTitle: String? {
        guard input.tab == .sessions, !picks.isEmpty else { return nil }
        return "Stop \(NumberWording.count(picks.count))…"
    }

    /// `Stop 1,006 sessions…`.
    var primaryHelp: String? {
        guard primaryTitle != nil else { return nil }
        return "Stop \(NumberWording.plural(picks.count, "session"))…"
    }

    var selectedSession: ActivitySessionRow? {
        guard input.tab == .sessions, let id = input.selection else { return nil }
        return sessionRows.first { $0.id == id }
    }

    var selectedFailure: ActivityFailureRow? {
        guard input.tab == .failures, let id = input.selection else { return nil }
        return failures.first { $0.id == id }
    }

    /// The Sessions empty state: no session of a shown CLI at all, or none of the one the menu picked.
    var isSessionsEmpty: Bool { groups.isEmpty }

    // MARK: Stop

    /// The alert's wording for exactly these sessions (the dialog lists what was clicked or ticked).
    static func stopText(_ rows: [ActivitySessionRow]) -> StopAlertText {
        StopAlertText(sessions: rows.map { StopAlertText.Session(title: $0.session.title, pid: Int32(clamping: $0.session.pid), cli: $0.cliName) })
    }

    /// The toast after the core accepted every Stop: no Undo (GLOSSARY Stop).
    static func stoppedLabel(_ rows: [ActivitySessionRow]) -> String {
        rows.count == 1
            ? "Stopped pid \(rows[0].session.pid). This can't be undone."
            : "Stopped \(NumberWording.plural(rows.count, "session")). This can't be undone."
    }

    /// The sentence when some of several Stops were refused: which pids stopped and which did not, then the first refusal in
    /// the core's words ("Stopped 1 of 2 sessions: pid 48211. Not stopped: pid 47990. <reason>"). Nil when every one was
    /// stopped.
    static func partialStop(stopped: [Int], refused: [(pid: Int, reason: String)]) -> String? {
        guard let first = refused.first else { return nil }
        let total = stopped.count + refused.count
        let head = "Stopped \(NumberWording.count(stopped.count)) of \(NumberWording.plural(total, "session"))"
        let done = stopped.isEmpty ? "" : ": " + CLINames.sentence(stopped.map { "pid \($0)" })
        let notStopped = CLINames.sentence(refused.map { "pid \($0.pid)" })
        let why = refused.count > 1 ? "pid \(first.pid): \(first.reason)" : first.reason
        return "\(head)\(done). Not stopped: \(notStopped). \(why)"
    }

    // MARK: Dates

    /// Whole calendar days from an ISO time to `now`; nil when it cannot be read.
    static func daysAgo(_ iso: String?, now: Date, calendar: Calendar) -> Int? {
        guard let at = ActivityFormat.date(iso) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: at), to: calendar.startOfDay(for: now)).day
    }
}
