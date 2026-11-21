import Foundation

/// The two toolbar filters of Skills and Subagents (RD22: `All / Never ran`, no Filter menu, chips or Group by).
enum EquipFilter: String, CaseIterable, Sendable {
    case all, neverRan

    var title: String { self == .all ? "All" : "Never ran" }
}

/// The page's own view state (AR3): never in the store. Nothing is ticked at first (RD41).
struct EquipViewState: Equatable, Sendable {
    var filter: EquipFilter = .all
    /// The `All CLIs` menu's pick: nil is every shown CLI.
    var cli: String?
    var ticked: Set<String> = []

    /// Another filter or CLI clears the ticks: a tick on a row the filter hides would never be seen (the mock's `flt`, `cflt`).
    func filtering(_ filter: EquipFilter) -> EquipViewState { EquipViewState(filter: filter, cli: cli) }
    func scoping(_ cli: String?) -> EquipViewState { EquipViewState(filter: filter, cli: cli) }

    func toggling(_ id: String) -> EquipViewState {
        var next = self
        if next.ticked.contains(id) { next.ticked.remove(id) } else { next.ticked.insert(id) }
        return next
    }

    /// The header checkbox and `Select N Suggested`: all of `ids` ticked, or none of them when all were.
    func togglingAll(_ ids: [String]) -> EquipViewState {
        var next = self
        if !ids.isEmpty, ids.allSatisfy(ticked.contains) { next.ticked.subtract(ids) } else { next.ticked.formUnion(ids) }
        return next
    }
}

/// One row of the table as it is drawn (the mock's `pageEquip` row): the name and its sub-line, the logo toggles, the Sessions
/// total with its bar, Last ran, and whether it can be ticked.
struct EquipListRow: Identifiable, Sendable {
    let row: FrameRow
    let readers: EquipReaders
    /// One per shown CLI, in the fixed order; the inspector's tiles take the same values (RD-R12).
    let toggles: [CLIToggleState]
    /// Sessions over the shown CLIs that have the kind.
    let total: Int
    /// A shown CLI's folder could not be read: the total is a floor (`+?`).
    let hasUnknown: Bool
    /// `today`, `12 days ago`, `—`; nil while the first usage scan runs.
    let lastRan: String?
    /// "Project · payments-web · added 41 days ago · Pull text out of PDF files".
    let subline: String?
    let isPending: Bool

    var id: String { row.id }
    var name: String { row.name }
    var isNeverRan: Bool { row.status == .neverRan }
    /// Plugin and project rows are listed, read-only, never ticked (the "Inferred" Project items line, RD26).
    var isReadOnly: Bool { row.isPlugin || row.isProject }
    var isTickable: Bool { !isReadOnly && !isPending && !row.writableMembers.isEmpty }
}

/// Everything the Skills or Subagents page shows, from the store and the page's view state. Pure, so the hero, the rows, the
/// group head, the toolbar's `Remove N selected…` and the inspector read one value and cannot disagree (AR3).
struct EquipListModel: Sendable {
    enum Phase: Equatable, Sendable {
        /// `loadout.rows` has not answered yet.
        case loading
        /// It could not be read and nothing was read before.
        case failed(String)
        /// No CLI has one.
        case empty
        case normal
    }

    let kind: EquipKind
    let phase: Phase
    /// The first usage scan is running: rows are listed with pending counts (RD-R13).
    let isScanning: Bool
    let figure: PageFigure
    let view: EquipViewState
    /// The shown CLIs, in the fixed order (the strip's slots).
    let clis: [CoreRegistryCLI]
    /// Every row of the kind, most sessions first (RD22, D33).
    let all: [EquipListRow]
    /// The rows the filters show, in the same order.
    let visible: [EquipListRow]
    /// The ids `Select N Suggested` ticks: suggested rows the Never ran filter shows under the current CLI pick.
    let suggested: [String]
    /// Shown CLIs whose folder could not be read: each gets the problem band.
    let unreadable: [CoreRegistryCLI]
    let roots: [String: String]

    static let scanningTitle = "Counting sessions in your logs…"
    static let loadingTitle = "Reading your CLI folders…"

    // MARK: Derived

    /// Never ran rows of the kind, plugin and project ones included (a fact, RD-R2): the hero's count.
    var neverRan: [EquipListRow] { all.filter(\.isNeverRan) }
    /// Rows whose answer is not known (a CLI unreadable and nothing counted).
    var unknownCount: Int { all.filter { $0.row.status == .unknown }.count }
    /// The top total of the kind: the Sessions bars are drawn against it.
    var maxTotal: Int { max(1, all.map(\.total).max() ?? 0) }

    /// The ticked rows shown that SpaceVibe may write: what `Remove N selected…`, `Add to…` and `Remove from…` act on.
    var picked: [EquipListRow] { visible.filter { view.ticked.contains($0.id) && $0.isTickable } }
    var tickable: [String] { visible.filter(\.isTickable).map(\.id) }
    var allSuggestedTicked: Bool { !suggested.isEmpty && suggested.allSatisfy(view.ticked.contains) }

    func row(_ id: String?) -> EquipListRow? { id.flatMap { id in all.first { $0.id == id } } }

    /// The hero (RD-R2): `N never ran`, `· N Unmeasurable` when some rows cannot be judged; `…` while scanning.
    var heroFigure: PageHero.Figure {
        switch figure {
        case .count(let n, _): .value(NumberWording.count(n), unit: nil)
        case .pending: .scanning
        default: .unmeasurable
        }
    }

