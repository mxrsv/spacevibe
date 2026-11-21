import Foundation

/// The CLI tiles of a Skill or Subagent in the Inbox inspector (RD-R11, RD-R12, D53, RD31; the mock's `tileInspector`): one
/// `CLIToggleState` per shown registry CLI, from the row's cells and the readers map. Pure.
///
/// Built here because RB-R2 (Skills and Subagents) has not landed: when it does, its row toggles and this grid should read one
/// factory, so the row's logo and the tile cannot disagree (RD-R12).
enum ItemTileStates {
    static func states(of row: FrameRow, in world: FrameWorld) -> [CLIToggleState] {
        let readers = world.readers(of: row)
        let noun = row.kind == .agent ? "Subagents" : "Skills"
        let owner: String? = row.isProject ? "project \(row.project.map { ($0 as NSString).lastPathComponent } ?? "")"
            : row.isPlugin ? "plugin" : nil
        return world.clis.map { cli in
            let identity = CLIIdentity(id: cli.id, name: cli.name)
            guard cli.supports.supports(row.kind) else { return CLIToggleState(cli: identity, presence: .notSupported(noun: noun)) }
            let presence = presence(row.cell(cli.id), noun: noun)
            var hold: CLIToggleState.Hold = owner.map { .readOnly(owner: $0) } ?? .none
            var shared: [String] = []
            var owns = true
            if case .on = presence, let readers {
                let via = readers.via(cli.id)
                owns = via == nil
                if hold == .none {
                    if let via { hold = .via(via.map(world.cliName)) } else if readers.isLastCopy(turningOff: cli.id) { hold = .lastCopy }
                }
                let files = readers.members(readBy: cli.id)
                shared = readers.members.filter { files.contains($0.id) }.flatMap(\.readBy)
                    .reduce(into: [String]()) { out, id in if id != cli.id, !out.contains(id) { out.append(id) } }
                    .map(world.cliName)
            }
            return CLIToggleState(cli: identity, presence: presence, hold: hold, sharedWith: shared, ownsFile: owns)
        }
    }

    static func presence(_ cell: CoreCLICell, noun: String) -> CLIToggleState.Presence {
        switch cell {
        case .sessions(let count, _, _, _), .runs(let count, _, _, _, _): .on(count > 0 ? .sessions(count) : .neverRan)
        case .unmeasurable: .on(.unmeasurable)
        case .scanning: .on(.pending)
        case .missing: .off
        case .unknown: .unreadable
        case .notSupported: .notSupported(noun: noun)
        }
    }
}

extension FrameWorld {
    /// The registry's name for a CLI id; an id it does not list shows as itself.
    func cliName(_ cli: String) -> String { snapshot.registry.first { $0.id == cli }?.name ?? cli }
}
