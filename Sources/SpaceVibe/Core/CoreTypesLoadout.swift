import Foundation

// loadout.rows and the writes that return a journal entry. Go: core/internal/inventory/loadout-rows.go,
// core/internal/mutate/{service,ops}.go.

/// Counts for the filter chips, deduplicated by row key.
struct CoreFilterCounts: Codable, Equatable, Sendable {
    struct Only: Codable, Equatable, Sendable {
        var claude: Int
        var codex: Int
    }

    var all: Int
    var only: Only
    var neverRan: Int
    var dead: Int
}

/// The chips one matrix row sets: each is the filter count over the row's members, above zero.
struct CoreRowFlags: Codable, Equatable, Sendable {
    var one: Bool
    var neverRan: Bool
    var dead: Bool
}

/// `loadout.rows`: one inventory read with usage attached. Grouping rows by `key`, sorting and labels stay in Swift.
/// `problems` are the raw sentences with absolute paths; the shell shortens the home folder before showing them.
struct CoreLoadoutRows: Codable, Equatable, Sendable {
    enum UsageState: String, Codable, Sendable {
        case scanning, ready
    }

    var usage: UsageState
    var items: [CoreInventoryItem]
    var hooks: [CoreInventoryHook]
    var problems: [String]
    var events: [String: [String]]
    var roots: [String: String]
    /// Keyed `global` or an absolute project folder.
    var countsByScope: [String: CoreFilterCounts]
    /// Keyed by row key.
    var rowFlags: [String: CoreRowFlags]
    /// The readers map, sorted by path: every folder a row lives in, each installed CLI's own folders and the shared
    /// `~/.agents/skills` (inventory.md "Readers map"). The v5 shell does not read it.
    var folders: [CoreReadersFolder] = []
    /// Members every v5 field above leaves out until RB-X1: the Codex skills of `~/.agents/skills` (ids
    /// `codex:skill:agents:<entry>`, not removable, `cliCells` but no `cells`). The new frame reads them with `items`.
    var extraItems: [CoreInventoryItem] = []
    /// The problem lines about `~/.agents/skills`, left out of `problems`.
    var extraProblems: [String] = []
}

/// One entry of the readers map: a skills or agents folder, or for Hooks the file that holds them.
struct CoreReadersFolder: Codable, Equatable, Hashable, Sendable {
    /// The reader's spelling; a member's `folder` repeats it exactly.
    var path: String
    /// The path with every link followed: folders with one `realPath` are one folder, and their readers add up.
    var realPath: String
    var kind: CoreKind
    /// Registry ids, registry order, never empty.
    var readBy: [String]
    /// The CLI whose folder it is: a CLI that reads a row only from others' folders reads it "via" them (RD31).
    var ownedBy: String
    /// `loadout.copyToOther` writes into `ownedBy` here; false for `~/.agents/skills`, plugin and project folders.
    var copyTarget: Bool
}

/// What a write returns for the entry it recorded. The ops hold absolute paths and trash names, so only their count
/// leaves the core.
struct CoreJournalEntry: Codable, Equatable, Sendable, Identifiable {
    var id: String
    /// ISO 8601 UTC with milliseconds.
    var at: String
    var label: String
    var undone: Bool
    var count: Int
}

/// The result of `loadout.copyToOther`, `loadout.removeItem`, `loadout.removeDeadHooks`, `rules.add`, `rules.remove`
/// and `rules.changeVerdict`.
struct CoreEntryResult: Codable, Equatable, Sendable {
    var entry: CoreJournalEntry
}

struct CoreUndoResult: Codable, Equatable, Sendable {
    var label: String
}

/// Newest first, at most 200 entries.
struct CoreJournalHistory: Codable, Equatable, Sendable {
    var entries: [CoreJournalEntry]
}
