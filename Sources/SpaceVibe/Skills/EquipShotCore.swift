import Foundation

/// The in-memory engine the redesign's Skills and Subagents shots read (`EquipFrameShots`): `EquipShotData` in each page state
/// the fixture home cannot hold. Its writes answer as the core would and change what it lists next, so a write shot shows the
/// re-read rows and its toast. Never used outside shot mode.
final class EquipShotCore: CoreService, @unchecked Sendable {
    enum Scenario: String, CaseIterable, Sendable {
        /// The mock's items at 2 CLIs (today's registry).
        case normal
        /// The same items at 6 and at 10 CLIs: an illustration of RD13 and RD28 (RD42), one layout.
        case six, ten
        /// No CLI has one.
        case empty
        /// The first usage scan never ends: rows with pending counts.
        case scanning
        /// `~/.codex` unreadable: every Codex cell unknown, the banner.
        case error
        /// `loadout.rows` refused: nothing read.
        case failed
        /// The break-ui data at 10 CLIs.
        case worst
        /// A write the core refuses (the mock's `writefail` for Skills).
        case refused
    }

    let scenario: Scenario
    let kind: CoreKind
    let now: Date
    private let lock = NSLock()
    /// Members a shot removed and copies it added (member ids `<folder key>:<kind>:<name>`).
    private var removed: Set<String> = []
    private var added: [String: [String]] = [:]

    init(_ scenario: Scenario, kind: CoreKind, now: Date = Date()) {
        self.scenario = scenario
        self.kind = kind
        self.now = now
    }

    var registry: [CoreRegistryCLI] {
        switch scenario {
        case .six: EquipShotData.registry(count: 6)
        case .ten, .worst: EquipShotData.registry(count: 10)
        default: EquipShotData.registry(count: 2)
        }
    }

    private func refuse(_ method: String) -> CoreError { CoreError("\(method) is not served in a shot.", status: 501) }

    private var specs: [EquipShotData.Spec] {
        switch scenario {
        case .empty: []
        case .worst: EquipShotData.worst(kind)
        default: kind == .skill ? EquipShotData.skills : EquipShotData.subagents
        }
    }

    // MARK: Reads

    func initialize() async throws -> CoreInitializeResult { throw refuse("initialize") }
    func clisRegistry() async throws -> CoreRegistryResult { CoreRegistryResult(clis: registry) }

    func inventoryRead() async throws -> CoreInventorySnapshot {
        CoreInventorySnapshot(items: [], hooks: [], problems: [], events: [:], roots: ["claude": "~/.claude", "codex": "~/.codex"])
    }

