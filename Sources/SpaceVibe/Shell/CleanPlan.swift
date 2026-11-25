import Foundation

/// What holds one CLI's logs or caches back, and the sentence the disabled control says it with (CL-R5).
struct CleanLock: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        /// Sessions of the CLI: running or waiting for logs (RD27), any but ended for caches (RD35).
        case sessions
        /// A process of the CLI with no Activity row (a Codex `app-server`), caches only (RD35).
        case processes
        /// The process check failed, so whether the CLI runs is not known: the lock fails closed. A reason the shell does not
        /// know reads as this too.
        case processUnknown
    }

    let reason: Reason
    /// Activity session ids, so the lock popover can name them; empty for the other reasons.
    let sessionIDs: [String]
    let message: String

    init(reason: Reason, sessionIDs: [String] = [], message: String) {
        self.reason = reason
        self.sessionIDs = sessionIDs
        self.message = message
    }

    init(_ wire: CoreCleanLock) {
        let reason: Reason = switch wire.reason {
        case "sessions": .sessions
        case "processes": .processes
        default: .processUnknown
        }
        self.init(reason: reason, sessionIDs: wire.sessions, message: wire.message)
    }
}

/// Which CLIs' logs and caches Clean must not move now (RD27, RD35, CL-R5). The core decides: `clean.scan` reports each
/// lock with its sentence, and `clean.move` checks again whatever the shell sends. The scan is read on demand, so a session
/// that starts after it is added from the live Activity report in the core's own words; a lock is never dropped before the
/// next scan (fail closed). Every installed CLI counts, a hidden one too ("Show guard").
struct CleanLocks: Equatable, Sendable {
    let logs: [String: CleanLock]
    let caches: [String: CleanLock]

    /// The Activity code that says the process check failed, so no session state is known for that CLI.
    static let processUnknownCode = "codex-process-unknown"

    init(logs: [String: CleanLock] = [:], caches: [String: CleanLock] = [:]) {
        self.logs = logs
        self.caches = caches
    }

    init(scan: CoreCleanScan?, activity: CoreActivityReport?, registry: [CoreRegistryCLI]) {
        var logs: [String: CleanLock] = [:]
        var caches: [String: CleanLock] = [:]
        for cli in scan?.clis ?? [] {
            logs[cli.cli] = cli.locks.logs.map(CleanLock.init)
            caches[cli.cli] = cli.locks.caches.map(CleanLock.init)
        }
        if let activity {
            let name = { (id: String) in registry.first { $0.id == id }?.name ?? id }
            let unknown = Set(activity.unmeasurable.filter { $0.code == Self.processUnknownCode }.map(\.cli.rawValue))
            for cli in Set(activity.sessions.map(\.cli.rawValue)).union(unknown) {
                if unknown.contains(cli) {
                    let lock = Self.unknown(name(cli))
                    if logs[cli] == nil { logs[cli] = lock }
                    if caches[cli] == nil { caches[cli] = lock }
                    continue
                }
                let writing = activity.sessions.filter { $0.cli.rawValue == cli && ($0.state == .running || $0.state == .waiting) }
                let live = activity.sessions.filter { $0.cli.rawValue == cli && $0.state != .ended }
                if logs[cli] == nil, !writing.isEmpty { logs[cli] = Self.logsHeld(name(cli), by: writing.map(\.id)) }
                if caches[cli] == nil, !live.isEmpty { caches[cli] = Self.cachesHeld(name(cli), by: live.map(\.id)) }
            }
        }
        self.logs = logs
        self.caches = caches
    }

    // The core's sentences (core/internal/clean/locks.go), for a lock the live report adds after the scan.

    static func logsHeld(_ name: String, by sessions: [String]) -> CleanLock {
        let one = sessions.count == 1
        let count = one ? "1 running session" : "\(NumberWording.count(sessions.count)) running sessions"
        return CleanLock(reason: .sessions, sessionIDs: sessions,
                         message: "\(name) has \(count), so its logs stay until \(one ? "it ends" : "they end").")
    }

