import Foundation

/// The Hooks page's view state (AR3: page state, never in the store): the ticked rows, the event the strip filters to and
/// the CLI the `All CLIs` menu shows. A filter change clears the ticks (the mock's click paths: "filters (incl. the Hooks
/// event) clear ticks").
struct HooksViewState: Equatable, Sendable {
    var ticked: Set<String> = []
    var event: String?
    /// A registry id; nil is All CLIs.
    var cli: String?

    func filtering(event next: String?) -> HooksViewState {
        HooksViewState(ticked: next == event ? ticked : [], event: next, cli: cli)
    }

    func filtering(cli next: String?) -> HooksViewState {
        HooksViewState(ticked: next == cli ? ticked : [], event: event, cli: next)
    }

    func toggling(_ id: String) -> HooksViewState {
        HooksViewState(ticked: ticked.symmetricDifference([id]), event: event, cli: cli)
    }

    /// `Select N Suggested` ticks them all; pressed again with all of them ticked (`Clear Selection`) it clears them.
    func togglingAll(_ ids: [String]) -> HooksViewState {
        let all = !ids.isEmpty && ids.allSatisfy(ticked.contains)
        return HooksViewState(ticked: all ? ticked.subtracting(ids) : ticked.union(ids), event: event, cli: cli)
    }
}

/// What the page body draws (RD-R13): the first read or scan, a failed read, no Hook at all, or the table.
enum HooksPhase: Equatable, Sendable {
    case normal
    case empty
    /// No `loadout.rows` yet, or the usage scan is running: skeleton rows and no judged row, as the mock draws it, until the
    /// counts are in (a row's state needs its runs).
    case scanning
    /// `loadout.rows` could not be read and nothing was read before: the core's sentence.
    case failed(String)
}

/// The quiet state line of a row (the mock's Status column): a failing or dead Hook in its state colour with its glyph.
struct HooksStatusLine: Equatable, Sendable {
    enum Tone: Equatable, Sendable { case critical, attention, quiet }
    let tone: Tone
    let text: String
}

/// One row of the Hooks table: one CLI's members of a `loadout.rows` hook key (RD46, the mock's `pageHooks`: one CLI per
/// row; `FrameRow.rows(from:)` splits a key two CLIs hold).
struct HooksListRow: Identifiable, Equatable, Sendable {
    /// Why the page writes nothing for this row (D-rule: Hooks are written only into Claude Code, mutations.md).
    enum ReadOnly: Equatable, Sendable {
        /// Under `<project>/.claude`: "Project · <name>", never selectable for removal.
        case project(String)
        /// Owned by a plugin.
        case plugin
        /// Held by Codex or another CLI only: SpaceVibe writes Hooks only into Claude Code.
        case notClaudeCode
    }

    let row: FrameRow
    /// The script it runs (`HookLabel`, RD-R17), the same on every surface.
    let label: String
    let command: String
    /// The event as its CLI names it, and its lifecycle stage.
    let event: String
    let stage: String
    let matcher: String?
    /// The registry id of the CLI that holds it.
    let cli: String
    let status: ItemStatus
    /// Errors in the last 7 days over the CLIs that count them (RB-E5); nil when no CLI sent its week.
    let errorsLastWeek: Int?
    let runs: RunsCell.Value
    let statusLine: HooksStatusLine
    let readOnly: ReadOnly?
    /// The Claude Code members a removal takes (`loadout.removeMany` member ids).
    let removalIDs: [String]

    var id: String { row.id }
    var isWritable: Bool { readOnly == nil && !removalIDs.isEmpty }
    var isDeadOrNeverRan: Bool { status == .dead || status == .neverRan }

    /// The quiet line under the name: the project, the state when the Status column is folded, the CLI's own event name
    /// when it differs from the stage, the matcher (the mock's `sub`; the state comes first so a cut line never hides it).
    func subLine(foldsStatus: Bool) -> String {
        var parts: [String] = []
        if case .project(let name) = readOnly { parts.append("Project · \(name)") }
        if foldsStatus, statusLine.tone != .quiet { parts.append(statusLine.text) }
        if event != stage { parts.append(event) }
        if let matcher, !matcher.isEmpty { parts.append("Matcher \(matcher)") }
        return parts.isEmpty ? "Every event" : parts.joined(separator: " · ")
    }
}

/// The rows of one lifecycle stage, in firing order.
struct HooksStage: Identifiable, Equatable, Sendable {
    let stage: String
    let rows: [HooksListRow]
    var id: String { stage }
}