    func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        if scenario == .scanning { try await Task.sleep(for: .seconds(3600)) }
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }

    func loadoutRows() async throws -> CoreLoadoutRows {
        if scenario == .failed { throw CoreError("~/.claude/\(kind == .skill ? "skills" : "agents") could not be read.", status: 500) }
        let (gone, copies) = lock.withLock { (removed, added) }
        // The cells follow the files, as the core's would: a removed copy leaves its readers, an added one reaches its CLI.
        let changed = specs.map { spec -> EquipShotData.Spec in
            var next = spec
            let keys = Set(gone.filter { name(of: $0) == spec.name }.compactMap { $0.split(separator: ":").first.map(String.init) })
            if keys.contains("claude") { next.claude = nil }
            if keys.contains("codex") || keys.contains("agents") { next.codex = nil }
            next.extra.removeAll(where: keys.contains)
            for target in copies[spec.name] ?? [] {
                switch target {
                case "claude": next.claude = next.claude ?? 0
                case "codex": next.codex = next.codex ?? 0
                default: if !next.extra.contains(target) { next.extra.append(target) }
                }
            }
            return next
        }
        return EquipShotData.loadout(kind, specs: changed, registry: registry, now: now,
                                     unreadable: scenario == .error ? ["codex"] : [], scanning: scenario == .scanning)
    }

    func activityRead() async throws -> CoreActivityReport { Self.noActivity }
    func activitySubscribe() -> AsyncThrowingStream<CoreActivityReport, Error> { AsyncThrowingStream { $0.yield(Self.noActivity) } }
    func activityStop(cli: CoreCLI, id: String) async throws -> CoreStopResult { throw refuse("activity.stop") }
    func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    func limitsRead() async throws -> CoreLimitsResult { CoreLimitsResult(limits: []) }
    func rulesSnapshot(scope: CoreRuleScope, dir: String?, refreshProjects: Bool) async throws -> CoreRulesSnapshot { throw refuse("rules.snapshot") }
    func findingsKept() async throws -> CoreKeptFindings { CoreKeptFindings(kept: []) }

    // MARK: Writes

    /// The refused shot's sentences name the item and CLI the shot really pressed (the mock's `writefail` wording for Skills
    /// and Subagents), so the toast never names an item the page shows as already on.
    private func refusedAdd(_ id: String, targets: [String]) -> CoreError {
        let item = name(of: id)
        let names = registry.filter { targets.contains($0.id) }.map(\.name)
        let folder = EquipShotData.folders(kind).first { $0.key == targets.first }?.path ?? "~/.\(targets.first ?? "")"
        return CoreError("Couldn\u{2019}t add \(item) to \(CLINames.sentence(names)): \(folder)/\(item) already exists and is not a "
            + "SpaceVibe copy. Nothing changed.", status: 409)
    }

    private func refusedRemove(_ id: String) async -> CoreError {
        let item = name(of: id)
        let path = (try? await loadoutRows())?.items.first { $0.id == id || $0.name == item }?.path ?? item
        return CoreError("Couldn\u{2019}t remove \(item): \(path) changed since SpaceVibe read it. Nothing changed.", status: 409)
    }

    private func entry(_ label: String) -> CoreJournalEntry {
        CoreJournalEntry(id: "shot-1", at: "2026-11-21T10:00:00.000Z", label: label, undone: false, count: 1)
    }

    private func name(of id: String) -> String { id.split(separator: ":").last.map(String.init) ?? id }

    func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult {
        if scenario == .refused { throw refusedAdd(id, targets: targets) }
        let item = name(of: id)
        lock.withLock { added[item, default: []] += targets }
        return CoreCopyToResult(entry: entry("Copied \(kind.rawValue) \(item)"), alsoReaders: [])
    }

    func loadoutRemoveFrom(id: String, clis: [String]) async throws -> CoreRemoveFromResult {
        if scenario == .refused { throw await refusedRemove(id) }
        let item = name(of: id)
        let rows = try await loadoutRows()
        let gone = rows.items.filter { item in
            item.name == name(of: id) && !Set(rows.folders.first { $0.path == item.folder }?.readBy ?? []).isDisjoint(with: clis)
        }
        lock.withLock { removed.formUnion(gone.map(\.id)) }
        return CoreRemoveFromResult(entry: entry("Removed \(kind.rawValue) \(item)"), lost: clis, stillHave: [])
    }

    func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult {
        if scenario == .refused { throw await refusedRemove(ids.first ?? "") }
        let rows = try await loadoutRows()
        let readers = Set(rows.items.filter { ids.contains($0.id) }.flatMap { item in rows.folders.first { $0.path == item.folder }?.readBy ?? [] })
        lock.withLock { removed.formUnion(ids) }
        return CoreRemoveManyResult(entry: entry("Removed"), lost: registry.map(\.id).filter(readers.contains))
    }

    func loadoutCopyToOther(id: String) async throws -> CoreEntryResult { throw refuse("loadout.copyToOther") }
    func loadoutRemoveItem(id: String) async throws -> CoreEntryResult { throw refuse("loadout.removeItem") }
    func loadoutRemoveDeadHooks(cli: CoreCLI) async throws -> CoreEntryResult { throw refuse("loadout.removeDeadHooks") }
    func journalUndo(id: String) async throws -> CoreUndoResult { throw refuse("journal.undo") }
    func rulesPreview(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreCapabilityPreview { throw refuse("rules.preview") }
    func rulesSetCapability(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreSetCapabilityResult { throw refuse("rules.setCapability") }
    func rulesAdd(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult { throw refuse("rules.add") }
    func rulesRemove(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult { throw refuse("rules.remove") }
    func rulesChangeVerdict(scope: CoreRuleScope, dir: String?, rule: String, from: CoreVerdict, to: CoreVerdict) async throws -> CoreEntryResult { throw refuse("rules.changeVerdict") }
    func rulesChangeVerdicts(scope: CoreRuleScope, dir: String?, to: CoreVerdict, rules: [CoreRuleMove]) async throws -> CoreEntryResult { throw refuse("rules.changeVerdicts") }
    func rulesCheck(rule: String) async throws -> CoreRuleCheck { throw refuse("rules.check") }
    func rulesRemoveMany(scope: CoreRuleScope, dir: String?, ids: [String]) async throws -> CoreEntryResult { throw refuse("rules.removeMany") }
    func findingsKeep(id: String) async throws -> CoreEntryResult { throw refuse("findings.keep") }
    func findingsUnkeep(id: String) async throws -> CoreEntryResult { throw refuse("findings.unkeep") }

    private static let noActivity = CoreActivityReport(sessions: [], failures: [], files: [], unmeasurable: [], stats: CoreActivityStats(logs: 0, truncated: 0))
}
