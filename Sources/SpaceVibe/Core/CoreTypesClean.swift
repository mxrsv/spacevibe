import Foundation

// clean.scan, clean.move and clean/progress (RB-E7). Go: core/internal/clean/types.go (docs/internals/core-protocol.md,
// "Wire types"; docs/internals/clean.md). Every `bytes` is allocated bytes, what `du` counts (CL-R6). Decoders only for
// now: the Clean page (RB-R5) maps them onto `CleanScan`.

/// The logs of one CLI older than an age (30, 90 or 180 days); a bucket holds every older age too.
struct CoreCleanBucket: Codable, Equatable, Sendable {
    var olderThanDays: Int
    var files: Int
    var bytes: Int64
}

/// One CLI's session logs: `measured`, `missing` (no logs folder) or `unreadable`. Only buckets with a log are listed.
struct CoreCleanLogs: Codable, Equatable, Sendable {
    var state: String
    var buckets: [CoreCleanBucket]
}

/// One allowlisted cache folder with something in it; a move takes its `entries`, the folder stays.
struct CoreCleanCache: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var path: String
    var entries: Int
    var files: Int
    var bytes: Int64
}

/// What holds a CLI's logs or caches back: `sessions` (their Activity ids) or `processUnknown`, with the sentence.
struct CoreCleanLock: Codable, Equatable, Sendable {
    var reason: String
    var sessions: [String]
    var message: String
}

/// Null means not locked.
struct CoreCleanLocks: Codable, Equatable, Sendable {
    @CoreNullable var logs: CoreCleanLock?
    @CoreNullable var caches: CoreCleanLock?
}

/// What one CLI leaves behind.
struct CoreCleanCLI: Codable, Equatable, Sendable {
    var cli: String
    var logs: CoreCleanLogs
    var caches: [CoreCleanCache]
    var locks: CoreCleanLocks
}

/// The bytes a removal of a `loadout.rows` row's removable Skill and Subagent members frees, by row key.
struct CoreCleanItemSize: Codable, Equatable, Sendable {
    var key: String
    var bytes: Int64
}

/// The `clean.scan` result.
struct CoreCleanScan: Codable, Equatable, Sendable {
    var clis: [CoreCleanCLI]
    var items: [CoreCleanItemSize]
    /// Fixed sentences about what Clean left alone, such as an interrupted move whose list is refused. Omitted when empty.
    var problems: [String]? = nil
}

/// Files (or cache entries) and their allocated bytes.
struct CoreCleanAmount: Codable, Equatable, Sendable {
    var files: Int
    var bytes: Int64
}

/// One picked row of a move (`logs:<cli>` or a cache id): what moved, how many paths stayed and why.
struct CoreCleanGroup: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var moved: CoreCleanAmount
    var stayed: Int
    @CoreNullable var reason: String?
}

/// The `clean.move` result: what actually left the CLI folders, per row, and the folder it went to in the Trash.
struct CoreCleanMoveResult: Codable, Equatable, Sendable {
    @CoreNullable var entry: CoreJournalEntry?
    var moved: CoreCleanAmount
    var groups: [CoreCleanGroup]
    var cancelled: Bool
    @CoreNullable var trash: String?
}

/// The `clean/progress` params without the request id: `reading` archives the usage of the logs, `moving` renames.
struct CoreCleanProgress: Codable, Equatable, Sendable {
    var phase: String
    var done: Int
    var total: Int
    var bytes: Int64
}