    static func cachesHeld(_ name: String, by sessions: [String]) -> CleanLock {
        let count = sessions.count == 1 ? "1 open session" : "\(NumberWording.count(sessions.count)) open sessions"
        return CleanLock(reason: .sessions, sessionIDs: sessions, message: "\(name) has \(count), so its caches are in use.")
    }

    static func unknown(_ name: String) -> CleanLock {
        CleanLock(reason: .processUnknown,
                  message: "The process check failed just now, so SpaceVibe cannot tell whether \(name) is running. Try again in a moment.")
    }
}

/// Clean's rows and what can be cleaned, from `clean.scan` and the Never ran / Dead set. Port of the "Clean" block of the
/// reference mock's `world` (`src/m-model.js`). Pure.
struct CleanPlan: Equatable, Sendable {
    /// Why an equipment row is listed but never selectable (CL-R1).
    enum ReadOnly: Equatable, Sendable {
        case plugin(String)
        case project(String)
        /// SpaceVibe writes Hooks only into Claude Code (D25).
        case hookNotWritten
    }

    struct AgentRow: Identifiable, Equatable, Sendable {
        let row: FrameRow
        let readOnly: ReadOnly?
        let isSuggested: Bool
        /// The allocated bytes its removal frees (`clean.scan` `items`); a Hook removal edits a settings file and moves
        /// nothing, so it is 0. Nil when the scan has no size for it: such a row is not offered.
        let bytes: Int64?
        var id: String { row.id }
        var isReadOnly: Bool { readOnly != nil }
    }

    struct LogRow: Identifiable, Equatable, Sendable {
        let cli: String
        /// The ages that hold a log (a bucket holds every older age too), ascending; the age control offers these.
        let ages: [Int]
        let ageDays: Int
        let files: Int
        let bytes: Int64
        let lock: CleanLock?
        /// The logs folder exists but cannot be listed: Unmeasurable, never offered.
        let isUnreadable: Bool
        var id: String { Self.id(cli) }
        var isLocked: Bool { lock != nil }

        /// The group id `clean.move` answers with.
        static func id(_ cli: String) -> String { "logs:\(cli)" }
    }

    struct CacheRow: Identifiable, Equatable, Sendable {
        let cli: String
        let cache: CoreCleanCache
        let lock: CleanLock?
        var id: String { cache.id }
        var isLocked: Bool { lock != nil }
    }

    /// The age (days) a log row shows before the page picks another.
    static let defaultLogAge = 90
    /// The ages `clean.scan` counts logs into (clean.md "What moves where"): what a log row's age control offers while the
    /// first scan still counts.
    static let logAges = [30, 90, 180]

    let agentRows: [AgentRow]
    let logs: [LogRow]
    let caches: [CacheRow]
    let locks: CleanLocks
    /// Whether a scan exists: without one no byte figure is shown.
    let isMeasured: Bool
    /// Shown CLIs the scan does not cover (no verified log or cache path, RD42): named once, never offered.
    let notOffered: [String]

