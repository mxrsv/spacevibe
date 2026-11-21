import Foundation

/// The latest engine readings the store holds, as one value: the input of every derivation (plan AR2, AR3).
struct FrameSnapshot: Equatable, Sendable {
    var registry: [CoreRegistryCLI] = []
    var inventory: CoreInventorySnapshot?
    var loadout: CoreLoadoutRows?
    /// Global, and the Shared and Local file of every known project.
    var rules: [FrameScope: CoreRulesSnapshot] = [:]
    var limits: CoreLimitsResult?
    var activity: CoreActivityReport?
    var journal: CoreJournalHistory?
}

/// What the derivations need beside the snapshot: engine answers the store keeps in the derivations' terms, inputs the
/// engine does not report yet, and the user's settings. Every member starts empty: an empty input gives no finding and no
/// figure, never an invented one (FE-D3). Each names who fills it.
struct FrameFacts: Equatable, Sendable {
    /// The store fills hook errors in 7 days (from `loadout.rows`) and the Keep list (from `findings.kept`); RB-R8 the
    /// Balance pins.
    var findings = FindingFacts()
    /// RB-E7: `clean.scan`.
    var clean: CleanScan?
    /// RB-R8 Settings › CLIs › Show: hidden registry ids. A hidden CLI leaves every list; it still locks and still loses files.
    var hidden: Set<String> = []
}

/// The one figure a page leads with; the sidebar shows the same value, so the two cannot disagree (AR3, RD10).
enum PageFigure: Equatable, Sendable {
    /// The page's source has not answered yet (the sidebar's "…", Clean's "Measuring").
    case pending
    /// The source could not be read and nothing was read before.
    case failed
    case count(Int, tone: FindingSeverity?)
    case percentLeft(Double, tone: FindingSeverity?)
    case bytes(Int64)
    /// No CLI gives the data (Limits without a measured Window).
    case unmeasurable
    /// The engine does not report this figure yet (Clean before RB-E7).
    case notMeasured
}

/// Every derivation of one snapshot. Pure: built from the snapshot, the facts and the clock, and read by every page and
/// the sidebar. Selection, ticks, filters and popovers are page state and never enter it. Port of the reference mock's
/// `world` and `sideVals` (`src/m-model.js`).
struct FrameWorld: Sendable {
    let snapshot: FrameSnapshot
    let facts: FrameFacts
    /// The shown CLIs in registry order; at least one stays shown ("Show guard").
    let clis: [CoreRegistryCLI]
    /// Every row any shown CLI has or might have (an unknown cell keeps a row listed).
    let rows: [FrameRow]
    /// The Never ran / Dead set every surface shares (consistency rule "one Never ran set").
    let candidates: [FrameRow]
    let windows: [WindowPace]
    let heroWindow: WindowPace?
    let wideAllows: [(rule: CoreRule, file: FrameScope)]
    let sessions: [CoreActivitySession]
    let findings: [InboxFinding]
    let keptFindings: [InboxFinding]
    let clean: CleanPlan

    init(snapshot: FrameSnapshot, facts: FrameFacts = FrameFacts(), now: Date) {
        self.snapshot = snapshot
        self.facts = facts
        let shown = snapshot.registry.filter { !facts.hidden.contains($0.id) }
        clis = shown.isEmpty ? Array(snapshot.registry.prefix(1)) : shown
        let ids = clis.map(\.id)
        rows = (snapshot.loadout.map { FrameRow.rows(from: $0, now: now) } ?? []).filter { row in
            ids.contains { row.presence($0) == .on || row.presence($0) == .unknown }
        }
        candidates = rows.filter(\.isCandidate)
        windows = WindowPace.windows(limits: snapshot.limits, registry: clis, now: now)
        heroWindow = WindowPace.hero(windows)
        wideAllows = snapshot.rules.keys.sorted(by: Self.fileOrder).flatMap { file in
            WholeToolRule.allows(in: snapshot.rules[file]!, file: file).map { (rule: $0, file: file) }
        }
        sessions = (snapshot.activity?.sessions ?? []).filter { ids.contains($0.cli.rawValue) }
        let found = Findings.all(rows: rows, wideAllows: wideAllows, windows: windows, sessions: sessions, shownCLIs: ids, facts: facts.findings)
        findings = found.open
        keptFindings = found.kept
        clean = CleanPlan(candidates: candidates, kept: facts.findings.kept, scan: facts.clean,
                          locks: CleanLocks(activity: snapshot.activity, registry: snapshot.registry), shownCLIs: ids)
    }

    /// Global first, then projects by folder, Shared before Local.
    private static func fileOrder(_ a: FrameScope, _ b: FrameScope) -> Bool {
        let key = { (s: FrameScope) in (s.dir ?? "", s.scope == .local ? 1 : 0) }
        return key(a) < key(b)
    }

    // MARK: Pages

    func rows(_ kind: CoreKind) -> [FrameRow] { rows.filter { $0.kind == kind } }

    /// The Never ran rows of one kind; Hooks add their dead ones (the Hooks hero is "dead or never ran", RD-R2). Plugin and
    /// project rows count: they are a fact, only never suggested.
    func neverRan(_ kind: CoreKind) -> [FrameRow] { rows(kind).filter { $0.status == .neverRan } }
    var deadHooks: [FrameRow] { rows(.hook).filter { $0.status == .dead } }

    /// The candidates `Select N Suggested` ticks: not just added, not plugin or project, not kept, not a Hook SpaceVibe does
    /// not write (D25).
    var suggested: Set<String> {
        Set(candidates.filter { $0.isSuggested(kept: facts.findings.kept) && !$0.isHookSpaceVibeDoesNotWrite }.map(\.id))
    }

