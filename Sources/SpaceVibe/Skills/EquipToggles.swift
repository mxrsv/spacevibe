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
}

/// One row's readers answers (RB-E2), computed once per row and read by its logo toggles, its tiles, the shared-file
/// confirmation and the per-CLI sheet, so the four cannot disagree. Nil `readers` is a core that sent no map for the row: every
/// answer is then unknown, and the page falls back to the engine's own refusals (FE-D3: never a guess).
struct EquipReaders: Sendable {
    let readers: ItemReaders?
    /// Every installed CLI, hidden ones included: who reads or loses a file always counts them ("Show guard").
    let registry: [CoreRegistryCLI]
    let kind: CoreKind
    let folders: [CoreReadersFolder]

    /// The installed CLIs that have the kind at all.
    var supporting: [String] { registry.filter { $0.supports.supports(kind) }.map(\.id) }

    func name(_ id: String) -> String { registry.first { $0.id == id }?.name ?? id }
    func names(_ ids: [String]) -> [String] { ids.map(name) }

    /// Every member turning `cli` off removes, with the members that share their file (`ItemReaders.turningOff`).
    func turningOff(_ cli: String) -> Set<String>? { readers?.turningOff(cli) }

    /// Every supporting CLI left with nothing of the row once `removed` is gone.
    func losers(removing removed: Set<String>) -> [String]? {
        readers.map { $0.losers(removing: $0.expand(removed), among: supporting) }
    }

    /// Every installed CLI that reads a file `removed` takes: the readers the engine names when it refuses.
    func fileReaders(removing removed: Set<String>) -> [String]? {
        readers.map { $0.fileReaders(removing: $0.expand(removed), among: registry.map(\.id)) }
    }

    /// `removed` in the readers map's order: the row's members, then those of other rows.
    func ordered(_ removed: Set<String>) -> [String] {
        guard let readers else { return removed.sorted() }
        return (readers.members + readers.elsewhere).map(\.id).filter(removed.contains)
    }

    /// A CLI SpaceVibe can copy the kind into: it owns a folder of the kind that `loadout.copyTo` writes (`copyTarget`). A core
    /// that sent no readers map leaves the engine to refuse.
    func isCopyTarget(_ cli: String) -> Bool {
        guard !folders.isEmpty else { return true }
        return folders.contains { $0.ownedBy == cli && $0.kind == kind && $0.copyTarget }
    }

    /// The losers of turning `cli` off that can keep the row with a copy in their own folder first (the mock's `savableOf`):
    /// not `cli`, none of the removed files is in their own folder, and SpaceVibe can copy into it.
    func savable(turningOff cli: String, removed: Set<String>, losers: [String]) -> [String] {
        let owners = Set((readers.map { $0.members + $0.elsewhere } ?? []).filter { removed.contains($0.id) }.map(\.folderOwner))
        return losers.filter { $0 != cli && !owners.contains($0) && isCopyTarget($0) }
    }
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

/// Builds each CLI's `CLIToggleState` for a row and the intent of pressing it.
enum EquipToggles {
    /// One state per shown CLI, in the fixed order.
    static func states(_ row: FrameRow, clis: [CoreRegistryCLI], readers: EquipReaders, noun: String) -> [CLIToggleState] {
        let lit = clis.filter { row.presence($0.id) == .on }.count
        return clis.map { state(row, cli: $0, readers: readers, noun: noun, litCount: lit) }
    }

    /// `litCount` is the shown CLIs whose logo is on: without a readers map, D53 falls back to "the only lit logo".
    static func state(_ row: FrameRow, cli: CoreRegistryCLI, readers: EquipReaders, noun: String, litCount: Int) -> CLIToggleState {
        let identity = CLIIdentity(id: cli.id, name: cli.name)
        let readOnly = readOnlyOwner(row).map(CLIToggleState.Hold.readOnly(owner:))
        let cell = row.cell(cli.id)
        if !cli.supports.supports(row.kind) || cell == .notSupported {
            return CLIToggleState(cli: identity, presence: .notSupported(noun: "\(noun)s"))
        }
        if cell == .unknown { return CLIToggleState(cli: identity, presence: .unreadable) }
        guard let usage = usage(cell) else {
            return CLIToggleState(cli: identity, presence: .off, hold: readOnly ?? .none)
        }
        let via = readers.readers?.via(cli.id)
        var hold: CLIToggleState.Hold = .none
        if let readOnly {
            hold = readOnly
        } else if let via {
            hold = .via(readers.names(via))
        } else if let readerMap = readers.readers {
            if readerMap.isLastCopy(turningOff: cli.id) { hold = .lastCopy }
        } else if litCount <= 1 {
            hold = .lastCopy
        }
        let shared = readers.turningOff(cli.id).flatMap(readers.fileReaders(removing:))?.filter { $0 != cli.id } ?? []
        return CLIToggleState(cli: identity, presence: .on(usage), hold: hold, sharedWith: readers.names(shared),
                              ownsFile: readers.readers == nil || via == nil)
    }

    /// What a lit cell says about use; nil for a cell that is not lit (missing).
    static func usage(_ cell: CoreCLICell) -> CLIToggleState.Usage? {
        switch cell {
        case .sessions(let n, _, _, _), .runs(let n, _, _, _, _): n > 0 ? .sessions(n) : .neverRan
        case .unmeasurable: .unmeasurable
        case .scanning: .pending
        case .missing, .unknown, .notSupported: nil
        }
    }

    /// "project payments-web" or "plugin" for a row SpaceVibe never writes; nil for the user's own.
    static func readOnlyOwner(_ row: FrameRow) -> String? {
        if row.isProject { return "project \(projectName(row) ?? "")" }
        return row.isPlugin ? "plugin" : nil
    }

    /// The project folder's own name ("payments-web" for `~/work/payments-web`).
    static func projectName(_ row: FrameRow) -> String? {
        row.project.map { ($0 as NSString).lastPathComponent }
    }

    /// What pressing `state` does.
    static func intent(_ state: CLIToggleState, row: FrameRow, readers: EquipReaders) -> EquipToggleIntent {
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
