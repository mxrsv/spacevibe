import Foundation

/// The Skills or Subagents page a list, inspector and sheet are for: the kind it lists and its words. One implementation serves
/// both pages (`SkillsFrame`, `SubagentsFrame`); only these values differ.
struct EquipKind: Hashable, Sendable {
    let page: FramePage
    let kind: CoreKind
    /// The singular label word: "Skill", "Subagent".
    let noun: String
    /// The folder a CLI keeps them in, for the empty state ("a CLI's skills folder").
    let folderWord: String

    var plural: String { "\(noun)s" }
    /// What the toolbar's search finds ("skills"): its placeholder and "No skills match".
    var searchItems: String { plural.lowercased() }
}

/// What one logo toggle or tile does when pressed (RD-R11, RD31, D53). Pure: the page state runs it.
enum EquipToggleIntent: Equatable, Sendable {
    /// Not a toggle (via, last copy, read-only, Not supported, unreadable, pending): nothing.
    case none
    /// Off: copy the row into the CLI's own folder (`loadout.copyTo`).
    case add(cli: String)
    /// On, its files read by this CLI only: `loadout.removeFrom`.
    case removeFrom(cli: String)
    /// On, read by this CLI only, but the file is reached from another row (a link under another name): the removal must name
    /// those members too, so it goes through `loadout.removeMany` (`ItemReaders.reachesOtherRows`).
    case removeMembers(cli: String, members: [String])
    /// On, and another CLI reads a file it would take: the anchored confirmation names every reader first.
    case confirm(EquipSharedRemoval)
}

/// A shared-file removal waiting for its confirmation (`SharedFileConfirmation`).
struct EquipSharedRemoval: Hashable, Sendable {
    let rowID: String
    let cli: String
    /// Exactly what goes, in the readers map's order: every member the CLI reads the row from and every member sharing their
    /// file, other rows' included. `loadout.removeMany` takes these and no other, so a reader whose own folder is not among
    /// them keeps the row.
    let members: [String]
    /// Every CLI that loses the row, `cli` included.
    let losers: [String]
    /// The losers that can keep it by a copy in their own folder first.
    let savable: [String]
    let wording: SharedFileConfirmation.Wording
}

/// What pressing a row's logo toggle or tile does on Skills and Subagents. The states themselves come from the one shared
/// source, `CLIToggleStates`.
enum EquipToggles {
    /// What pressing `state` does.
    static func intent(_ state: CLIToggleState, row: FrameRow, readers: RowReaders) -> EquipToggleIntent {
        guard state.isToggle else { return .none }
        let cli = state.cli.id
        guard state.isOn else { return .add(cli: cli) }
        guard let readerMap = readers.readers, let removed = readers.turningOff(cli), !removed.isEmpty else { return .removeFrom(cli: cli) }
        let others = (readers.fileReaders(removing: removed) ?? []).filter { $0 != cli }
        if others.isEmpty {
            return readerMap.reachesOtherRows(removed) ? .removeMembers(cli: cli, members: readers.ordered(removed)) : .removeFrom(cli: cli)
        }
        let losers = readers.losers(removing: removed) ?? [cli]
        let savable = readers.savable(turningOff: cli, removed: removed, losers: losers)
        let files = Self.files(row, removed: removed, readers: readerMap)
        let wording = SharedFileConfirmation.Wording(
            cli: readers.name(cli), files: files, losers: readers.names(losers), savable: readers.names(savable),
            savableShort: savable.map { CLIIdentity(id: $0, name: readers.name($0)).shortName })
        return .confirm(EquipSharedRemoval(rowID: row.id, cli: cli, members: readers.ordered(removed), losers: losers,
                                           savable: savable, wording: wording))
    }

    /// The files a removal takes, as the user knows them (`~/.agents/skills/pdf-extract`): each removed member's own path,
    /// once; a member of another row by its folder.
    static func files(_ row: FrameRow, removed: Set<String>, readers: ItemReaders) -> [String] {
        var out: [String] = []
        for member in readers.members + readers.elsewhere where removed.contains(member.id) {
            let path = row.items.first { $0.id == member.id }?.path ?? member.folder
            let shown = (path as NSString).abbreviatingWithTildeInPath
            if !out.contains(shown) { out.append(shown) }
        }
        return out
    }
}