    var heroLabel: String {
        guard case .count = figure, unknownCount > 0 else { return "never ran" }
        return "never ran · \(NumberWording.count(unknownCount)) Unmeasurable"
    }

    /// The Never ran group head: shown once the scan has counted and some row never ran (amber only when something is
    /// suggested, RD10).
    var showsNeverRanHead: Bool { !isScanning && !neverRan.isEmpty }
    var neverRanSeverity: GroupSeverity { suggested.isEmpty ? .none : .attention }

    /// The toolbar's destructive slot: nil (an empty slot) while scanning or empty; otherwise its title, disabled at 0.
    var primaryTitle: String? {
        guard phase == .normal, !isScanning else { return nil }
        return picked.isEmpty ? "Select rows to remove" : "Remove \(NumberWording.count(picked.count)) selected…"
    }

    /// The table's line when the filters leave nothing (the mock's wording).
    var noMatch: String {
        let who = view.cli.flatMap { id in clis.first { $0.id == id }?.name } ?? "these CLIs"
        return "No \(kind.noun) is loaded by \(who)."
    }

    var emptyTitle: String { "No \(kind.plural) installed" }
    var emptyText: String {
        "No CLI has a \(kind.noun) yet. Drop a folder into a CLI’s \(kind.folderWord) folder and it shows here."
    }

    /// `Remove…` (inspector, row menu): the explicit removal, for a row SpaceVibe may write.
    func canRemove(_ row: EquipListRow) -> Bool { row.isTickable }

    // MARK: Building

    @MainActor
    static func from(_ store: FrameStore, kind: EquipKind, view: EquipViewState, now: Date = Date()) -> EquipListModel {
        var failure: String?
        if case .failed(let message) = store.states[.loadout] { failure = message }
        return make(kind: kind, world: store.world(now: now), loading: store.loading, failed: store.failedEmpty, failure: failure,
                    view: view, now: now)
    }

    static func make(kind: EquipKind, world: FrameWorld, loading: Set<FrameSource>, failed: Set<FrameSource>, failure: String?,
                     view: EquipViewState, now: Date) -> EquipListModel {
        let snapshot = world.snapshot
        let scanning = snapshot.loadout?.usage == .scanning
        let figure = world.figure(for: kind.page, loading: loading, failed: failed)
        let clis = world.clis
        let supporting = clis.filter { $0.supports.supports(kind.kind) }.map(\.id)
        let folders = snapshot.loadout?.folders ?? []
        let built = world.rows(kind.kind).map { row -> EquipListRow in
            let readers = EquipReaders(readers: world.readers(of: row), registry: snapshot.registry, kind: kind.kind, folders: folders)
            let counted = supporting.compactMap { row.cell($0).count }
            let lastDays = supporting.compactMap { id -> Int? in
                if case .sessions(_, _, let last?, _) = row.cell(id) { return daysAgo(last, now: now) }
                return nil
            }.min()
            return EquipListRow(
                row: row, readers: readers, toggles: EquipToggles.states(row, clis: clis, readers: readers, noun: kind.noun),
                total: counted.reduce(0, +), hasUnknown: supporting.contains { row.cell($0) == .unknown },
                lastRan: scanning ? nil : DayWording.lastRan(daysAgo: lastDays), subline: subline(row, scanning: scanning, now: now),
                isPending: scanning)
        }
        // Most sessions first; equal totals keep the core's order (RD22).
        let all = built.enumerated().sorted { a, b in a.element.total != b.element.total ? a.element.total > b.element.total : a.offset < b.offset }
            .map(\.element)
        let inScope = all.filter { row in view.cli.map { row.row.presence($0) == .on } ?? true }
        let visible = inScope.filter { view.filter == .all || scanning || $0.isNeverRan }
        let suggestedIDs = world.suggested
        let suggested = inScope.filter { $0.isNeverRan && suggestedIDs.contains($0.id) && $0.isTickable }.map(\.id)
        let unreadable = clis.filter { cli in all.contains { $0.row.cell(cli.id) == .unknown } }
        let phase: Phase
        if snapshot.loadout == nil {
            phase = failure.map(Phase.failed) ?? .loading
        } else {
            phase = all.isEmpty ? .empty : .normal
        }
        return EquipListModel(kind: kind, phase: phase, isScanning: scanning, figure: figure, view: view, clis: clis, all: all,
                              visible: visible, suggested: suggested, unreadable: unreadable, roots: snapshot.loadout?.roots ?? [:])
    }

    /// The quiet line under the name (the mock's `.nm i`): the project, the D63 "added …" note on a Never ran row once the scan
    /// has counted, then the description.
    static func subline(_ row: FrameRow, scanning: Bool, now: Date) -> String? {
        var parts: [String] = []
        if row.isProject, let name = EquipToggles.projectName(row) { parts.append("Project · \(name)") }
        if !scanning, row.status == .neverRan, let seen = row.firstSeen { parts.append(DayWording.added(secondsAgo: now.timeIntervalSince(seen))) }
        if let description = row.items.first?.description, !description.isEmpty { parts.append(description) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// Whole days from a usage day (`YYYY-MM-DD`, UTC like every usage day) to the UTC day of `now`; nil for any other text.
    static func daysAgo(_ day: String, now: Date) -> Int? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let from = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return utc.dateComponents([.day], from: from, to: utc.startOfDay(for: now)).day
    }
}