/// Everything the Hooks page shows, from the store's world and the page's view state. Pure, so the tests check what each
/// state shows, that the hero equals the rows, which actions each row offers and which rows a removal takes.
struct HooksListModel: Sendable {
    static let heroLabel = "dead or never ran"
    static let writesNote = "SpaceVibe writes Hooks only into Claude Code. It does not write Hooks into Codex or any other CLI."
    static let scanningTitle = "Matching Hooks to runs in your logs\u{2026}"
    static let emptyTitle = "No Hooks yet"
    static let emptyText = "A Hook is a command a CLI runs on an event. SpaceVibe shows and removes Hooks but never runs them."

    let phase: HooksPhase
    let hero: PageHero.Figure
    let nodes: [LifecycleNode]
    /// The rows shown (the event and CLI filters applied), grouped by stage in firing order; none while scanning.
    let stages: [HooksStage]
    /// Every Hook row, unfiltered: the hero and the `Dead or never ran` head count these.
    let all: [HooksListRow]
    let view: HooksViewState
    /// Shown CLIs whose Hook cells could not be read: the banner names them, their figures read Unmeasurable.
    let unreadable: [CoreRegistryCLI]
    /// Shown CLIs with Hooks and none installed ("No Hooks: …").
    let noHooks: [CoreRegistryCLI]
    /// Shown CLIs without Hooks ("Not supported: … have no command Hooks").
    let notSupported: [CoreRegistryCLI]
    /// The `All CLIs` menu's lines: every shown CLI, a CLI without Hooks disabled.
    let cliOptions: [CLIMenuEntries.Option]
    let suggestedIDs: Set<String>
    /// The shown CLIs in registry order (the row logos).
    let clis: [CoreRegistryCLI]
    /// Every installed CLI, hidden ones too: the removal toast names who lost a Hook.
    let registry: [CoreRegistryCLI]

    /// The toolbar's search (⌘F): the stages keep only the rows it matches; the hero and the strip count every Hook.
    let query: FrameSearchQuery

    var visible: [HooksListRow] { stages.flatMap(\.rows) }
    /// The search hides every row the filters would show: "No hooks match" with Clear Search.
    var isSearchMiss: Bool { phase == .normal && !query.isEmpty && visible.isEmpty }
    var deadOrNeverRan: [HooksListRow] { all.filter(\.isDeadOrNeverRan) }
    /// The group head's severity: critical with a dead Hook, attention with only Never ran ones.
    var deadHeadSeverity: GroupSeverity {
        deadOrNeverRan.contains { $0.status == .dead } ? .critical : deadOrNeverRan.isEmpty ? .none : .attention
    }
    /// What `Select N Suggested` ticks: the suggested rows among those shown that the page may write (RD41, RD26).
    var suggested: [String] { visible.filter { suggestedIDs.contains($0.id) && $0.isWritable }.map(\.id) }
    var allSuggestedTicked: Bool { !suggested.isEmpty && suggested.allSatisfy(view.ticked.contains) }
    /// The rows `Remove N selected` takes: ticked, shown and writable. A tick the filter hides never removes a row.
    var removal: [HooksListRow] { visible.filter { view.ticked.contains($0.id) && $0.isWritable } }
    /// The header checkbox covers the writable rows shown.
    var tickable: [String] { visible.filter(\.isWritable).map(\.id) }
    var subtitle: String? { view.event.map { "\($0) only" } }

    /// The skeleton rows the scanning page draws (the mock's `skel(7)`).
    static let skeletonRows = 7

    /// One shown row with its zebra step.
    struct StripedRow: Equatable, Sendable {
        let row: HooksListRow
        let isStriped: Bool
    }

    /// A stage with its rows' zebra steps.
    struct StripedStage: Identifiable, Equatable, Sendable {
        let stage: String
        let rows: [StripedRow]
        var id: String { stage }
    }

    /// The stages with the zebra of the mock's group (`.tr:nth-child(odd)`, `style.css:142`): the head row is the group's
    /// first child and each stage's caption one more, so a row is striped when its place among them is odd.
    var stripedStages: [StripedStage] {
        var place = 1
        return stages.map { stage in
            place += 1
            let rows = stage.rows.map { row -> StripedRow in
                place += 1
                return StripedRow(row: row, isStriped: !place.isMultiple(of: 2))
            }
            return StripedStage(stage: stage.stage, rows: rows)
        }
    }

    /// The Status column folds into the sub-line when the main column (the window less the sidebar and a docked inspector,
    /// `FrameChrome.listWidth`) is under the mock's 940; before the window is measured the wide layout stands.
    static func foldsStatus(listWidth: CGFloat, windowMeasured: Bool) -> Bool {
        windowMeasured && listWidth < TableColumnWidth.wideListWidth
    }

    /// The `All CLIs` menu and the search show except on the empty and failed pages (the mock draws `mid` unless the page is
    /// empty; a page that could not read a Hook has nothing to filter or search).
    var hasToolbarControls: Bool {
        switch phase {
        case .normal, .scanning: true
        case .empty, .failed: false
        }
    }
    /// `Remove N selected` sits in the slot once the table shows; while empty or scanning the slot stays, empty.
    var hasRemoveSelected: Bool { phase == .normal }

