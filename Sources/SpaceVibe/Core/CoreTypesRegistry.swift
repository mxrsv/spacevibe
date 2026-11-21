import Foundation

// clis.registry and the `cliCells` of loadout.rows. Go: core/internal/cliregistry/registry.go,
// core/internal/inventory/cli-cells.go (docs/internals/core-protocol.md, "Wire types"). Additive beside the two-CLI
// `CoreCells` the v5 shell reads (plan AR1).

/// Which concepts a CLI has. False is Not supported, a different fact from Missing or Unmeasurable.
struct CoreRegistrySupports: Codable, Equatable, Hashable, Sendable {
    var skill: Bool
    var agent: Bool
    var hook: Bool
    var rule: Bool
    var logs: Bool
    var limits: Bool

    /// The registry's answer for one item kind (`skill`, `agent`, `hook` are the wire kinds).
    func supports(_ kind: CoreKind) -> Bool {
        switch kind {
        case .skill: skill
        case .agent: agent
        case .hook: hook
        }
    }
}

/// One registry entry. `id` is lowercase and stable; for the two CLIs read today it is a `CoreCLI` raw value.
struct CoreRegistryCLI: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var supports: CoreRegistrySupports
}

/// The `clis.registry` result: every CLI in the fixed order every page uses.
struct CoreRegistryResult: Codable, Equatable, Sendable {
    var clis: [CoreRegistryCLI]
}

/// One day of a counted hook cell's `last7Days` (RB-E5): the day (YYYY-MM-DD, UTC like every usage day) and the runs and
/// errors logged on it.
struct CoreHookDay: Codable, Equatable, Sendable {
    var day: String
    var runs: Int
    var errors: Int
}

/// One CLI's cell for one `loadout.rows` row, keyed by registry id in `cliCells`. A skill or subagent counts sessions and
/// days, a hook counts runs and errors (GLOSSARY: Runs are hooks only). `note` is set only on a counted zero that may be too
/// new for the logs (D63). A hook's `errors` is lifetime; `week` is its last 7 days, oldest first and ending on the core's
/// today, which RD26's failing Hook reads (`errorsLast7Days`). An empty `week` means the core sent none (a cell built by
/// hand or an older shape): it is not written back and reads as unknown, never as 0 errors.
enum CoreCLICell: Equatable, Sendable {
    case sessions(count: Int, days: [String], last: String?, note: String?)
    case runs(count: Int, errors: Int, last: String?, note: String?, week: [CoreHookDay] = [])
    /// Installed, but nothing SpaceVibe can count: never 0.
    case unmeasurable(reason: String)
    /// Installed; no usage scan has finished in this core process.
    case scanning
    case missing
    /// The CLI's folder or file for this kind could not be read: whether the item is there is not known.
    case unknown
    case notSupported
}

extension CoreCLICell: Codable {
    private enum Keys: String, CodingKey { case state, sessions, days, runs, errors, errorsLast7Days, last7Days, last, note, reason }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .state) {
        case "counted":
            let last = try c.decodeIfPresent(String.self, forKey: .last)
            let note = try c.decodeIfPresent(String.self, forKey: .note)
            if let runs = try c.decodeIfPresent(Int.self, forKey: .runs) {
                let week = try c.decodeIfPresent([CoreHookDay].self, forKey: .last7Days) ?? []
                self = .runs(count: runs, errors: try c.decode(Int.self, forKey: .errors), last: last, note: note, week: week)
            } else {
                self = .sessions(count: try c.decode(Int.self, forKey: .sessions), days: try c.decode([String].self, forKey: .days), last: last, note: note)
            }
        case "unmeasurable": self = .unmeasurable(reason: try c.decode(String.self, forKey: .reason))
        case "scanning": self = .scanning
        case "missing": self = .missing
        case "unknown": self = .unknown
        case "notSupported": self = .notSupported
        case let other: throw DecodingError.dataCorruptedError(forKey: .state, in: c, debugDescription: "unknown cli cell state \(other)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .sessions(let count, let days, let last, let note):
            try c.encode("counted", forKey: .state)
            try c.encode(count, forKey: .sessions)
            try c.encode(days, forKey: .days)
            try Self.encode(last: last, note: note, into: &c)
        case .runs(let count, let errors, let last, let note, let week):
            try c.encode("counted", forKey: .state)
            try c.encode(count, forKey: .runs)
            try c.encode(errors, forKey: .errors)
            if !week.isEmpty {
                try c.encode(week.reduce(0) { $0 + $1.errors }, forKey: .errorsLast7Days)
                try c.encode(week, forKey: .last7Days)
            }
            try Self.encode(last: last, note: note, into: &c)
        case .unmeasurable(let reason):
            try c.encode("unmeasurable", forKey: .state)
            try c.encode(reason, forKey: .reason)
        case .scanning: try c.encode("scanning", forKey: .state)
        case .missing: try c.encode("missing", forKey: .state)
        case .unknown: try c.encode("unknown", forKey: .state)
        case .notSupported: try c.encode("notSupported", forKey: .state)
        }
    }

    private static func encode(last: String?, note: String?, into c: inout KeyedEncodingContainer<Keys>) throws {
        if let last { try c.encode(last, forKey: .last) } else { try c.encodeNil(forKey: .last) }
        try c.encodeIfPresent(note, forKey: .note)
    }

    /// Sessions for a skill or subagent, runs for a hook; nil unless counted.
    var count: Int? {
        switch self {
        case .sessions(let count, _, _, _), .runs(let count, _, _, _, _): count
        default: nil
        }
    }

    /// A counted zero the core marks as possibly too new for the logs (D63): the item was added recently.
    var isRecentlyAdded: Bool {
        switch self {
        case .sessions(0, _, _, let note?), .runs(0, _, _, let note?, _): !note.isEmpty
        default: false
        }
    }

    /// A counted hook's errors in its last 7 days (RD26); nil for any other cell and when the core sent no week. The
    /// lifetime `errors` never stands in.
    var errorsLast7Days: Int? {
        if case .runs(_, _, _, _, let week) = self, !week.isEmpty { return week.reduce(0) { $0 + $1.errors } }
        return nil
    }
}

/// `cliCells`: one cell per registry id.
typealias CoreCLICells = [String: CoreCLICell]
