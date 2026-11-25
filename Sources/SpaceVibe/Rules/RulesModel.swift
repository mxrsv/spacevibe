import AppKit
import Observation

/// The Rules screen's state: the chosen scope, what was read for it and every write.
///
/// Everything goes through the Go core (`env.goCore`), so reads and writes run off the main actor. A refresh (launch, app activation, after a write or an Undo) asks the core to discover the projects
/// again; a scope switch reuses the list the core holds. A newer read replaces an older one, so a slow read never overwrites a
/// fresh one. The core keeps settings-file paths out of its messages and checks a rule's shape (`rules.check`). Nothing here
/// reads `env` values or logs rule text.
@MainActor
@Observable
final class RulesModel {
    let env: AppEnvironment

    private(set) var snapshot: RulesSnapshot?
    /// The last read could not run. With a snapshot on screen it shows as a banner over the stale data.
    private(set) var failure: String?
    private(set) var selection = RulesSelection.global
    private(set) var isWriting = false

    static let page = "rules"

    /// Screenshots only: show row actions without hover.
    var revealRowActions = false

    // The v5 tab's own state (V5-R57, V5-R61, V5-R68). The tab shows the global scope only; the old page keeps the rest.
    var filter = RulesFilter()
    /// The rule the keys act on: the chosen one while it is listed, else the first listed.
    var currentID: String?
    /// The rule whose detail popover is open.
    var detailID: String?
    var isFilterOpen = false
    /// The verdict menu that is open: one rule's or a whole family's.
    var verdictMenu: VerdictTarget?

    /// The CLIs on this Mac: the shell's reading (`limits.read`), which a shot or a test replaces.
    @ObservationIgnored var limitsResults: () -> [CoreLimitsEntry]
    /// The ids listed now, in order: the tab writes them, so a removal can hand the current rule to its neighbour (D2).
    @ObservationIgnored var listedKeys: [String] = []
    @ObservationIgnored private var started = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private(set) var readsInFlight = 0

    init(env: AppEnvironment) {
        self.env = env
        limitsResults = { env.limits.results }
    }

    /// A model over a snapshot read elsewhere (a shot's in-memory state): it reads nothing.
    convenience init(env: AppEnvironment, snapshot: RulesSnapshot?, failure: String? = nil) {
        self.init(env: env)
        self.snapshot = snapshot
        self.failure = failure
        started = true
    }

    private var service: any CoreService { env.goCore }

    var isLoading: Bool { snapshot == nil && failure == nil }

    /// Reads are done and nothing waits for the user. Screenshots wait for this.
    var isSettled: Bool { snapshot != nil && readsInFlight == 0 && !isWriting }

    /// The rules in the global file; nil while unknown, which includes a file that does not parse or cannot be read (a count of 0 would
    /// say "no rules", and V5-R68 hides them instead).
    var badge: Int? {
        guard let snapshot, !snapshot.globalNotReadable else { return nil }
        if snapshot.selection == .global, !snapshot.problems.isEmpty { return nil }
        return snapshot.globalRuleCount
    }

    // MARK: The v5 tab

    /// Codex is on this Mac unless the shell's reading (`limits.read`) says it is not. Before a reading exists nothing says so, and a Mac
    /// with Codex but no `config.toml` must not read "not installed": the page then says there is no file.
    var codexInstalled: Bool {
        limitsResults().first { $0.cli == .codex }.map { $0.state != .notInstalled } ?? true
    }

    var page: RulesPage { RulesPage(snapshot: snapshot, failure: failure, codexInstalled: codexInstalled, filter: filter) }

    /// The tab shows the global scope: the old page (or the palette) may have left another selected.
    func showGlobal() { select(.global) }

    var isMenuOpen: Bool { isFilterOpen || verdictMenu != nil }

    func current(in visible: [CoreRule]) -> CoreRule? { visible.first { $0.id == currentID } ?? visible.first }

    /// A click on a row: it becomes current and its detail opens (V5-R57).
    func open(_ rule: CoreRule) {
        currentID = rule.id
        detailID = rule.id
    }

    /// `j` (`by: 1`) and `k` (`by: -1`) over the rows listed now, stopping at the first and the last; the detail closes.
    func move(by step: Int, in visible: [CoreRule]) {
        guard let current = current(in: visible), let index = visible.firstIndex(of: current) else { return }
        currentID = visible[min(max(index + step, 0), visible.count - 1)].id
        detailID = nil
    }

    /// `Return`: the detail of the current row, closed when it is open already.
    func toggleDetail(of rule: CoreRule?) {
        guard let rule else { return }
        currentID = rule.id
        detailID = detailID == rule.id ? nil : rule.id
    }

    /// A small card's row: clear the Filter, open the rule's band, make it current and open its detail.
    func reveal(_ rule: CoreRule, store: OpenStateStore) {
        filter.clear()
        store.setOpen(true, page: Self.page, id: RuleFamily.of(tool: rule.tool).id)
        open(rule)
    }

    func toggleFilter(_ value: String) {
        filter.toggle(.verdict, value)
        detailID = nil
    }

    func clearFilters() {
        filter.clear()
        detailID = nil
    }

    func toggleVerdictMenu(_ target: VerdictTarget) {
        verdictMenu = verdictMenu == target ? nil : target
    }

    // MARK: Reading

    /// The first read. Safe to call again.
    func start() {
        guard !started else { return }
        started = true
        reload()
    }

    /// The app became active again: the files may have changed outside.
    func refresh() {
        guard started else { return }
        reload()
    }

    func retry() {
        failure = nil
        reload()
    }

