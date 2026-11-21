import Foundation

/// What RB-E7's `clean.scan` will report: logs by CLI and age with file counts and bytes, caches from the verified
/// allowlist (CL-R4) and the real size of each item (CL-R6). Not on the wire yet, so the store holds none and Clean shows
/// no byte figure at all rather than a made-up one (FE-D3).
struct CleanScan: Equatable, Sendable {
    struct Logs: Equatable, Sendable {
        let files: Int
        let bytes: Int64
    }

    struct Cache: Identifiable, Equatable, Sendable {
        let id: String
        let cli: String
        let path: String
        let bytes: Int64
    }

    /// Registry id → age in days (30, 90 or 180) → the logs older than that age.
    var logs: [String: [Int: Logs]] = [:]
    /// CLIs whose log folder could not be read: their logs are never offered.
    var unreadableLogs: Set<String> = []
    var caches: [Cache] = []
    /// Row key → bytes the move would free. A Hook removal edits a settings file and moves nothing, so it is 0.
    var itemBytes: [String: Int64] = [:]
}

/// Which CLIs' logs and caches Clean must not move now, from the activity report alone (RD27, RD35). The core enforces the
/// same locks on `clean.move` (RB-E7); the shell's copy only says so before the click. Every installed CLI counts, a hidden
/// one too ("Show guard"), and an answer the shell cannot get locks: no report yet, or a failed process check.
struct CleanLocks: Equatable, Sendable {
    /// A CLI with a running or waiting session: its logs are being written (RD27).
    let logs: Set<String>
    /// A CLI with any live process, idle and unmeasurable included: its caches are in use (RD35).
    let caches: Set<String>

    /// The activity code that says the process check failed, so no session state is known for that CLI.
    static let processUnknownCode = "codex-process-unknown"

    init(activity: CoreActivityReport?, registry: [CoreRegistryCLI]) {
        let all = Set(registry.map(\.id))
        guard let activity else {
            logs = all
            caches = all
            return
        }
        let unknown = Set(activity.unmeasurable.filter { $0.code == Self.processUnknownCode }.map(\.cli.rawValue))
        let writing = Set(activity.sessions.filter { $0.state == .running || $0.state == .waiting }.map(\.cli.rawValue))
        let live = Set(activity.sessions.filter { $0.state != .ended }.map(\.cli.rawValue))
        logs = writing.union(unknown)
        caches = live.union(unknown)
    }
}

/// Clean's rows and what can be cleaned. Port of the "Clean" block of the reference mock's `world`.
struct CleanPlan: Equatable, Sendable {
    struct AgentRow: Identifiable, Equatable, Sendable {
        let row: FrameRow
        /// Plugin and project items are listed but never selectable (CL-R1, "Inferred, not decided": Project items).
        let isReadOnly: Bool
        let isSuggested: Bool
        /// Nil until `clean.scan` reports the item's size.
        let bytes: Int64?
        var id: String { row.id }
    }

    struct LogRow: Identifiable, Equatable, Sendable {
        let cli: String
        let ageDays: Int
        let files: Int
        let bytes: Int64
        let isLocked: Bool
        var id: String { "logs:\(cli)" }
    }

    struct CacheRow: Identifiable, Equatable, Sendable {
        let cache: CleanScan.Cache
        let isLocked: Bool
        var id: String { cache.id }
    }

    /// The default log age (days) before the page picks another.
    static let defaultLogAge = 90

    let agentRows: [AgentRow]
    let logs: [LogRow]
    let caches: [CacheRow]
    let locks: CleanLocks
    /// Whether a scan exists: without one no byte figure is shown.
    let isMeasured: Bool

    /// `logAge` is the page's choice per CLI (view state), 90 days when it has made none.
    init(candidates: [FrameRow], kept: Set<String>, scan: CleanScan?, locks: CleanLocks, shownCLIs: [String], logAge: [String: Int] = [:]) {
        self.locks = locks
        isMeasured = scan != nil
        agentRows = candidates.map { row in
            AgentRow(row: row, isReadOnly: row.isPlugin || row.isProject, isSuggested: row.isSuggested(kept: kept),
                     bytes: row.kind == .hook ? 0 : scan?.itemBytes[row.id])
        }
        logs = shownCLIs.compactMap { cli in
            let age = logAge[cli] ?? Self.defaultLogAge
            guard let scan, !scan.unreadableLogs.contains(cli), let found = scan.logs[cli]?[age], found.files > 0 else { return nil }
            return LogRow(cli: cli, ageDays: age, files: found.files, bytes: found.bytes, isLocked: locks.logs.contains(cli))
        }
        caches = (scan?.caches ?? []).filter { shownCLIs.contains($0.cli) }.map { CacheRow(cache: $0, isLocked: locks.caches.contains($0.cli)) }
    }

    /// The ids a move may take: not locked, not read-only. A row whose size is unknown is not offered.
    var openIDs: Set<String> {
        Set(agentRows.filter { !$0.isReadOnly && $0.bytes != nil }.map(\.id) + logs.filter { !$0.isLocked }.map(\.id)
            + caches.filter { !$0.isLocked }.map(\.id))
    }

    /// The hero and the sidebar figure (RD-R2 Clean): every open row. Nil before a scan.
    var cleanableBytes: Int64? { isMeasured ? bytes(of: openIDs) : nil }

    /// The bytes of the picked rows that may move: the bar and the button. Nil before a scan.
    func selectedBytes(_ picked: Set<String>) -> Int64? { isMeasured ? bytes(of: picked.intersection(openIDs)) : nil }

    /// Bytes in use as text only: locked logs and caches (RD-R17 "Honesty").
    var lockedBytes: Int64 { logs.filter(\.isLocked).map(\.bytes).reduce(0, +) + caches.filter(\.isLocked).map(\.cache.bytes).reduce(0, +) }

    private func bytes(of ids: Set<String>) -> Int64 {
        agentRows.filter { ids.contains($0.id) }.compactMap(\.bytes).reduce(0, +)
            + logs.filter { ids.contains($0.id) }.map(\.bytes).reduce(0, +)
            + caches.filter { ids.contains($0.id) }.map(\.cache.bytes).reduce(0, +)
    }
}