    func row(_ id: String?) -> HooksListRow? { id.flatMap { id in all.first { $0.id == id } } }

    /// The CLI that holds a row, for its logo and sentences; nil for a CLI the registry no longer lists.
    func holder(of row: HooksListRow) -> CoreRegistryCLI? { registry.first { $0.id == row.cli } }

    init(world: FrameWorld, loading: Set<FrameSource>, failed: Set<FrameSource>, failure: String?, view: HooksViewState,
         query: FrameSearchQuery = FrameSearchQuery(""), now: Date) {
        self.query = query
        let registry = world.clis.map(\.id)
        let order = HooksLifecycle.firingOrder(world.snapshot.loadout?.events ?? [:], registry: registry)
        let rows = world.rows(.hook)
        let busiest = max(1, rows.map(\.total).max() ?? 0)
        let suggestedIDs = world.suggested
        // The same 7-day count Inbox's failing Hook reads (RD26).
        let errors = world.snapshot.loadout.map(FindingFacts.hookErrorsLastWeek(in:)) ?? [:]
        let all = rows.map { Self.listRow($0, registry: registry, busiest: busiest, errorsLastWeek: errors[$0.id], now: now) }
            .sorted { a, b in
                let (ra, rb) = (HooksLifecycle.rank(a.stage, in: order), HooksLifecycle.rank(b.stage, in: order))
                if ra != rb { return ra < rb }
                let (ca, cb) = (registry.firstIndex(of: a.cli) ?? registry.count, registry.firstIndex(of: b.cli) ?? registry.count)
                return ca < cb
            }
        self.all = all
        self.view = view
        self.suggestedIDs = suggestedIDs

        let figure = world.figure(for: .hooks, loading: loading, failed: failed)
        switch figure {
        case .pending: hero = .scanning
        case .failed, .unmeasurable, .notMeasured: hero = .unmeasurable
        case .count(let n, _): hero = .value(NumberWording.count(n), unit: nil)
        case .percentLeft, .bytes: hero = .unmeasurable
        }

        let phase: HooksPhase
        if failed.contains(.loadout) {
            phase = .failed(failure ?? "Hooks could not be read.")
        } else if loading.contains(.loadout) || world.snapshot.loadout == nil || world.snapshot.loadout?.usage == .scanning {
            phase = .scanning
        } else if rows.isEmpty {
            phase = .empty
        } else {
            phase = .normal
        }
        self.phase = phase

        let shown = phase == .scanning ? [] : all.filter { row in
            (view.event.map { row.stage == $0 } ?? true) && (view.cli.map { row.cli == $0 } ?? true)
                && query.matches(row.row.searchFields + [row.label])
        }
        let stageNames = shown.reduce(into: [String]()) { names, row in if !names.contains(row.stage) { names.append(row.stage) } }
        stages = stageNames.map { name in HooksStage(stage: name, rows: shown.filter { $0.stage == name }) }

        let withHooks = Set(all.map(\.stage))
        // No strip on the empty page (the mock's `band`), nor while no Hook could be read yet: its nodes would all read 0.
        let counted = world.snapshot.loadout != nil && !failed.contains(.loadout) && !loading.contains(.loadout)
        nodes = phase == .empty || !counted ? [] : HooksLifecycle.strip(order: order, stagesWithHooks: withHooks).map { event in
            let here = all.filter { $0.stage == event }
            let mark: LifecycleNode.Mark = here.isEmpty ? .empty
                : here.contains { $0.status == .dead } ? .critical
                : here.contains { ($0.errorsLastWeek ?? 0) > 0 } ? .attention : .plain
            return LifecycleNode(event: event, count: here.count, mark: mark)
        }

        let hookCLIs = world.clis.filter(\.supports.hook)
        let unreadable = hookCLIs.filter { cli in rows.contains { $0.cell(cli.id) == .unknown } }
        self.unreadable = unreadable
        noHooks = hookCLIs.filter { cli in !unreadable.contains(cli) && !rows.contains { $0.presence(cli.id) == .on } }
        notSupported = world.clis.filter { !$0.supports.hook }
        clis = world.clis
        self.registry = world.snapshot.registry
        cliOptions = world.clis.map { CLIMenuEntries.Option(cli: CLIIdentity(id: $0.id, name: $0.name), isSupported: $0.supports.hook) }
    }

    /// From the store as it stands.
    @MainActor
    static func from(_ store: FrameStore, view: HooksViewState, query: FrameSearchQuery = FrameSearchQuery(""),
                     now: Date = Date()) -> HooksListModel {
        var failure: String?
        if case .failed(let message) = store.states[.loadout] { failure = message }
        return HooksListModel(world: store.world(now: now), loading: store.loading, failed: store.failedEmpty, failure: failure,
                              view: view, query: query, now: now)
    }

