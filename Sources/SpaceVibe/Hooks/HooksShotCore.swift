import Foundation

/// The in-memory engine the redesign's Hooks shots read (`HooksFrameShots`): the reference mock's Hook set (`src/a-core.js`
/// HOOKS, synthetic names only, S-R2) in each page state the fixture home cannot hold. Never used outside shot mode.
final class HooksShotCore: CoreService, @unchecked Sendable {
    enum Scenario: String, CaseIterable, Sendable {
        /// The mock's set at 2 CLIs.
        case normal
        /// The same set with the registry at 10 CLIs (RD-R10: one shape).
        case many
        /// No Hook in any CLI.
        case empty
        /// The usage scan never ends: rows with pending Runs.
        case scanning
        /// `~/.codex` unreadable: Codex cells unknown, the banner.
        case error
        /// `loadout.rows` refused: nothing read.
        case failed
        /// The mock's break-ui data (`src/x-data.js`): long commands, huge counts, emoji, 60 rows.
        case worst
        /// A removal the core refuses (the mock's `writefail`).
        case refused
    }

    let scenario: Scenario
    private let lock = NSLock()
    /// Members a shot removed: the next `loadout.rows` leaves them out, as the real core would.
    private var removed: Set<String> = []

    init(_ scenario: Scenario) { self.scenario = scenario }

    private func refuse(_ method: String) -> CoreError { CoreError("\(method) is not served in a shot.", status: 501) }

    // MARK: Reads

    func initialize() async throws -> CoreInitializeResult { throw refuse("initialize") }

    func clisRegistry() async throws -> CoreRegistryResult { CoreRegistryResult(clis: scenario == .many ? Self.registry10 : Self.registry2) }

    func inventoryRead() async throws -> CoreInventorySnapshot {
        CoreInventorySnapshot(items: [], hooks: [], problems: [], events: Self.events, roots: Self.roots)
    }

