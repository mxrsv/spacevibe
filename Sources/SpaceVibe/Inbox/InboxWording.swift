import Foundation

/// The words and glyph of each Inbox row, ported from the "Inbox findings" block of the reference mock's `world`
/// (`src/m-model.js`) and its `rowIcon` / `actOf` (`src/c-inbox-equip.js`). Pure: built from one world and the clock.
struct InboxWording {
    let world: FrameWorld
    let now: Date

    // MARK: Names

    /// The registry's name for a CLI id; an id it does not list shows as itself.
    func name(_ cli: String) -> String { world.cliName(cli) }

    func names(_ clis: [String]) -> String { CLINames.sentence(clis.map(name)) }

    static func kindWord(_ kind: CoreKind) -> String {
        switch kind {
        case .skill: "Skill"
        case .agent: "Subagent"
        case .hook: "Hook"
        }
    }

    /// The CLIs that load the row now, in registry order (the mock's `whereOf`). A Hook belongs to its own CLI.
    func loadedBy(_ row: FrameRow) -> [String] {
        if row.kind == .hook { return row.hooks.contains { $0.cli == .claude } ? ["claude"] : row.hooks.first.map { [$0.cli.rawValue] } ?? [] }
        return world.snapshot.registry.map(\.id).filter { row.presence($0) == .on }
    }

    /// A Skill or Subagent whose file another CLI reads too, or whose readers are not known: removing it names every reader
    /// first. A Hook never asks: its file is its CLI's own (the mock's `MOCK.na`: Hooks never ask).
    func asksBeforeRemoving(_ row: FrameRow) -> Bool {
        guard row.kind != .hook else { return false }
        guard let readers = world.readers(of: row) else { return true }
        let supporting = Set(world.snapshot.registry.filter { $0.supports.supports(row.kind) }.map(\.id))
        return !readers.elsewhere.isEmpty || readers.members.contains { Set($0.readBy).intersection(supporting).count > 1 }
    }

    /// Every CLI that loses the row when all of it is removed, hidden CLIs included; who loads it when the readers are not
    /// known.
    func losers(_ row: FrameRow) -> [String] {
        world.losers(of: row, removing: Set(row.memberIDs)).value ?? loadedBy(row)
    }

    /// The member ids a removal passes (`loadout.removeMany`): every member of a Skill or Subagent, a Hook's Claude Code members
    /// only (D25: SpaceVibe writes Hooks only into Claude Code).
    static func removableMembers(_ rows: [FrameRow]) -> Set<String> {
        Set(rows.flatMap { row in row.kind == .hook ? row.hooks.filter { $0.cli == .claude }.map(\.id) : row.memberIDs })
    }

    /// "Remove from Claude Code and Codex"; a shared file "Remove…" (it asks first, so it ends in an ellipsis).
    func removeTitle(_ row: FrameRow) -> String {
        if asksBeforeRemoving(row) { return "Remove…" }
        return "Remove from \(names(loadedBy(row)))"
    }

    /// "added 3 days ago" from the newest `firstSeen`; nil when no member carries one.
    func added(_ row: FrameRow) -> String? {
        row.firstSeen.map { DayWording.added(secondsAgo: now.timeIntervalSince($0)) }
    }

    // MARK: Rows

