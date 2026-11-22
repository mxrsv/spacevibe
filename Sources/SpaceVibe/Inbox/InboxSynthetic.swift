import Foundation

/// In-memory engine readings for the Inbox shots, one per RD-R13 state, at 2 and 10 CLIs: what the synthetic home cannot
/// hold (a Window behind pace, a waiting session, a kept finding, an unreadable Codex folder, a shared `~/.agents/skills`
/// file). Built like the reference mock's data (`src/a-core.js`); names are made up (S-R2).
enum InboxSynthetic {
    enum State: String, CaseIterable, Sendable {
        case normal, empty, scanning, error, worst, write, refused, dialog
    }

    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Registry

    static func registry(_ count: Int) -> [CoreRegistryCLI] {
        let all = CoreRegistrySupports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)
        let others: [(String, String, CoreRegistrySupports)] = [
            ("cursor", "Cursor CLI", .init(skill: true, agent: true, hook: true, rule: false, logs: true, limits: false)),
            ("copilot", "GitHub Copilot", .init(skill: true, agent: true, hook: true, rule: false, logs: false, limits: false)),
            ("opencode", "OpenCode", .init(skill: true, agent: true, hook: false, rule: false, logs: true, limits: false)),
            ("amp", "Amp", .init(skill: true, agent: false, hook: false, rule: false, logs: true, limits: false)),
            ("antigravity", "Antigravity", .init(skill: true, agent: true, hook: false, rule: false, logs: false, limits: false)),
            ("kiro", "Kiro", .init(skill: true, agent: true, hook: true, rule: false, logs: true, limits: false)),
            ("qwen", "Qwen Code", .init(skill: true, agent: true, hook: false, rule: false, logs: true, limits: false)),
            ("aider", "Aider", .init(skill: false, agent: false, hook: false, rule: false, logs: true, limits: false)),
        ]
        let two = [CoreRegistryCLI(id: "claude", name: "Claude Code", supports: all), CoreRegistryCLI(id: "codex", name: "Codex", supports: all)]
        return two + others.prefix(max(0, count - 2)).map { CoreRegistryCLI(id: $0.0, name: $0.1, supports: $0.2) }
    }

    // MARK: Cells

    static func sessions(_ n: Int) -> CoreCLICell { .sessions(count: n, days: n > 0 ? ["2026-12-01"] : [], last: n > 0 ? "2026-12-01" : nil, note: nil) }

    /// Every registry CLI's cell for an item: `on` CLIs counted (or Unmeasurable without logs), the rest Missing or Not supported;
    /// `unreadable` CLIs Unknown.
    static func cells(_ registry: [CoreRegistryCLI], kind: CoreKind, on: [String: Int], unreadable: Set<String>) -> CoreCLICells {
        Dictionary(uniqueKeysWithValues: registry.map { cli -> (String, CoreCLICell) in
            if unreadable.contains(cli.id) { return (cli.id, .unknown) }
            guard cli.supports.supports(kind) else { return (cli.id, .notSupported) }
            guard let n = on[cli.id] else { return (cli.id, .missing) }
            if kind == .hook { return (cli.id, .runs(count: n, errors: 0, last: nil, note: nil)) }
            return (cli.id, cli.supports.logs ? sessions(n) : .unmeasurable(reason: "\(cli.name) keeps no log SpaceVibe can count"))
        })
    }

    static func iso(daysAgo: Double) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(-daysAgo * 86_400))
    }

    // MARK: Items

    struct Item {
        let name: String
        var kind: CoreKind = .skill
        var description = ""
        /// Sessions per CLI id; a CLI not listed is Missing.
        let on: [String: Int]
        var addedDaysAgo: Double = 30
        /// Codex's copy sits in `~/.agents/skills`, which other CLIs read too.
        var agentsFolder = false
    }

    static func items(_ list: [Item], registry: [CoreRegistryCLI], unreadable: Set<String>) -> [CoreInventoryItem] {
        list.flatMap { item -> [CoreInventoryItem] in
            let folderName = item.kind == .agent ? "agents" : "skills"
            let key = "\(item.kind.rawValue)::\(item.name)"
            let cells = cells(registry, kind: item.kind, on: item.on, unreadable: unreadable)
            return ["claude", "codex"].filter { item.on[$0] != nil }.map { cli in
                let folder = cli == "codex" && item.agentsFolder ? "~/.agents/skills" : "~/.\(cli)/\(folderName)"
                let path = "\(folder)/\(item.name)"
                return CoreInventoryItem(
                    id: "\(cli):\(item.kind.rawValue):\(item.name)", cli: cli == "claude" ? .claude : .codex, kind: item.kind, name: item.name,
                    entry: item.name, description: item.description, owner: "user", path: path, file: "\(path)/SKILL.md", removable: true,
                    scope: .global, project: nil, inOther: false, key: key, cliCells: cells, folder: folder, realPath: path,
                    firstSeen: iso(daysAgo: item.addedDaysAgo))
            }
        }
    }

    /// The readers map: each CLI's own folders; `~/.agents/skills` read by Codex and, at many CLIs, by Cursor CLI and Amp.
    static func folders(_ registry: [CoreRegistryCLI]) -> [CoreReadersFolder] {
        let ids = registry.map(\.id)
        let agentsReaders = ["codex", "cursor", "amp"].filter(ids.contains)
        return [
            CoreReadersFolder(path: "~/.claude/skills", realPath: "~/.claude/skills", kind: .skill, readBy: ["claude"], ownedBy: "claude", copyTarget: true),
            CoreReadersFolder(path: "~/.codex/skills", realPath: "~/.codex/skills", kind: .skill, readBy: ["codex"], ownedBy: "codex", copyTarget: true),
            CoreReadersFolder(path: "~/.agents/skills", realPath: "~/.agents/skills", kind: .skill, readBy: agentsReaders, ownedBy: "codex", copyTarget: false),
            CoreReadersFolder(path: "~/.claude/agents", realPath: "~/.claude/agents", kind: .agent, readBy: ["claude"], ownedBy: "claude", copyTarget: true),
            CoreReadersFolder(path: "~/.codex/agents", realPath: "~/.codex/agents", kind: .agent, readBy: ["codex"], ownedBy: "codex", copyTarget: true),
            CoreReadersFolder(path: "~/.claude/settings.json", realPath: "~/.claude/settings.json", kind: .hook, readBy: ["claude"], ownedBy: "claude", copyTarget: false),
        ]
    }

    struct Hook {
        let hash: String
        let command: String
        var event = "PostToolUse"
        var dead = false
        var runs = 0
        var errorsLastWeek = 0
    }

    static func hooks(_ list: [Hook], registry: [CoreRegistryCLI]) -> [CoreInventoryHook] {
        list.map { hook in
            var cells = cells(registry, kind: .hook, on: ["claude": hook.runs], unreadable: [])
            let week = [CoreHookDay(day: "2026-12-01", runs: hook.runs, errors: hook.errorsLastWeek)]
            cells["claude"] = .runs(count: hook.runs, errors: hook.errorsLastWeek, last: hook.runs > 0 ? "2026-12-01" : nil, note: nil,
                                    week: hook.errorsLastWeek > 0 ? week : [])
            return CoreInventoryHook(
                id: "claude:hook:\(hook.hash)", cli: .claude, kind: .hook, event: hook.event, matcher: nil, command: hook.command, timeout: nil,
                async: false, owner: "user", removable: true, dead: hook.dead, paths: [], hash: hook.hash, file: "~/.claude/settings.json",
                scope: .global, project: nil, key: "hook::\(hook.hash)", cells: nil, cliCells: cells, folder: "~/.claude/settings.json",
                usage: nil, firstSeen: iso(daysAgo: 40))
        }
    }

    // MARK: Worlds

    static let longName = "migrate-tailwind-utility-classes-across-the-whole-monorepo-and-every-storybook-story"
    static let project = "/Users/someone/Development/payments-web"

    /// The engine readings of one state at `count` CLIs (2 or 10), with the facts the store would fill. `pinned`: Claude Code
    /// and Codex are pinned, as the mock's Settings default (`UI.pin`), so Balance compares them; false shows "Balance is off".
    static func snapshot(_ state: State, clis count: Int, pinned: Bool = true) -> (snapshot: FrameSnapshot, facts: FrameFacts) {
        let registry = registry(count)
        let unreadable: Set<String> = state == .error ? ["codex"] : []
        let worst = state == .worst
        var list: [Item] = [
            // At many CLIs Codex's copy is in `~/.agents/skills`, which Cursor CLI and Amp read too: one shared file.
            Item(name: "pdf-extract", description: "Pulls text and tables out of PDF files.",
                 on: count > 2 ? ["claude": 0, "codex": 0, "cursor": 0, "amp": 0] : ["claude": 0, "codex": 0], addedDaysAgo: 41,
                 agentsFolder: count > 2),
            Item(name: "changelog-writer", description: "Drafts a changelog entry from the merged pull requests.", on: ["claude": 0], addedDaysAgo: 12),
            Item(name: "figma-export", description: "Exports frames from a Figma file.", on: ["codex": 0], addedDaysAgo: 3),
            Item(name: "release-captain", kind: .agent, description: "Walks a release through its checklist.", on: ["claude": 0, "codex": 0]),
            Item(name: "code-review", description: "Reviews a diff.", on: ["claude": 312, "codex": 41]),
            Item(name: "test-runner", kind: .agent, description: "Runs the tests that cover a change.", on: ["claude": 88]),
        ]
        if worst {
            let stems = [longName, "データ変換-スキル", "مراجعة-طلبات-الدمج"]
            for index in 0 ..< 9 {
                let name: String = "\(stems[index % 3])-\(index)"
                let kind: CoreKind = index % 2 == 0 ? .skill : .agent
                list.append(Item(name: name, kind: kind, description: "Handles every odd edge case the team ever hit, in every repository, forever.",
                                 on: ["claude": 0, "codex": 0], addedDaysAgo: Double(412 + index)))
            }
        }
        var hookList: [Hook] = [
            Hook(hash: "h1", command: "~/.claude/hooks/lint-staged.sh", event: "PreToolUse", dead: true),
            Hook(hash: "h2", command: "sh '$HOME/.claude/scripts/post-edit-format.sh'", dead: true, runs: 14),
            Hook(hash: "h3", command: "~/.claude/hooks/notify-done.sh", event: "Stop"),
            Hook(hash: "h4", command: "pnpm prettier --write \"$CLAUDE_FILE\"", runs: 1_204, errorsLastWeek: 2),
        ]
        if state == .empty {
            // Everything is fixed: test-runner is in both pinned CLIs too, so Balance has nothing to say.
            list = list.filter { $0.name == "changelog-writer" || $0.name == "code-review" }
                + [Item(name: "test-runner", kind: .agent, description: "Runs the tests that cover a change.", on: ["claude": 88, "codex": 12])]
            hookList = []
        }
        if worst {
            hookList.append(Hook(hash: "h5", command: "node /Users/someone/Development/monorepo/packages/internal/tools/configs/very/deep/"
                                     + "hook.mjs --config ./hook.json --verbose --and-a-flag-that-goes-on-for-a-long-time",
                                 runs: 48_211_904, errorsLastWeek: 1_209_331))
        }
        var loadout = CoreLoadoutRows(
            usage: state == .scanning ? .scanning : .ready, items: items(list, registry: registry, unreadable: unreadable),
            hooks: hooks(hookList, registry: registry), problems: [], events: [:], roots: ["claude": "~/.claude", "codex": "~/.codex"],
            countsByScope: [:], rowFlags: [:])
        loadout.folders = folders(registry)

        let wideBash = CoreRule(id: "global:allow:Bash", scope: .global, dir: nil, file: "settings.json", verdict: .allow, rule: "Bash", tool: "Bash",
                                specifier: nil, wide: true)
        let local = FrameScope.local(project)
        let localBash = CoreRule(id: "local:allow:Bash", scope: .local, dir: project, file: "settings.local.json", verdict: .allow, rule: "Bash",
                                 tool: "Bash", specifier: nil, wide: true)
        // A bare `Bash` allow is the Run commands capability, as the engine's grid places it.
        func rules(_ list: [CoreRule], _ file: FrameScope) -> CoreRulesSnapshot {
            let grid = list.isEmpty ? [] : [CoreCapabilityCell(capability: .run, label: "Run commands", state: .allow, editable: true, rules: list)]
            return CoreRulesSnapshot(projectDirs: [project], globalRuleCount: 1, scope: file.scope, dir: file.dir, fileLabel: "settings.json",
                                     exists: true, problems: [], rules: list, grid: grid, codex: RulesSynthetic.codex(), notReadable: false,
                                     globalNotReadable: false)
        }

        func window(_ id: String, minutes: Int, used: Double, minutesLeft: Double) -> CoreLimitWindow {
            CoreLimitWindow(id: id, minutes: minutes, scope: nil, usedPercent: used, resetsAt: now.timeIntervalSince1970 + minutesLeft * 60,
                            active: true, current: true)
        }
        let at = now.timeIntervalSince1970 - 120
        let limits = CoreLimitsResult(limits: [
            CoreLimitsEntry(cli: .claude, state: .measured, plan: "max", source: nil, at: at,
                            windows: [window("five_hour", minutes: 300, used: 62, minutesLeft: 99)]),
            CoreLimitsEntry(cli: .codex, state: .measured, plan: "plus", source: nil, at: at,
                            windows: [window("primary", minutes: 300, used: worst ? 104.5 : 23, minutesLeft: 246)]),
        ])

        var waiting = CoreActivitySession(
            cli: .claude, id: "s-waiting", title: worst ? "Investigate the intermittent failure in the nightly integration suite \(longName)"
                : "Refactor the billing webhook", project: worst ? nil : "payments-web", pid: 47_812, state: .waiting,
            stateReason: "Waiting for your answer", reasonCode: nil, currentTool: nil, ageMs: 41 * 60_000, lastWriteAgoMs: 4 * 60_000,
            cost: CoreActivityCost(usd: worst ? 1_834.27 : 2.41, estimated: true), costNote: nil)
        waiting.currentTool = CoreActivityTool(name: "AskUserQuestion", target: "Which branch should the fix land on?")
        let activity = CoreActivityReport(sessions: state == .empty ? [] : [waiting], failures: [], files: [], unmeasurable: [],
                                          stats: CoreActivityStats(logs: 12, truncated: 0))

        let snapshot = FrameSnapshot(
            registry: registry, inventory: nil, loadout: loadout,
            rules: state == .empty ? [.global: rules([], .global)] : [.global: rules([wideBash], .global), local: rules([localBash], local)],
            limits: state == .empty ? CoreLimitsResult(limits: []) : limits, activity: activity, journal: CoreJournalHistory(entries: []))
        var facts = FrameFacts()
        facts.findings.hookErrorsLastWeek = FindingFacts.hookErrorsLastWeek(in: loadout)
        if pinned { facts.findings.pinned = ["claude", "codex"] }
        if state == .empty {
            // Everything is fixed but one Never ran Skill, which is kept: `Clear`, and `1 kept, not counted` (RD-A9).
            facts.findings.kept = ["skill::changelog-writer"]
        }
        return (snapshot, facts)
    }

    static func world(_ state: State, clis count: Int, pinned: Bool = true) -> FrameWorld {
        let built = snapshot(state, clis: count, pinned: pinned)
        return FrameWorld(snapshot: built.snapshot, facts: built.facts, now: now)
    }
}