    /// `logAge` is the page's choice per CLI (view state); an age that holds no log falls back to 90 days, then to the
    /// youngest age that has one.
    init(candidates: [FrameRow], kept: Set<String>, scan: CoreCleanScan?, locks: CleanLocks, shownCLIs: [String],
         logAge: [String: Int] = [:]) {
        self.locks = locks
        isMeasured = scan != nil
        let sizes = Dictionary((scan?.items ?? []).map { ($0.key, $0.bytes) }, uniquingKeysWith: { first, _ in first })
        agentRows = candidates.map { row in
            AgentRow(row: row, readOnly: Self.readOnly(row), isSuggested: row.isSuggested(kept: kept),
                     bytes: row.kind == .hook ? 0 : scan == nil ? nil : sizes[row.id])
        }
        let scanned = (scan?.clis ?? []).filter { shownCLIs.contains($0.cli) }
        logs = scanned.compactMap { cli in
            if cli.logs.state == "unreadable" {
                return LogRow(cli: cli.cli, ages: [], ageDays: logAge[cli.cli] ?? Self.defaultLogAge, files: 0, bytes: 0,
                              lock: locks.logs[cli.cli], isUnreadable: true)
            }
            // RD-R17 Honesty: empty log rows are not offered.
            let buckets = cli.logs.buckets.filter { $0.files > 0 }.sorted { $0.olderThanDays < $1.olderThanDays }
            guard !buckets.isEmpty else { return nil }
            let ages = buckets.map(\.olderThanDays)
            let wanted = logAge[cli.cli] ?? Self.defaultLogAge
            let age = ages.contains(wanted) ? wanted : ages.contains(Self.defaultLogAge) ? Self.defaultLogAge : ages[0]
            let bucket = buckets.first { $0.olderThanDays == age }!
            return LogRow(cli: cli.cli, ages: ages, ageDays: age, files: bucket.files, bytes: bucket.bytes, lock: locks.logs[cli.cli],
                          isUnreadable: false)
        }
        caches = scanned.flatMap { cli in
            cli.caches.filter { $0.bytes > 0 || $0.entries > 0 }.map { CacheRow(cli: cli.cli, cache: $0, lock: locks.caches[cli.cli]) }
        }
        let covered = Set((scan?.clis ?? []).map(\.cli))
        notOffered = scan == nil ? [] : shownCLIs.filter { !covered.contains($0) }
    }

    static func readOnly(_ row: FrameRow) -> ReadOnly? {
        if row.isProject { return .project(row.project.map { ($0 as NSString).lastPathComponent } ?? "") }
        if row.isPlugin {
            let owner = (row.items.map(\.owner) + row.hooks.map(\.owner)).first { FrameRow.isPluginOwner($0) } ?? ""
            return .plugin(owner)
        }
        if row.isHookSpaceVibeDoesNotWrite { return .hookNotWritten }
        return nil
    }

    /// The ids a move may take: not locked, not read-only, not unreadable. A row whose size is unknown is not offered.
    var openIDs: Set<String> {
        Set(agentRows.filter { !$0.isReadOnly && $0.bytes != nil }.map(\.id)
            + logs.filter { !$0.isLocked && !$0.isUnreadable }.map(\.id)
            + caches.filter { !$0.isLocked }.map(\.id))
    }

    /// Nothing at all is listed: the page is Tidy.
    var isEmpty: Bool { agentRows.isEmpty && logs.isEmpty && caches.isEmpty }

    /// The hero and the sidebar figure (RD-R2 Clean): every open row. Nil before a scan.
    var cleanableBytes: Int64? { isMeasured ? bytes(of: openIDs) : nil }

    /// The bytes of the picked rows that may move: the bar and the button. Nil before a scan.
    func selectedBytes(_ picked: Set<String>) -> Int64? { isMeasured ? bytes(of: picked.intersection(openIDs)) : nil }

    /// Bytes in use as text only: locked logs and caches (RD-R17 "Honesty").
    var lockedBytes: Int64 {
        logs.filter { $0.isLocked && !$0.isUnreadable }.map(\.bytes).reduce(0, +) + caches.filter(\.isLocked).map(\.cache.bytes).reduce(0, +)
    }

    /// The suggested open rows of a section, what its `Select N Suggested` ticks: suggested equipment, and every open log
    /// and cache row (the mock's `sugOf`).
    var suggestedAgents: [String] { agentRows.filter { $0.isSuggested && openIDs.contains($0.id) }.map(\.id) }
    var suggestedLogs: [String] { logs.map(\.id).filter(openIDs.contains) }
    var suggestedCaches: [String] { caches.map(\.id).filter(openIDs.contains) }

    private func bytes(of ids: Set<String>) -> Int64 {
        agentRows.filter { ids.contains($0.id) }.compactMap(\.bytes).reduce(0, +)
            + logs.filter { ids.contains($0.id) }.map(\.bytes).reduce(0, +)
            + caches.filter { ids.contains($0.id) }.map(\.cache.bytes).reduce(0, +)
    }
}