    var groups: [InboxGroup] { Findings.groups(findings) }
    var waiting: [CoreActivitySession] { sessions.filter { $0.state == .waiting } }
    var running: [CoreActivitySession] { sessions.filter { $0.state == .running } }

    /// The rows a bulk removal takes: the ticked rows among those shown, that the app may write (`Remove N selected` counts
    /// rows, not copies). A tick on a row the filter hides never removes it.
    func removalSet(selected: Set<String>, shown: [FrameRow]) -> [FrameRow] {
        shown.filter { selected.contains($0.id) && !$0.isPlugin && !$0.isProject && !$0.writableMembers.isEmpty }
    }

    /// When the newest status line snapshot of this Claude account was taken (`limits.read` `statusline.at`, RD24): what
    /// Settings › Limits ages. Not the Claude entry's `at`, which may date Claude's usage cache. Nil when there is none.
    var statuslineAt: Date? { snapshot.limits?.statusline?.at.map(Date.init(timeIntervalSince1970:)) }

    // MARK: Readers

    /// From `loadout.rows`' readers map; nil when a member names no folder of it. Members of other rows that share a file
    /// with this one are `elsewhere`.
    func readers(of row: FrameRow) -> ItemReaders? {
        guard let loadout = snapshot.loadout else { return nil }
        return ItemReaders(row: row, folders: loadout.folders, loadoutItems: loadout.items + loadout.extraItems)
    }

    /// Every installed CLI that ends up without the row once `members` are removed, hidden ones included.
    func losers(of row: FrameRow, removing members: Set<String>) -> ReadersAnswer<[String]> {
        guard let readers = readers(of: row) else { return .unknown }
        return .known(readers.losers(removing: readers.expand(members), among: snapshot.registry.filter { $0.supports.supports(row.kind) }.map(\.id)))
    }

    /// Every installed CLI that reads a file removing `members` takes, hidden ones included: the readers the engine names
    /// when it refuses a removal that does not name them all.
    func fileReaders(of row: FrameRow, removing members: Set<String>) -> ReadersAnswer<[String]> {
        guard let readers = readers(of: row) else { return .unknown }
        return .known(readers.fileReaders(removing: readers.expand(members), among: snapshot.registry.map(\.id)))
    }

    /// The CLIs whose folder gives `cli` the row (RD31); `.known(nil)` when `cli` has its own copy.
    func via(of row: FrameRow, cli: String) -> ReadersAnswer<[String]?> {
        guard let readers = readers(of: row) else { return .unknown }
        return .known(readers.via(cli))
    }

    /// Turning `cli` off would delete the row's last file (D53): its logo is not a toggle.
    func isLastCopy(of row: FrameRow, turningOff cli: String) -> ReadersAnswer<Bool> {
        guard let readers = readers(of: row) else { return .unknown }
        return .known(readers.isLastCopy(turningOff: cli))
    }

    /// The number of files the row has: distinct real paths, not lit logos (D53).
    func fileCount(of row: FrameRow) -> ReadersAnswer<Int> {
        guard let readers = readers(of: row) else { return .unknown }
        return .known(readers.files().count)
    }

    // MARK: Figures

    /// The figure of one page, for its hero and its sidebar item alike. `loading` names the sources still unanswered and
    /// `failed` those that could not be read with nothing read before (the store's states).
    func figure(for page: FramePage, loading: Set<FrameSource>, failed: Set<FrameSource>) -> PageFigure {
        let usage: Set<FrameSource> = [.loadout]
        let scanning = snapshot.loadout?.usage == .scanning
        func gate(_ needs: Set<FrameSource>, usageToo: Bool) -> PageFigure? {
            if !needs.isDisjoint(with: failed) { return .failed }
            if !needs.isDisjoint(with: loading) || (usageToo && scanning) { return .pending }
            return nil
        }
        switch page {
        case .inbox:
            // The Keep list decides the count: until it is read, kept findings would be counted.
            if let early = gate(usage.union([.rules(.global), .limits, .activity, .kept]), usageToo: true) { return early }
            let tone: FindingSeverity? = findings.isEmpty ? nil : findings.contains { $0.severity == .critical } ? .critical : .attention
            return .count(findings.count, tone: tone)
        case .skills, .subagents:
            if let early = gate(usage, usageToo: true) { return early }
            let count = neverRan(page == .skills ? .skill : .agent).count
            return .count(count, tone: count > 0 ? .attention : nil)
        case .hooks:
            if let early = gate(usage, usageToo: true) { return early }
            let count = deadHooks.count + neverRan(.hook).count
            return .count(count, tone: count > 0 ? .critical : nil)
        case .rules:
            if let early = gate([.rules(.global)], usageToo: false) { return early }
            return .count(wideAllows.count, tone: wideAllows.isEmpty ? nil : .attention)
        case .limits:
            if let early = gate([.limits], usageToo: false) { return early }
            guard let hero = heroWindow, let left = hero.left else { return .unmeasurable }
            return .percentLeft(left, tone: hero.isBehind ? FindingSeverity(hero.severity) : nil)
        case .activity:
            if let early = gate([.activity], usageToo: false) { return early }
            return .count(waiting.isEmpty ? running.count : waiting.count, tone: waiting.isEmpty ? nil : .attention)
        case .clean:
            if let early = gate(usage.union([.activity]), usageToo: true) { return early }
            return clean.cleanableBytes.map(PageFigure.bytes) ?? .notMeasured
        }
    }
}
