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

/// One row of Skills, Subagents or Hooks. A Skill or Subagent row is every member of one `loadout.rows` row key, whichever CLI
/// holds it; its cells are the core's `cliCells`, the same on every member of the key (inventory.md "CLI cells"). A Hook row
/// is one CLI's members of a key (RD46, the mock's `pageHooks`: one CLI per Hook row): its own CLI keeps its cell, every other
/// CLI reads Missing (Not supported and an unreadable CLI's Unknown stay), so its logo, status, counts and Inbox finding are
/// that CLI's alone.
struct FrameRow: Identifiable, Equatable, Sendable {
    /// The row key: `<kind>:<project or empty>:<bare name>`; a Hook row's is its CLI's part of the key,
    /// `hook:<project or empty>:<hash>@<cli>` (`HookPart.id`).
    let id: String
    let kind: CoreKind
    /// The item's name, or for a Hook the script it runs (`HookLabel`, RD-R17).
    let name: String
    let items: [CoreInventoryItem]
    let hooks: [CoreInventoryHook]
    let cells: CoreCLICells
    /// The newest `firstSeen` of the members (RB-E5): when SpaceVibe first saw the newest copy. Nil when no member carries it.
    var firstSeen: Date? = nil
    /// `firstSeen` is less than `addedGrace` before the clock the rows were built with (`rows(from:now:)`).
    var isNewByClock = false

    /// The core's grace for "Added in the last 24 hours" (`pendingGraceMs` in core/internal/inventory/attach-usage.go).
    static let addedGrace: TimeInterval = 24 * 60 * 60

    var project: String? { items.first?.project ?? hooks.first?.project }
    /// Skills, Subagents and Hooks under `<project>/.claude`: listed, read-only, never an Inbox finding ("Inferred, not
    /// decided": Project items).
    var isProject: Bool { (items.first?.scope ?? hooks.first?.scope) == .project }
    /// A member is owned by a plugin. One plugin-owned member is enough: the row is never suggested for removal.
    var isPlugin: Bool { items.contains { Self.isPluginOwner($0.owner) } || hooks.contains { Self.isPluginOwner($0.owner) } }
    /// Every script the Hook names is gone.
    var isDead: Bool { hooks.contains(where: \.dead) }
    /// Added in the last day, so not a finding (RD26). One rule: a counted zero carries the core's D63 note ("Added in the
    /// last 24 hours", "Added after the newest log"), or, where no cell carries one (a dead Hook that ran, unmeasurable or
    /// scanning cells), the newest `firstSeen` is under 24 hours old. The note is decided by that same time, so the two
    /// agree where both exist.
    var isRecentlyAdded: Bool { isNewByClock || cells.values.contains(where: \.isRecentlyAdded) }
    /// The members whose file is the user's own, so a write may touch them.
    var removableMembers: [String] { items.filter(\.removable).map(\.id) + hooks.filter(\.removable).map(\.id) }
    /// The members the new frame's writes (`removeFrom`, `removeMany`) may take: user-level files outside any project. The
    /// Codex skills of `~/.agents/skills` count: `loadout.rows` marks them not `removable` only for the v5 methods
    /// (inventory.md "Readers map").
    var writableMembers: [String] {
        let user = { (owner: String, scope: CoreInventoryScope, project: String?) in !Self.isPluginOwner(owner) && scope == .global && project == nil }
        return items.filter { $0.removable || user($0.owner, $0.scope, $0.project) }.map(\.id)
            + hooks.filter { $0.removable || user($0.owner, $0.scope, $0.project) }.map(\.id)
    }
    /// Every member id, items then Hooks: what `Remove N selected` passes for each row (`loadout.removeMany`).
    var memberIDs: [String] { items.map(\.id) + hooks.map(\.id) }
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
        let all = judgedCells
        let counted = all.compactMap(\.count)
        if counted.contains(where: { $0 > 0 }) { return .ran }
        if all.contains(.unknown) { return .unknown }
        if !counted.isEmpty { return .neverRan }
        if all.contains(.scanning) { return .pending }
        return .unmeasurable
    }

    /// The cells `status` judges. A Skill or Subagent: every CLI's, so an unreadable folder makes an item with no counted use
    /// unknown (the mock's `itemStatus`, `src/m-model.js:48`). A Hook: only the CLIs that hold it (RD-R10, mock
    /// `m-model.js:45`: a Hook is judged by its own CLI), so an unreadable `~/.codex` never turns a Claude Code-only Never ran
    /// Hook unknown.
    private var judgedCells: [CoreCLICell] {
        guard kind == .hook else { return Array(cells.values) }
        return Set(hooks.map(\.cli.rawValue)).sorted().compactMap { cells[$0] }
    }

    /// The Never ran / Dead set every surface shares (Skills hero, Hooks hero, Inbox Clean up, Clean's Agents section).
    var isCandidate: Bool { status == .neverRan || status == .dead }

    /// Open to a removal suggestion: not just added, not plugin-owned, not a project item and not a Hook SpaceVibe does not
    /// write (RD26, RD-R4 "What counts", D25). Whether it is a candidate or kept is asked separately.
    var isSuggestible: Bool { !isRecentlyAdded && !isPlugin && !isProject && !isHookSpaceVibeDoesNotWrite }

    /// Suggested for removal: a suggestible candidate that is not kept.
    func isSuggested(kept: Set<String>) -> Bool {
        isCandidate && isSuggestible && !kept.contains(id)
    }

    /// The tile's heat step for one CLI (RD-R12), by the one rule in `HeatStep.step(sessions:top:)`: its count (sessions, or
    /// runs for a Hook) against the item's top CLI. A cell with no count (missing, unmeasurable, scanning) is step 0.
    func heatStep(_ cli: String) -> HeatStep {
        HeatStep.step(sessions: cell(cli).count ?? 0, top: cells.values.compactMap(\.count).max() ?? 0)
    }
}