    func row(_ finding: InboxFinding, kept: Bool, hasHost: (Int) -> Bool) -> InboxRowModel {
        let keep: InboxAction = kept ? .stopKeeping : .keep
        switch finding.subject {
        case .row(let row):
            let isHook = row.kind == .hook
            let dead = row.status == .dead
            let hook = row.hooks.first
            let sub = isHook
                ? "Hook · \(hook?.event ?? "") · \(hook.map { name($0.cli.rawValue) } ?? "")"
                : [Self.kindWord(row.kind), added(row)].compactMap { $0 }.joined(separator: " · ")
            return InboxRowModel(
                finding: finding, glyph: InboxRowGlyph(icon: dead ? .prohibit : .circleDashed), title: row.name, isMono: isHook,
                sub: sub, evidence: dead ? "Script file is missing" : "Never ran", isRemovable: !kept, isKept: kept,
                actions: [keep, .remove(title: removeTitle(row), asks: asksBeforeRemoving(row))])
        case .balance(let row, let missing, let sessions):
            return InboxRowModel(
                finding: finding, glyph: InboxRowGlyph(icon: .copy), title: row.name, isMono: false,
                sub: "\(Self.kindWord(row.kind)) · ran in \(NumberWording.plural(sessions, "session"))",
                evidence: "Missing in \(name(missing))", isRemovable: false, isKept: kept,
                actions: [keep, .addTo(cli: missing, title: "Add to \(name(missing))")])
        case .failingHook(let row, let errors):
            let hook = row.hooks.first
            return InboxRowModel(
                finding: finding, glyph: InboxRowGlyph(icon: .warning), title: row.name, isMono: true,
                sub: "Hook · \(hook?.event ?? "") · \(hook.map { name($0.cli.rawValue) } ?? "")",
                evidence: "\(NumberWording.plural(errors, "failure")) in 7 days", isRemovable: false, isKept: kept,
                actions: [keep, .copyCommand(hook?.command ?? row.name)])
        case .rule(let rule, let file):
            return InboxRowModel(
                finding: finding, glyph: InboxRowGlyph(icon: .shieldWarning), title: rule.rule, isMono: true,
                sub: "Rule · Claude Code · \(Self.place(file))", evidence: "Allows every \(rule.tool ?? rule.rule) call",
                isRemovable: false, isKept: kept, actions: [keep, .changeToAsk])
        case .window(let pace):
            return InboxRowModel(
                finding: finding, glyph: InboxRowGlyph(icon: .limits), title: windowTitle(pace), isMono: false,
                sub: pace.over > 0 ? "Over the limit" : pace.isLow ? "Almost used up" : "Faster than time passes",
                evidence: "\(Self.percent(pace.left ?? 0)) left · resets \(LimitsWording.resetsAt(pace.window, now: now))",
                isRemovable: false, isKept: kept, actions: [keep])
        case .session(let session):
            let waited = session.lastWriteAgoMs.map { "Waiting \(ActivityFormat.span($0))" } ?? "Waiting"
            return InboxRowModel(
                finding: finding, glyph: InboxRowGlyph(icon: .chatCircleDots, ink: .sessionWaiting), title: session.title, isMono: false,
                sub: "\(name(session.cli.rawValue)) session · \(session.project ?? "No project")", evidence: waited,
                isRemovable: false, isKept: kept,
                actions: [keep, hasHost(session.pid) ? .showTerminal(pid: session.pid) : .terminalNotFound])
        }
    }

    /// "Codex · 5-hour Window".
    func windowTitle(_ pace: WindowPace) -> String { "\(name(pace.cli)) · \(LimitsWording.name(pace.window)) Window" }

    /// "Global", "payments-web · Shared", "payments-web · Local".
    static func place(_ file: FrameScope) -> String {
        guard let dir = file.dir else { return "Global" }
        return "\((dir as NSString).lastPathComponent) · \(file.scope == .local ? "Local" : "Shared")"
    }

    /// The file a Rule write lands in: `~/.claude/settings.json`, `<project>/.claude/settings.json` or `settings.local.json`.
    static func settingsFile(_ file: FrameScope) -> String {
        guard let dir = file.dir else { return "~/.claude/settings.json" }
        return "\((dir as NSString).abbreviatingWithTildeInPath)/.claude/settings\(file.scope == .local ? ".local" : "").json"
    }

    /// One decimal only when there is one: "77%", "4.5%".
    static func percent(_ share: Double) -> String {
        let rounded = (share * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))%" : "\(rounded)%"
    }

    // MARK: Problems

    /// The registry CLIs whose folder could not be read: some row has an unknown cell for them (RD-R10).
    var unreadable: InboxBanner? {
        let ids = world.clis.map(\.id).filter { id in world.rows.contains { $0.cell(id) == .unknown } }
        guard !ids.isEmpty else { return nil }
        let roots = world.snapshot.loadout?.roots ?? [:]
        let paths = ids.map { id in roots[id].map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "\(name(id))’s folder" }
        return .unreadable(names: ids.map(name), paths: paths)
    }
}
