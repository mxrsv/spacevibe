import Foundation

/// What a removal of a Skill, Subagent or Hook row sends to the engine, outside the Skills and Subagents pages (Inbox's
/// Remove, `Remove N selected` and tiles, Clean's `Remove …`): the same logic as those pages' logos (`EquipToggles.intent`),
/// so no page sends a removal the engine is bound to refuse. Pure.
///
/// `loadout.removeMany` refuses a member whose file another member also reaches unless that member is named too ("pick
/// every copy of it", core `removeMany`); `loadout.removeFrom` refuses when a CLI it was not told about reads one of the
/// files. So a whole-row removal names every member that shares a file with the row's own, other rows' links included
/// (`ItemReaders.expand`), and a tile goes through the logo's intent.
enum RowRemoval {
    /// The member ids that removing all of `rows` passes to `loadout.removeMany`, in the readers map's order and without
    /// repeats: every member of a Skill or Subagent and a Hook's Claude Code members (D25), each expanded to every member
    /// that shares its file. A row without a readers map passes its own members; the engine then refuses what it must.
    static func members(_ rows: [FrameRow], in world: FrameWorld) -> [String] {
        var out: [String] = []
        for row in rows {
            let own = row.kind == .hook ? row.hooks.filter { $0.cli == .claude }.map(\.id) : row.memberIDs
            for id in RowReaders(row, in: world).removal(of: own) where !out.contains(id) { out.append(id) }
        }
        return out
    }

    /// What pressing `state` (a tile of `row`) does in `world`: exactly what the row's logo does on Skills or Subagents.
    static func toggle(_ state: CLIToggleState, row: FrameRow, in world: FrameWorld) -> EquipToggleIntent {
        EquipToggles.intent(state, row: row, readers: RowReaders(row, in: world))
    }
}

extension RowReaders {
    /// `chosen` with every member that shares a file with it, in the readers map's order; `chosen` as given without a map.
    func removal(of chosen: [String]) -> [String] {
        guard let readers else { return chosen }
        return ordered(readers.expand(Set(chosen)))
    }
}