extension FrameRow {
    /// Groups `loadout.rows` by row key, in the order the core sent the members (items, extra items, then Hooks). The extra
    /// items (Codex skills in `~/.agents/skills`) belong to the same rows; only the v5 shell must not see them. With `now`,
    /// a row whose newest `firstSeen` is under `addedGrace` old is recently added; without it only the D63 note says so.
    static func rows(from loadout: CoreLoadoutRows, now: Date? = nil) -> [FrameRow] {
        var order: [String] = []
        var items: [String: [CoreInventoryItem]] = [:]
        var hooks: [String: [CoreInventoryHook]] = [:]
        for item in loadout.items + loadout.extraItems {
            if items[item.key] == nil { order.append(item.key) }
            items[item.key, default: []].append(item)
        }
        for hook in loadout.hooks {
            if hooks[hook.key] == nil, items[hook.key] == nil { order.append(hook.key) }
            hooks[hook.key, default: []].append(hook)
        }
        return order.flatMap { key -> [FrameRow] in
            let members = items[key] ?? []
            guard members.isEmpty else {
                return [row(id: key, items: members, hooks: hooks[key] ?? [], cells: members.first?.cliCells ?? [:], now: now)]
            }
            return hookParts(hooks[key] ?? []).map { part in
                row(id: part.id(key), items: [], hooks: part.hooks, cells: part.cells, now: now)
            }
        }
    }

    private static func row(id: String, items: [CoreInventoryItem], hooks: [CoreInventoryHook], cells: CoreCLICells, now: Date?) -> FrameRow {
        let kind = items.first?.kind ?? .hook
        let name = items.first.map { Self.bareName($0.name) } ?? hooks.first.map { HookLabel.of($0.command) } ?? id
        let seen = (items.map(\.firstSeen) + hooks.map(\.firstSeen)).compactMap(ActivityFormat.date).max()
        let isNew = now.flatMap { now in seen.map { now.timeIntervalSince($0) < addedGrace } } ?? false
        return FrameRow(id: id, kind: kind, name: name, items: items, hooks: hooks, cells: cells, firstSeen: seen, isNewByClock: isNew)
    }

    /// One CLI's members of a Hook key (RD46).
    struct HookPart: Equatable, Sendable {
        let cli: String
        let hooks: [CoreInventoryHook]
        let cells: CoreCLICells
        /// The part that held the bare core key as its row id before every part carried its CLI (Claude Code's, else the
        /// first CLI's): the one whose Keep entries `keptHookIDMoves` moves.
        let wasKeyHolder: Bool

        /// `<key>@<cli>` for every part, so a part's id (its selection, ticks, Keep entry and Inbox ids) never changes when
        /// another CLI's member of the same key comes or goes.
        func id(_ key: String) -> String { "\(key)@\(cli)" }
    }

    /// Splits one key's Hook members by CLI, in the order the core sent them. A part's cells keep its own CLI's cell and
    /// Not supported and Unknown (an unreadable folder); every other CLI reads Missing, so the part is that CLI's alone.
    static func hookParts(_ hooks: [CoreInventoryHook]) -> [HookPart] {
        var order: [String] = []
        var byCLI: [String: [CoreInventoryHook]] = [:]
        for hook in hooks {
            let cli = hook.cli.rawValue
            if byCLI[cli] == nil { order.append(cli) }
            byCLI[cli, default: []].append(hook)
        }
        let keeper = order.contains(CoreCLI.claude.rawValue) ? CoreCLI.claude.rawValue : order.first
        return order.map { cli in
            let members = byCLI[cli] ?? []
            let shared = members.first?.cliCells ?? [:]
            let cells = shared.reduce(into: CoreCLICells()) { out, entry in
                out[entry.key] = entry.key == cli || entry.value == .notSupported || entry.value == .unknown ? entry.value : .missing
            }
            return HookPart(cli: cli, hooks: members, cells: cells, wasKeyHolder: cli == keeper)
        }
    }

    /// One Keep entry to move: the finding id under the old Hook row id and the same finding under the new one.
    struct KeptIDMove: Equatable, Sendable {
        let old: String
        let new: String
    }

    /// The Keep entries stored under a Hook row id of the old shape (the bare core key, for the part that held it), each
    /// with its id under `HookPart.id`: the Clean up finding (the row id) and the failing Hook (`<row id>:fail`). Only keys
    /// `loadout` still lists move; an entry whose new id is kept already is left alone.
    static func keptHookIDMoves(kept: Set<String>, loadout: CoreLoadoutRows) -> [KeptIDMove] {
        let itemKeys = Set((loadout.items + loadout.extraItems).map(\.key))
        var order: [String] = []
        var byKey: [String: [CoreInventoryHook]] = [:]
        for hook in loadout.hooks where !itemKeys.contains(hook.key) {
            if byKey[hook.key] == nil { order.append(hook.key) }
            byKey[hook.key, default: []].append(hook)
        }
        var moves: [KeptIDMove] = []
        for key in order {
            guard let holder = hookParts(byKey[key] ?? []).first(where: \.wasKeyHolder) else { continue }
            let id = holder.id(key)
            for (old, new) in [(key, id), ("\(key):fail", "\(id):fail")] where kept.contains(old) && !kept.contains(new) {
                moves.append(KeptIDMove(old: old, new: new))
            }
        }
        return moves
    }

    /// A plugin item's name carries its plugin (`plugin:name`); the row key holds the bare name.
    private static func bareName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }
}
