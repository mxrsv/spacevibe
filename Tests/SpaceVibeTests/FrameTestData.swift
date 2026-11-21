import Foundation
@testable import SpaceVibe

/// Hand-built engine readings for the redesign's model tests: registry entries, `loadout.rows` members with `cliCells`,
/// rules, limit Windows and sessions. Names are synthetic (S-R2).
enum FrameTestData {
    static let all = CoreRegistrySupports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)

    static func cli(_ id: String, supports: CoreRegistrySupports = all) -> CoreRegistryCLI {
        CoreRegistryCLI(id: id, name: id.capitalized, supports: supports)
    }

    /// Claude Code and Codex, as `clis.registry` answers today.
    static let registry = [cli("claude"), cli("codex")]

    /// `n` CLIs: the two read today and synthetic others; every third one has no logs, every fourth no Subagents.
    static func registry(count n: Int) -> [CoreRegistryCLI] {
        registry + (2..<max(2, n)).map { index in
            cli("cli\(index)", supports: CoreRegistrySupports(skill: true, agent: index % 4 != 0, hook: index % 2 == 0, rule: false, logs: index % 3 != 0, limits: false))
        }
    }

    static func sessions(_ n: Int, note: String? = nil) -> CoreCLICell { .sessions(count: n, days: n > 0 ? ["2026-11-01"] : [], last: n > 0 ? "2026-11-01" : nil, note: note) }
    static func runs(_ n: Int, errors: Int = 0) -> CoreCLICell { .runs(count: n, errors: errors, last: nil, note: nil) }

    static func item(
        _ name: String, kind: CoreKind = .skill, cli: CoreCLI = .claude, owner: String = "user", project: String? = nil,
        cells: CoreCLICells, removable: Bool = true
    ) -> CoreInventoryItem {
        let key = "\(kind.rawValue):\(project ?? ""):\(name)"
        return CoreInventoryItem(
            id: "\(cli.rawValue):\(kind.rawValue):\(name)", cli: cli, kind: kind, name: name, entry: name, description: "", owner: owner,
            path: "/h/.\(cli.rawValue)/skills/\(name)", file: "/h/.\(cli.rawValue)/skills/\(name)/SKILL.md", removable: removable,
            scope: project == nil ? .global : .project, project: project, inOther: false, key: key, cliCells: cells
        )
    }

    static func hook(_ hash: String, command: String = "~/.claude/hooks/\("guard").sh", dead: Bool = false, owner: String = "user", cells: CoreCLICells) -> CoreInventoryHook {
        CoreInventoryHook(
            id: "claude:hook:\(hash)", cli: .claude, kind: .hook, event: "PreToolUse", matcher: nil, command: command, timeout: nil, async: false,
            owner: owner, removable: true, dead: dead, paths: [], hash: hash, file: "/h/.claude/settings.json", scope: .global, project: nil,
            key: "hook::\(hash)", cells: nil, cliCells: cells, usage: nil
        )
    }

    static func loadout(_ items: [CoreInventoryItem] = [], hooks: [CoreInventoryHook] = [], usage: CoreLoadoutRows.UsageState = .ready) -> CoreLoadoutRows {
        CoreLoadoutRows(usage: usage, items: items, hooks: hooks, problems: [], events: [:], roots: [:], countsByScope: [:], rowFlags: [:])
    }

    static func rule(_ text: String, verdict: CoreVerdict = .allow, file: FrameScope = .global) -> CoreRule {
        let open = text.firstIndex(of: "(")
        let tool = open.map { String(text[..<$0]) } ?? text
        let specifier = open.map { String(text[text.index(after: $0)..<text.index(before: text.endIndex)]) }
        return CoreRule(
            id: "\(file.scope.rawValue):\(verdict.rawValue):\(text)", scope: file.scope, dir: file.dir, file: "settings.json", verdict: verdict,
            rule: text, tool: tool, specifier: specifier
        )
    }

    static func rules(_ rules: [CoreRule], file: FrameScope = .global, projects: [String] = []) -> CoreRulesSnapshot {
        CoreRulesSnapshot(
            projectDirs: projects, globalRuleCount: rules.count, scope: file.scope, dir: file.dir, fileLabel: "settings.json", exists: true,
            problems: [], rules: rules, grid: [], codex: codex, notReadable: false, globalNotReadable: false
        )
    }

    static let codex = CoreCodexPermissions(
        present: false, model: .legacy, unrestricted: false, warnings: [], approvalPolicy: nil, sandboxMode: nil, sandboxWorkspaceWrite: nil,
        defaultPermissions: nil, approvalsReviewer: nil, profiles: [], projects: [],
        rules: CoreCodexRulesSummary(files: 0, allow: 0, prompt: 0, forbidden: 0, other: 0, unreadable: 0, folderNotReadable: false),
        notReadable: false, skippedLines: 0
    )

    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A Window `used`% through, with `minutesLeft` of `minutes` to go, read `readAgo` seconds before `now`.
    static func limits(
        _ cli: CoreLimitsCLI = .claude, id: String = "5-hour", used: Double, minutes: Int? = 300, minutesLeft: Double = 150,
        readAgo: TimeInterval = 60, active: Bool = true
    ) -> CoreLimitsEntry {
        let window = CoreLimitWindow(
            id: id, minutes: minutes, scope: nil, usedPercent: used, resetsAt: now.timeIntervalSince1970 + minutesLeft * 60, active: active, current: true
        )
        return CoreLimitsEntry(cli: cli, state: .measured, plan: nil, source: nil, at: now.timeIntervalSince1970 - readAgo, windows: [window])
    }

    static func session(_ id: String, cli: CoreCLI = .claude, state: CoreSessionState) -> CoreActivitySession {
        CoreActivitySession(
            cli: cli, id: id, title: "task \(id)", project: nil, pid: 100, state: state, stateReason: "", reasonCode: nil, currentTool: nil,
            ageMs: nil, lastWriteAgoMs: nil, cost: nil, costNote: nil
        )
    }

    static func activity(_ sessions: [CoreActivitySession], unmeasurable: [CoreActivityLimit] = []) -> CoreActivityReport {
        CoreActivityReport(sessions: sessions, failures: [], files: [], unmeasurable: unmeasurable, stats: CoreActivityStats(logs: 1, truncated: 0))
    }

    /// A snapshot with every source answered: two CLIs, these rows, no rules, no limits, no sessions.
    static func snapshot(_ loadout: CoreLoadoutRows, registry: [CoreRegistryCLI] = registry) -> FrameSnapshot {
        FrameSnapshot(
            registry: registry, inventory: nil, loadout: loadout, rules: [.global: rules([])], limits: CoreLimitsResult(limits: []),
            activity: activity([]), journal: CoreJournalHistory(entries: [])
        )
    }

    static func entry(_ id: String, label: String = "Removed a") -> CoreJournalEntry {
        CoreJournalEntry(id: id, at: "2026-11-21T10:00:00.000Z", label: label, undone: false, count: 1)
    }
}
