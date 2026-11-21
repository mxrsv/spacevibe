import Foundation

/// `CoreService` over the Go core: JSON-RPC 2.0 on the stdio of a child process (plan S.2; docs/internals/core-protocol.md).
/// The process, the handshake and the restart policy are `CoreConnection`'s; this type maps each service method to its RPC
/// method and parameters.
///
/// The process starts on the first call, not in `init`, so a process that never routes a screen here never spawns it.
/// Releasing the client closes the core's stdin, which makes the core finish its in-flight write and exit.
final class CoreClient: CoreService, @unchecked Sendable {
    let connection: CoreConnection

    /// - Parameters:
    ///   - binary: the helper. The app passes `CoreEnvironment.binaryURL()`.
    ///   - environment: the core's environment; nil inherits ours, which is what the app does. A test passes its fixture home.
    ///   - handshakeTimeout: how long a started core may take to answer `initialize` before it is ended and the start fails.
    init(binary: URL = CoreEnvironment.binaryURL(), environment: [String: String]? = nil, bundle: Bundle = .main, handshakeTimeout: Duration = .seconds(10)) {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        connection = CoreConnection(binary: binary, environment: environment, clientVersion: version, handshakeTimeout: handshakeTimeout)
    }

    deinit { connection.shutdown() }

    /// Stops the core now instead of at deinit.
    func shutdown() { connection.shutdown() }

    // MARK: Params

    private struct ID: Encodable { let id: String }
    private struct CLI: Encodable { let cli: CoreCLI }
    private struct Stop: Encodable { let cli: CoreCLI, id: String }
    private struct Check: Encodable { let rule: String }
    private struct CopyTo: Encodable { let id: String, targets: [String] }
    private struct RemoveFrom: Encodable { let id: String, clis: [String] }
    private struct IDs: Encodable { let ids: [String] }
    private struct CleanMove: Encodable { let logs: [CoreCleanLogPick], caches: [String] }

    /// The members of every `rules.*` call; a member a call does not take stays nil and is left out (params are strict).
    /// `dir` is `null` for the global scope.
    private struct Rules: Encodable {
        let scope: CoreRuleScope
        @CoreNullable var dir: String?
        var refreshProjects: Bool?
        var capability: CoreCapability?
        var verdict: CoreVerdict?
        var rule: String?
        var from: CoreVerdict?
        var to: CoreVerdict?
        var rules: [CoreRuleMove]?
        var ids: [String]?

        init(_ scope: CoreRuleScope, _ dir: String?) {
            self.scope = scope
            self.dir = dir
        }
    }

    // MARK: Handshake

    func initialize() async throws -> CoreInitializeResult { try await connection.handshake() }

    func clisRegistry() async throws -> CoreRegistryResult { try await connection.call("clis.registry") }

    // MARK: Inventory, usage, loadout

    func inventoryRead() async throws -> CoreInventorySnapshot { try await connection.call("inventory.read") }