    // MARK: Rows

    /// `errorsLastWeek` is the row's entry of `FindingFacts.hookErrorsLastWeek(in:)`: nil when no CLI sent its week.
    static func listRow(_ row: FrameRow, registry: [String], busiest: Int, errorsLastWeek: Int?, now: Date) -> HooksListRow {
        let first = row.hooks.first
        let event = first?.event ?? ""
        let cli = first?.cli.rawValue ?? ""
        let claude = row.hooks.filter { $0.cli == .claude }
        let readOnly: HooksListRow.ReadOnly? = row.isProject ? .project(Self.projectName(row.project))
            : row.isPlugin ? .plugin
            : claude.isEmpty ? .notClaudeCode : nil
        return HooksListRow(
            row: row, label: row.name, command: first?.command ?? "", event: event,
            stage: HooksLifecycle.stage(of: event, cli: cli), matcher: first?.matcher, cli: cli,
            status: row.status, errorsLastWeek: errorsLastWeek, runs: runs(row, busiest: busiest),
            statusLine: statusLine(row, errorsLastWeek: errorsLastWeek, now: now), readOnly: readOnly,
            removalIDs: readOnly == nil ? claude.map(\.id).filter(row.writableMembers.contains) : []
        )
    }

    /// A dead Hook still shows the runs the logs hold (inventory.md: it is counted like any other).
    static func runs(_ row: FrameRow, busiest: Int) -> RunsCell.Value {
        let counted = row.cells.values.compactMap(\.count)
        let total = counted.reduce(0, +)
        if total > 0 { return .count(total, share: Double(total) / Double(max(1, busiest))) }
        if !counted.isEmpty { return .zero }
        if row.cells.values.contains(.scanning) { return .pending }
        return .unmeasurable
    }

    /// The mock's Status cell, in its order: failing in 7 days, dead, no run log, never ran, older errors, average time.
    static func statusLine(_ row: FrameRow, errorsLastWeek: Int?, now: Date) -> HooksStatusLine {
        if let errors = errorsLastWeek, errors > 0 {
            return HooksStatusLine(tone: .attention, text: "\(NumberWording.plural(errors, "error")) · 7 days")
        }
        switch row.status {
        case .dead: return HooksStatusLine(tone: .critical, text: "Script missing")
        case .unmeasurable: return HooksStatusLine(tone: .quiet, text: "No run log")
        case .unknown: return HooksStatusLine(tone: .quiet, text: "Unmeasurable")
        case .pending: return HooksStatusLine(tone: .quiet, text: "Counting\u{2026}")
        case .neverRan:
            let note = row.cells.values.compactMap(Self.note).first
            return HooksStatusLine(tone: .quiet, text: note ?? "Never ran")
        case .ran:
            let lifetime = row.cells.values.compactMap(Self.errors).reduce(0, +)
            if lifetime > 0, errorsLastWeek != nil {
                return HooksStatusLine(tone: .quiet, text: "\(NumberWording.plural(lifetime, "error")), none in 7 days")
            }
            if let avg = row.hooks.compactMap({ $0.usage?.avgMs }).first {
                return HooksStatusLine(tone: .quiet, text: "\(NumberWording.milliseconds(avg)) avg")
            }
            let last = row.cells.values.compactMap(Self.last).max()
            return HooksStatusLine(tone: .quiet, text: "Last ran \(DayWording.lastRan(daysAgo: last.flatMap { Self.daysAgo($0, now: now) }))")
        }
    }

    private static func note(_ cell: CoreCLICell) -> String? {
        if case .runs(0, _, _, let note?, _) = cell, !note.isEmpty { return note }
        return nil
    }

    private static func errors(_ cell: CoreCLICell) -> Int? {
        if case .runs(_, let errors, _, _, _) = cell { return errors }
        return nil
    }

    private static func last(_ cell: CoreCLICell) -> String? {
        if case .runs(_, _, let last?, _, _) = cell { return last }
        return nil
    }

    /// Whole UTC days from a `YYYY-MM-DD` usage day to `now` (usage days are UTC dates, inventory.md).
    static func daysAgo(_ day: String, now: Date) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else { return nil }
        calendar.timeZone = utc
        let parts = day.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day
    }

    /// The project's folder name, as the row label shows it.
    static func projectName(_ project: String?) -> String {
        guard let project, !project.isEmpty else { return "project" }
        return (project as NSString).lastPathComponent
    }
}

/// A Hook row's spoken label, pure for the tests: "lint-staged.sh, PreToolUse, Claude Code, Script missing".
enum HooksRowWording {
    static func spoken(_ row: HooksListRow, cli: String?) -> String {
        ([row.label, row.stage] + (cli.map { [$0] } ?? []) + [row.statusLine.text]).joined(separator: ", ")
    }
}
