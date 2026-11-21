import Foundation

/// What the logs say about one row, judged over measured CLIs only (RD-R10): an unknown or unmeasurable cell can never
/// make an item Never ran. Port of the reference mock's `itemStatus` (`src/m-model.js`).
enum ItemStatus: Equatable, Sendable {
    /// At least one CLI counted a use.
    case ran
    /// Every counted cell is zero, none is unknown.
    case neverRan
    /// A Hook whose scripts are all gone (checked before any count).
    case dead
    /// No usage scan has finished in this core yet, and nothing counted.
    case pending
    /// Some CLI's folder could not be read and nothing counted: the answer is not known.
    case unknown
    /// Installed only where nothing can be counted.
    case unmeasurable
}

/// Whether a CLI has the row's item, as a logo toggle shows it (RD-R11). `on` is any installed cell: counted, unmeasurable
/// or still scanning.
enum CellPresence: Equatable, Sendable {
    case on, off, unknown, notSupported
}

/// One row of Skills, Subagents or Hooks: every member of one `loadout.rows` row key, whichever CLI holds it. The cells are
/// the core's `cliCells`, the same on every member of the key (inventory.md "CLI cells").
struct FrameRow: Identifiable, Equatable, Sendable {
    /// The row key: `<kind>:<project or empty>:<bare name>`, or `hook:<project or empty>:<hash>`.
    let id: String
    let kind: CoreKind
    /// The item's name, or for a Hook the script it runs (`HookLabel`, RD-R17).
    let name: String
    let items: [CoreInventoryItem]
    let hooks: [CoreInventoryHook]
    let cells: CoreCLICells

    var project: String? { items.first?.project ?? hooks.first?.project }
    /// Skills, Subagents and Hooks under `<project>/.claude`: listed, read-only, never an Inbox finding ("Inferred, not
    /// decided": Project items).
    var isProject: Bool { (items.first?.scope ?? hooks.first?.scope) == .project }
    /// A member is owned by a plugin. One plugin-owned member is enough: the row is never suggested for removal.
    var isPlugin: Bool { items.contains { Self.isPluginOwner($0.owner) } || hooks.contains { Self.isPluginOwner($0.owner) } }
    /// Every script the Hook names is gone.
    var isDead: Bool { hooks.contains(where: \.dead) }
    /// A counted zero the core marks as too new for the logs (D63): an item added in the last day is not a finding (RD26).
    var isRecentlyAdded: Bool { cells.values.contains(where: \.isRecentlyAdded) }
    /// The members whose file is the user's own, so a write may touch them.
    var removableMembers: [String] { items.filter(\.removable).map(\.id) + hooks.filter(\.removable).map(\.id) }
    /// Sessions (or runs) over every CLI that counted.
    var total: Int { cells.values.compactMap(\.count).reduce(0, +) }

    /// `user`, `link`, or a plugin's name.
    static func isPluginOwner(_ owner: String) -> Bool { owner != "user" && owner != "link" }

    /// A registry CLI the row has no cell for reads as unknown, never as Missing: an older core sent no `cliCells`.
    func cell(_ cli: String) -> CoreCLICell { cells[cli] ?? .unknown }

    func presence(_ cli: String) -> CellPresence {
        switch cell(cli) {
        case .sessions, .runs, .unmeasurable, .scanning: .on
        case .missing: .off
        case .unknown: .unknown
        case .notSupported: .notSupported
        }
    }

    var status: ItemStatus {
        if kind == .hook, isDead { return .dead }
        let all = Array(cells.values)
        let counted = all.compactMap(\.count)
        if counted.contains(where: { $0 > 0 }) { return .ran }
        if all.contains(.unknown) { return .unknown }
        if !counted.isEmpty { return .neverRan }
        if all.contains(.scanning) { return .pending }
        return .unmeasurable
    }

    /// The Never ran / Dead set every surface shares (Skills hero, Hooks hero, Inbox Clean up, Clean's Agents section).
    var isCandidate: Bool { status == .neverRan || status == .dead }

    /// Suggested for removal: a candidate that was not just added, is not plugin-owned, not a project item and not kept
    /// (RD26, RD-R4 "What counts").
    func isSuggested(kept: Set<String>) -> Bool {
        isCandidate && !isRecentlyAdded && !isPlugin && !isProject && !kept.contains(id)
    }

    /// The tile's heat step for one CLI, 0 to 3, relative to the item's top CLI (RD-R12): 0 for no use, then a quarter,
    /// six tenths, and above.
    func heatStep(_ cli: String) -> Int {
        let top = max(1, cells.values.compactMap(\.count).max() ?? 0)
        let ratio = Double(cell(cli).count ?? 0) / Double(top)
        return ratio <= 0 ? 0 : ratio <= 0.25 ? 1 : ratio <= 0.6 ? 2 : 3
    }
}

extension FrameRow {
    /// Groups `loadout.rows` by row key, in the order the core sent the members (items, then Hooks).
    static func rows(from loadout: CoreLoadoutRows) -> [FrameRow] {
        var order: [String] = []
        var items: [String: [CoreInventoryItem]] = [:]
        var hooks: [String: [CoreInventoryHook]] = [:]
        for item in loadout.items {
            if items[item.key] == nil { order.append(item.key) }
            items[item.key, default: []].append(item)
        }
        for hook in loadout.hooks {
            if hooks[hook.key] == nil, items[hook.key] == nil { order.append(hook.key) }
            hooks[hook.key, default: []].append(hook)
        }
        return order.map { key in
            let members = items[key] ?? []
            let rowHooks = hooks[key] ?? []
            let kind = members.first?.kind ?? .hook
            let name = members.first.map { Self.bareName($0.name) } ?? rowHooks.first.map { HookLabel.of($0.command) } ?? key
            let cells = members.first?.cliCells ?? rowHooks.first?.cliCells ?? [:]
            return FrameRow(id: key, kind: kind, name: name, items: members, hooks: rowHooks, cells: cells)
        }
    }

    /// A plugin item's name carries its plugin (`plugin:name`); the row key holds the bare name.
    private static func bareName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    /// The width of the inspector's tile grid: `max(3, ceil(N/3))` columns, so N CLIs never take more than 3 rows (RD-R12).
    static func tileColumns(cliCount: Int) -> Int { max(3, (cliCount + 2) / 3) }
}