    func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        try await connection.call("usage.scan", progress: progress)
    }

    func loadoutRows() async throws -> CoreLoadoutRows { try await connection.call("loadout.rows") }

    // MARK: Activity

    func activityRead() async throws -> CoreActivityReport { try await connection.call("activity.read") }

    func activitySubscribe() -> AsyncThrowingStream<CoreActivityReport, Error> {
        AsyncThrowingStream { continuation in
            let sink = CoreActivitySink(continuation)
            let connection = connection
            let token = connection.addSink(sink)
            // Subscribe, wait for the core to die, subscribe again: each round starts with a fresh full snapshot (resync).
            let task = Task {
                do {
                    while !Task.isCancelled {
                        let session = try await connection.subscribe(sink)
                        await session.waitUntilDead()
                    }
                    sink.finish()
                } catch is CancellationError {
                    sink.finish()
                } catch {
                    sink.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                connection.removeSink(token)
            }
        }
    }

    func activityStop(cli: CoreCLI, id: String) async throws -> CoreStopResult {
        try await connection.call("activity.stop", Stop(cli: cli, id: id))
    }

    // MARK: Loadout writes and the journal

    func loadoutCopyToOther(id: String) async throws -> CoreEntryResult { try await connection.call("loadout.copyToOther", ID(id: id)) }
    func loadoutRemoveItem(id: String) async throws -> CoreEntryResult { try await connection.call("loadout.removeItem", ID(id: id)) }
    func loadoutRemoveDeadHooks(cli: CoreCLI) async throws -> CoreEntryResult { try await connection.call("loadout.removeDeadHooks", CLI(cli: cli)) }

    func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult {
        try await connection.call("loadout.copyTo", CopyTo(id: id, targets: targets))
    }
    func loadoutRemoveFrom(id: String, clis: [String]) async throws -> CoreRemoveFromResult {
        try await connection.call("loadout.removeFrom", RemoveFrom(id: id, clis: clis))
    }
    func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult { try await connection.call("loadout.removeMany", IDs(ids: ids)) }

    func journalUndo(id: String) async throws -> CoreUndoResult { try await connection.call("journal.undo", ID(id: id)) }
    func journalHistory() async throws -> CoreJournalHistory { try await connection.call("journal.history") }

    // MARK: Rules

    func rulesSnapshot(scope: CoreRuleScope, dir: String?, refreshProjects: Bool) async throws -> CoreRulesSnapshot {
        var params = Rules(scope, dir)
        params.refreshProjects = refreshProjects
        return try await connection.call("rules.snapshot", params)
    }

    func rulesPreview(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreCapabilityPreview {
        var params = Rules(scope, dir)
        params.capability = capability
        params.verdict = verdict
        return try await connection.call("rules.preview", params)
    }

    func rulesSetCapability(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreSetCapabilityResult {
        var params = Rules(scope, dir)
        params.capability = capability
        params.verdict = verdict
        return try await connection.call("rules.setCapability", params)
    }

    func rulesAdd(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult {
        var params = Rules(scope, dir)
        params.verdict = verdict
        params.rule = rule
        return try await connection.call("rules.add", params)
    }

    func rulesRemove(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult {
        var params = Rules(scope, dir)
        params.verdict = verdict
        params.rule = rule
        return try await connection.call("rules.remove", params)
    }

    func rulesChangeVerdict(scope: CoreRuleScope, dir: String?, rule: String, from: CoreVerdict, to: CoreVerdict) async throws -> CoreEntryResult {
        var params = Rules(scope, dir)
        params.rule = rule
        params.from = from
        params.to = to
        return try await connection.call("rules.changeVerdict", params)
    }

    func rulesChangeVerdicts(scope: CoreRuleScope, dir: String?, to: CoreVerdict, rules: [CoreRuleMove]) async throws -> CoreEntryResult {
        var params = Rules(scope, dir)
        params.to = to
        params.rules = rules
        return try await connection.call("rules.changeVerdicts", params)
    }

    func rulesCheck(rule: String) async throws -> CoreRuleCheck { try await connection.call("rules.check", Check(rule: rule)) }

    func rulesRemoveMany(scope: CoreRuleScope, dir: String?, ids: [String]) async throws -> CoreEntryResult {
        var params = Rules(scope, dir)
        params.ids = ids
        return try await connection.call("rules.removeMany", params)
    }

    // MARK: Limits

    func limitsRead() async throws -> CoreLimitsResult { try await connection.call("limits.read") }

    // MARK: Keep list

    func findingsKept() async throws -> CoreKeptFindings { try await connection.call("findings.kept") }
    func findingsKeep(id: String) async throws -> CoreEntryResult { try await connection.call("findings.keep", ID(id: id)) }
    func findingsUnkeep(id: String) async throws -> CoreEntryResult { try await connection.call("findings.unkeep", ID(id: id)) }

    // MARK: Clean

    func cleanScan() async throws -> CoreCleanScan { try await connection.call("clean.scan") }

    func cleanMove(logs: [CoreCleanLogPick], caches: [String], progress: (@Sendable (CoreCleanProgress) -> Void)?) async throws -> CoreCleanMoveResult {
        try await connection.call("clean.move", CleanMove(logs: logs, caches: caches), cleanProgress: progress)
    }
}