    func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        if scenario == .scanning { try await Task.sleep(for: .seconds(3600)) }
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }

    func loadoutRows() async throws -> CoreLoadoutRows {
        if scenario == .failed { throw CoreError("~/.claude/settings.json and ~/.codex/hooks.json could not be read.", status: 500) }
        let registry = scenario == .many ? Self.registry10 : Self.registry2
        let hooks: [CoreInventoryHook] = switch scenario {
        case .empty: []
        case .worst: Self.worst
        case .error: Self.sample.filter { $0.cli == .claude }.map { Self.withCodex($0, .unknown) }
        default: Self.sample
        }
        let gone = lock.withLock { removed }
        return CoreLoadoutRows(usage: scenario == .scanning ? .scanning : .ready, items: [],
                               hooks: hooks.filter { !gone.contains($0.id) }.map { Self.filled($0, registry: registry) },
                               problems: [], events: Self.events, roots: Self.roots, countsByScope: [:], rowFlags: [:])
    }

    func activityRead() async throws -> CoreActivityReport { Self.noActivity }
    func activitySubscribe() -> AsyncThrowingStream<CoreActivityReport, Error> {
        AsyncThrowingStream { $0.yield(Self.noActivity) }
    }
    func activityStop(cli: CoreCLI, id: String) async throws -> CoreStopResult { throw refuse("activity.stop") }
    func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    func limitsRead() async throws -> CoreLimitsResult { CoreLimitsResult(limits: []) }
    func rulesSnapshot(scope: CoreRuleScope, dir: String?, refreshProjects: Bool) async throws -> CoreRulesSnapshot { throw refuse("rules.snapshot") }

    // MARK: Writes

    func loadoutRemoveItem(id: String) async throws -> CoreEntryResult {
        if scenario == .refused {
            throw CoreError("Couldn\u{2019}t remove lint-staged.sh: ~/.claude/settings.json changed since SpaceVibe read it. Nothing changed.", status: 409)
        }
        _ = lock.withLock { removed.insert(id) }
        return CoreEntryResult(entry: CoreJournalEntry(id: "shot-1", at: "2026-11-21T10:00:00.000Z", label: "Removed PreToolUse hook from Claude Code",
                                                       undone: false, count: 1))
    }

    func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult {
        if scenario == .refused {
            throw CoreError("Couldn\u{2019}t remove lint-staged.sh: ~/.claude/settings.json changed since SpaceVibe read it. Nothing changed.", status: 409)
        }
        lock.withLock { removed.formUnion(ids) }
        return CoreRemoveManyResult(entry: CoreJournalEntry(id: "shot-1", at: "2026-11-21T10:00:00.000Z", label: "Removed hook", undone: false, count: 1),
                                    lost: ["claude"])
    }

    func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult { throw refuse("loadout.copyTo") }
    func loadoutRemoveFrom(id: String, clis: [String]) async throws -> CoreRemoveFromResult { throw refuse("loadout.removeFrom") }
    func rulesRemoveMany(scope: CoreRuleScope, dir: String?, ids: [String]) async throws -> CoreEntryResult { throw refuse("rules.removeMany") }
    func findingsKept() async throws -> CoreKeptFindings { CoreKeptFindings(kept: []) }
    func findingsKeep(id: String) async throws -> CoreEntryResult { throw refuse("findings.keep") }
    func findingsUnkeep(id: String) async throws -> CoreEntryResult { throw refuse("findings.unkeep") }
    func loadoutCopyToOther(id: String) async throws -> CoreEntryResult { throw refuse("loadout.copyToOther") }
    func loadoutRemoveDeadHooks(cli: CoreCLI) async throws -> CoreEntryResult { throw refuse("loadout.removeDeadHooks") }
    func journalUndo(id: String) async throws -> CoreUndoResult { throw refuse("journal.undo") }
    func rulesPreview(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreCapabilityPreview { throw refuse("rules.preview") }
    func rulesSetCapability(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreSetCapabilityResult { throw refuse("rules.setCapability") }
    func rulesAdd(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult { throw refuse("rules.add") }
    func rulesRemove(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult { throw refuse("rules.remove") }
    func rulesChangeVerdict(scope: CoreRuleScope, dir: String?, rule: String, from: CoreVerdict, to: CoreVerdict) async throws -> CoreEntryResult { throw refuse("rules.changeVerdict") }
    func rulesChangeVerdicts(scope: CoreRuleScope, dir: String?, to: CoreVerdict, rules: [CoreRuleMove]) async throws -> CoreEntryResult { throw refuse("rules.changeVerdicts") }
    func rulesCheck(rule: String) async throws -> CoreRuleCheck { throw refuse("rules.check") }

    // MARK: Data

    private static let noActivity = CoreActivityReport(sessions: [], failures: [], files: [], unmeasurable: [], stats: CoreActivityStats(logs: 0, truncated: 0))
    private static let roots = ["claude": "~/.claude", "codex": "~/.codex"]
    private static let events: [String: [String]] = [
        "claude": ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "PostToolUseFailure", "Notification",
                   "SubagentStart", "SubagentStop", "Elicitation", "ElicitationResult", "TeammateIdle", "PreCompact", "PostCompact", "Stop",
                   "StopFailure", "SessionEnd"],
        "codex": ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "SubagentStart", "SubagentStop",
                  "Interrupt", "Stop", "SessionEnd"],
    ]

    private static func supports(hook: Bool, logs: Bool = true) -> CoreRegistrySupports {
        CoreRegistrySupports(skill: true, agent: true, hook: hook, rule: false, logs: logs, limits: false)
    }

    static let registry2 = [
        CoreRegistryCLI(id: "claude", name: "Claude Code", supports: CoreRegistrySupports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)),
        CoreRegistryCLI(id: "codex", name: "Codex", supports: CoreRegistrySupports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)),
    ]

    /// Eight synthetic CLIs after the two read today (RD13's 10-CLI preset): every other one without Hooks.
    static let registry10 = registry2 + (2..<10).map { index in
        CoreRegistryCLI(id: "cli\(index)", name: "Sample CLI \(index)", supports: supports(hook: index % 2 == 0, logs: index % 3 != 0))
    }

    private static func week(_ errors: Int) -> [CoreHookDay] {
        (1...7).map { CoreHookDay(day: "2026-11-\(14 + $0)", runs: 1, errors: $0 == 7 ? errors : 0) }
    }

    private static func counted(_ runs: Int, errors: Int = 0, last7: Int = 0, last: String? = "2026-11-21", note: String? = nil) -> CoreCLICells {
        ["claude": .runs(count: runs, errors: errors, last: runs > 0 ? last : nil, note: note, week: week(last7)), "codex": .missing]
    }

    private static let codexUnmeasurable: CoreCLICells = ["claude": .missing, "codex": .unmeasurable(reason: "Codex logs no hook runs")]

    private static func hook(_ hash: String, cli: CoreCLI = .claude, event: String, matcher: String? = nil, command: String, dead: Bool = false,
                             project: String? = nil, avg: Int? = nil, cells: CoreCLICells) -> CoreInventoryHook {
        let file = project.map { "\($0)/.claude/settings.json" } ?? (cli == .claude ? "~/.claude/settings.json" : "~/.codex/hooks.json")
        return CoreInventoryHook(
            id: "\(cli.rawValue):hook:\(hash)", cli: cli, kind: .hook, event: event, matcher: matcher, command: command, timeout: nil, async: false,
            owner: "user", removable: project == nil, dead: dead, paths: [], hash: hash, file: file, scope: project == nil ? .global : .project,
            project: project, key: "hook:\(project ?? ""):\(hash)", cells: nil, cliCells: cells,
            usage: avg.map { CoreHookUsage(runs: 1, avgMs: $0, totalMs: 0, errors: 0, last: nil) }
        )
    }

    /// The mock's HOOKS, in its order.
    static let sample: [CoreInventoryHook] = [
        hook("h1", event: "PreToolUse", matcher: "Bash", command: "~/.claude/hooks/lint-staged.sh", dead: true, cells: counted(0)),
        hook("h2", event: "Stop", command: "~/bin/notify-done.sh", dead: true, cells: counted(0)),
        hook("h3", event: "PreToolUse", matcher: "Bash", command: "python3 ~/.claude/hooks/guard.py", avg: 38, cells: counted(1204, errors: 6)),
        hook("h4", event: "PostToolUse", matcher: "Edit|Write", command: "~/.claude/hooks/post-edit-format.sh", avg: 214, cells: counted(812, errors: 14, last7: 14)),
        hook("h5", event: "SessionStart", command: "~/.claude/hooks/load-context.sh", avg: 120, cells: counted(96)),
        hook("h6", event: "UserPromptSubmit", command: "~/.claude/hooks/prompt-log.sh", cells: counted(0)),
        hook("h7", event: "Notification", command: "osascript -e 'display notification \"Done\"'", avg: 61, cells: counted(45)),
        hook("h8", cli: .codex, event: "PreToolUse", matcher: "shell", command: "~/.codex/hooks/guard.sh", cells: codexUnmeasurable),
        hook("h12", event: "PostToolUse", matcher: "Edit", command: "$CLAUDE_PROJECT_DIR/.claude/hooks/lint.sh", project: "~/work/payments-web",
             avg: 90, cells: counted(22, last: "2026-11-20")),
        hook("h9", cli: .codex, event: "SessionStart", command: "~/.codex/hooks/load-context.sh", cells: codexUnmeasurable),
    ]

    /// The mock's break-ui changes (`src/x-data.js`) plus 50 more Hooks spread over every event.
    static let worst: [CoreInventoryHook] = {
        var hooks = sample
        hooks[0] = hook("h1", event: "PreToolUse", matcher: "Edit|Write|MultiEdit|NotebookEdit", command: "sh '$HOME/.claude/scripts/block-env-edit.sh'", dead: true, cells: counted(0))
        hooks[1] = hook("h2", event: "Stop", command: "sh '$HOME/bin/format-on-save.sh' --fix", dead: true, cells: counted(0))
        hooks[2] = hook("h3", event: "PreToolUse", matcher: "mcp__github__.*",
                        command: "python3 ~/.claude/hooks/guard.py --deny 'rm -rf' --deny 'git push --force' --log ~/Library/Logs/claude-guard/guard.jsonl",
                        avg: 38, cells: counted(4_830_112, errors: 6))
        hooks[3] = hook("h4", event: "PostToolUse", matcher: "Edit|Write", command: "~/.claude/hooks/post-edit-format.sh", avg: 18342, cells: counted(1, errors: 1, last7: 1))
        hooks[4] = hook("h5", event: "SessionStart",
                        command: "bash -c 'cd \"$CLAUDE_PROJECT_DIR\" && npx --yes prettier@3.3.3 --write \"$(jq -r .tool_input.file_path)\" 2>/dev/null || true'",
                        avg: 120, cells: counted(96))
        hooks[5] = hook("h6", event: "UserPromptSubmit", command: "node \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/prompt-log.mjs", cells: counted(0))
        hooks[6] = hook("h7", event: "Notification", command: "osascript -e 'display notification \"Xong r\u{1EDD}i \u{1F389}\" with title \"Claude Code\"'", avg: 61, cells: counted(45))
        let all = events["claude"] ?? []
        hooks += (0..<50).map { index in
            hook("w\(index)", event: all[index % all.count], command: "~/.claude/hooks/a-very-long-hook-name-that-keeps-going-\(index).sh",
                 avg: 10 + index, cells: counted(index * 37))
        }
        return hooks
    }()

    private static func withCodex(_ hook: CoreInventoryHook, _ cell: CoreCLICell) -> CoreInventoryHook {
        var copy = hook
        copy.cliCells?["codex"] = cell
        return copy
    }

    /// One cell per registry CLI, as the core sends: Missing, or Not supported for a CLI without Hooks.
    private static func filled(_ hook: CoreInventoryHook, registry: [CoreRegistryCLI]) -> CoreInventoryHook {
        var copy = hook
        for cli in registry where copy.cliCells?[cli.id] == nil { copy.cliCells?[cli.id] = cli.supports.hook ? .missing : .notSupported }
        return copy
    }
}
