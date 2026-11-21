import Foundation

// Results of the per-CLI and batch writes the new frame calls (RB-E3, RB-E4), beside the v5 `CoreEntryResult`
// (docs/internals/core-protocol.md, plan AR1). Each id list holds registry ids in registry order and is never null.
// `rules.removeMany` answers a plain `CoreEntryResult`.

/// The result of `loadout.copyTo`: `alsoReaders` read a folder the copy went into, so they have the item too.
struct CoreCopyToResult: Codable, Equatable, Sendable {
    var entry: CoreJournalEntry
    var alsoReaders: [String]
}

/// The result of `loadout.removeFrom`: who no longer has the item, and who still reads it from a file that stayed.
struct CoreRemoveFromResult: Codable, Equatable, Sendable {
    var entry: CoreJournalEntry
    var lost: [String]
    var stillHave: [String]
}

/// The result of `loadout.removeMany`: every CLI that lost at least one item or hook.
struct CoreRemoveManyResult: Codable, Equatable, Sendable {
    var entry: CoreJournalEntry
    var lost: [String]
}
