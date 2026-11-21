import Foundation

/// One row's readers answers (RB-E2), computed once per row and read by its logo toggles, its tiles, the shared-file
/// confirmation and the per-CLI sheet, on Skills, Subagents and the Inbox inspector alike, so none can disagree. Nil `readers`
/// is a core that sent no map for the row: every answer is then unknown, and the page falls back to the engine's own refusals
/// (FE-D3: never a guess).
struct RowReaders: Sendable {
    let readers: ItemReaders?
    /// Every installed CLI, hidden ones included: who reads or loses a file always counts them ("Show guard").
    let registry: [CoreRegistryCLI]
    let kind: CoreKind
    let folders: [CoreReadersFolder]

    /// The row's answers in `world`.
    init(_ row: FrameRow, in world: FrameWorld) {
        self.init(readers: world.readers(of: row), registry: world.snapshot.registry, kind: row.kind,
                  folders: world.snapshot.loadout?.folders ?? [])
    }

    init(readers: ItemReaders?, registry: [CoreRegistryCLI], kind: CoreKind, folders: [CoreReadersFolder]) {
        self.readers = readers
        self.registry = registry
        self.kind = kind
        self.folders = folders
    }

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

/// Each shown CLI's `CLIToggleState` for a Skill or Subagent row: the one source the row's logo toggles (Skills, Subagents)
/// and the inspector's tiles (those pages and Inbox) read, so a logo and its tile never disagree (RD-R11, RD-R12, D53, RD31).
/// Pure. Its rules: a CLI that reads the row through another CLI's folder is "via"; turning off the CLI that holds the last
/// file is not a toggle (D53), and without a readers map that is the only lit logo; the CLIs a removal would also take the
/// file from include those that reach it through a link to the same file (`fileReaders`).
enum CLIToggleStates {
    /// One state per CLI of `world` (the shown ones, in the fixed order).
    static func states(of row: FrameRow, in world: FrameWorld) -> [CLIToggleState] {
        states(row, clis: world.clis, readers: RowReaders(row, in: world), noun: row.kind == .agent ? "Subagent" : "Skill")
    }

    /// One state per CLI of `clis`, in their order. `noun` is the singular kind word ("Skill").
    static func states(_ row: FrameRow, clis: [CoreRegistryCLI], readers: RowReaders, noun: String) -> [CLIToggleState] {
        let lit = clis.filter { row.presence($0.id) == .on }.count
        return clis.map { state(row, cli: $0, readers: readers, noun: noun, litCount: lit) }
    }

    /// `litCount` is the shown CLIs whose logo is on: without a readers map, D53 falls back to "the only lit logo".
    static func state(_ row: FrameRow, cli: CoreRegistryCLI, readers: RowReaders, noun: String, litCount: Int) -> CLIToggleState {
        let identity = CLIIdentity(id: cli.id, name: cli.name)
        let readOnly = readOnlyOwner(row).map(CLIToggleState.Hold.readOnly(owner:))
        let cell = row.cell(cli.id)
        if !cli.supports.supports(row.kind) || cell == .notSupported {
            return CLIToggleState(cli: identity, presence: .notSupported(noun: "\(noun)s"))
        }
        if cell == .unknown { return CLIToggleState(cli: identity, presence: .unreadable) }
        guard let usage = usage(cell) else {
            // An off logo adds into the CLI's own folder; a CLI with none of the kind (Codex's skills only in
            // `~/.agents/skills`) would get a 409, so it is not offered.
            let folder = row.kind == .agent ? "agents" : "skills"
            let nowhere = readers.isCopyTarget(cli.id) ? nil : CLIToggleState.Hold.noCopyTarget(folder: folder)
            return CLIToggleState(cli: identity, presence: .off, hold: readOnly ?? nowhere ?? .none)
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
}

extension FrameWorld {
    /// The registry's name for a CLI id; an id it does not list shows as itself.
    func cliName(_ cli: String) -> String { snapshot.registry.first { $0.id == cli }?.name ?? cli }
}