    /// `rediscover: false` reuses the project list the core holds (a scope switch); a refresh always discovers again.
    func reload(rediscover: Bool = true) {
        generation += 1
        let mine = generation
        let wanted = selection.scope
        readsInFlight += 1
        Task {
            let outcome = await attempt { try await service.rulesSnapshot(scope: wanted.kind, dir: wanted.dir, refreshProjects: rediscover) }
            readsInFlight -= 1
            guard mine == generation else { return }
            switch outcome {
            case .success(let dto):
                let fresh = RulesSnapshot(dto)
                snapshot = fresh
                selection = fresh.selection
                failure = nil
            case .failure(let error):
                failure = AppEnvironment.message(error)
            }
        }
    }

    private func attempt<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    // MARK: Choices

    func select(_ choice: RulesSelection) {
        guard choice != selection else { return }
        selection = choice
        reload(rediscover: false)
    }

    // MARK: The v5 tab's writes (V5-R68)

    /// A rule's verdict: one `rules.changeVerdict`, one toast with Undo.
    func set(_ rule: CoreRule, to verdict: CoreVerdict) {
        guard rule.verdict != verdict, page.state == .ready else { return }
        detailID = nil
        write(label: RulesTabWording.ruleChanged(rule.rule, to: verdict), undone: RulesTabWording.undone, [Self.changeStep(rule, to: verdict)])
    }

    /// A whole family's verdict (V5-R67, owner call C1): the family's wide rules move, path rules keep their verdicts, and the toast says
    /// how many rules changed and how many path rules were kept. It is ONE `rules.changeVerdicts`: one Journal entry, one toast, one
    /// Undo. No wide rule differs: a message, nothing written.
    func set(_ family: RuleFamily, to verdict: CoreVerdict) {
        guard page.state == .ready else { return }
        let members = RulesLayout.unique(page.rules).filter { RuleFamily.of(tool: $0.tool) == family }
        let wide = members.filter(\.isWide)
        let changing = wide.filter { $0.verdict != verdict }
        let kept = members.filter { !$0.isWide && $0.verdict != verdict }.count
        detailID = nil
        guard !changing.isEmpty else {
            env.toasts.show(wide.isEmpty ? RulesTabWording.familyNoWide(family) : RulesTabWording.familyUnchanged(family, to: verdict))
            return
        }
        let moves = changing.map { CoreRuleMove(rule: $0.rule, from: $0.verdict) }
        write(label: RulesTabWording.familyChanged(family, to: verdict, count: changing.count, kept: kept), undone: RulesTabWording.undone, [
            { core, scope in try await core.rulesChangeVerdicts(scope: scope.kind, dir: scope.dir, to: verdict, rules: moves).entry },
        ])
    }

    func removeRule(_ rule: CoreRule) {
        guard page.state == .ready else { return }
        detailID = nil
        let (verdict, text) = (rule.verdict, rule.rule)
        let before = currentID
        let after = CurrentRow.neighbour(of: [rule.id], current: before, in: listedKeys)
        let taken = write(
            label: RulesTabWording.removed(text), undone: RulesTabWording.undone,
            onFailure: { [weak self] message in
                guard let self else { return }
                env.toasts.show(message, tone: .danger)
                if currentID == after { currentID = before }
            },
            [{ core, scope in try await core.rulesRemove(scope: scope.kind, dir: scope.dir, verdict: verdict, rule: text).entry }]
        )
        if taken, after != before { currentID = after }
    }

    private static func changeStep(_ rule: CoreRule, to verdict: CoreVerdict) -> @Sendable (any CoreService, RulesScope) async throws -> CoreJournalEntry? {
        let (from, text) = (rule.verdict, rule.rule)
        return { core, scope in try await core.rulesChangeVerdict(scope: scope.kind, dir: scope.dir, rule: text, from: from, to: verdict).entry }
    }

    /// One write for every control: through the core, a toast with Undo, and a reload after the write and after an Undo. A nil
    /// result ("nothing to change", `rules.setCapability` only) is a message, never a success toast. Several `works` are one change
    /// (`AppEnvironment.performBatchWithUndo`); the family change is one call, so one entry and one Undo.
    /// Returns false when the write was not taken (no snapshot, or one is running).
    @discardableResult
    func write(
        label: String,
        undone: String? = nil,
        scope target: RulesScope? = nil,
        onFailure: (@MainActor (String) -> Void)? = nil,
        _ works: [@Sendable (any CoreService, RulesScope) async throws -> CoreJournalEntry?]
    ) -> Bool {
        guard let snapshot else {
            env.toasts.show("The config folders could not be resolved.", tone: .danger)
            return false
        }
        guard !isWriting else { return false }
        isWriting = true
        let scope = target ?? snapshot.selection.scope
        env.performBatchWithUndo(
            label: label,
            undone: undone,
            via: service,
            afterChange: { [weak self] in
                guard let self else { return }
                isWriting = false
                reload()
            },
            onFailure: { [weak self] message in
                guard let self else { return }
                isWriting = false
                if let onFailure { onFailure(message) } else { env.toasts.show(message, tone: .danger) }
                // A refused or failed write may still have changed the file (a restarted helper), so the list is read again.
                reload()
            },
            works.map { work in
                { core in
                    guard let entry = try await work(core, scope) else { throw CoreError("Nothing to change: the file already holds that.", status: 409) }
                    return entry
                }
            }
        )
        return true
    }

    @discardableResult
    private func write(
        label: String,
        scope target: RulesScope? = nil,
        onFailure: (@MainActor (String) -> Void)? = nil,
        _ work: @escaping @Sendable (any CoreService, RulesScope) async throws -> CoreJournalEntry?
    ) -> Bool {
        write(label: label, scope: target, onFailure: onFailure, [work])
    }
}
