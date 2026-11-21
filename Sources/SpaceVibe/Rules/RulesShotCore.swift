import Foundation

/// The in-memory engine the redesign's Rules shots read (`RulesFrameShots`): the reference mock's rule sets
/// (`src/a-core.js` RULES and PROJ_RULES, synthetic names only, S-R2) and Codex settings (CLI_RULES.codex), in each page
/// state the fixture home cannot hold. The grid cells are fixed per file, as the engine would answer for these rules
/// (design-notes B4: Read, Edit, Run, Network Mixed, Push Ask, Secrets Deny); writes answer a Journal entry or refuse and
/// change nothing. Never used outside shot mode.
final class RulesShotCore: CoreService, @unchecked Sendable {
    enum Scenario: String, CaseIterable, Sendable {
        case normal, many, empty, scanning, failed, worst, refused
        /// `~/.claude/settings.json` does not parse: the band, the grid and the list read only.
        case problem
        /// `~/.codex/config.toml` could not be read.
        case codexError
        /// Claude Code knows no project.
        case noProjects
    }

    let scenario: Scenario

    init(_ scenario: Scenario) { self.scenario = scenario }

    private func refuse(_ method: String) -> CoreError { CoreError("\(method) is not served in a shot.", status: 501) }
    private static let refusal = "Couldn\u{2019}t change Bash: ~/.claude/settings.json changed since SpaceVibe read it. Nothing changed."

    // MARK: Reads

    func initialize() async throws -> CoreInitializeResult { throw refuse("initialize") }
    func clisRegistry() async throws -> CoreRegistryResult { CoreRegistryResult(clis: scenario == .many ? Self.registry10 : HooksShotCore.registry2) }

    /// RD13's 10-CLI preset: every other synthetic CLI has Rules (read only, no reading: Unmeasurable), the rest are Not
    /// supported in the CLI pop-up. Five other CLIs with Rules: three lines beside the hero and `+2 more CLIs`.
    static let registry10 = HooksShotCore.registry2 + (2..<10).map { index in
        CoreRegistryCLI(id: "cli\(index)", name: "Sample CLI \(index)",
                        supports: CoreRegistrySupports(skill: true, agent: true, hook: false, rule: index % 2 == 0, logs: true, limits: false))
    }
    // The other pages' sources answer empty, so the sidebar reads zeros rather than Unmeasurable.
    func inventoryRead() async throws -> CoreInventorySnapshot { CoreInventorySnapshot(items: [], hooks: [], problems: [], events: [:], roots: [:]) }
    func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }
    func loadoutRows() async throws -> CoreLoadoutRows {
        CoreLoadoutRows(usage: .ready, items: [], hooks: [], problems: [], events: [:], roots: [:], countsByScope: [:], rowFlags: [:])
    }
    func activityRead() async throws -> CoreActivityReport { Self.noActivity }
    func activitySubscribe() -> AsyncThrowingStream<CoreActivityReport, Error> { AsyncThrowingStream { $0.yield(Self.noActivity) } }
    private static let noActivity = CoreActivityReport(sessions: [], failures: [], files: [], unmeasurable: [], stats: CoreActivityStats(logs: 0, truncated: 0))
    func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    func limitsRead() async throws -> CoreLimitsResult { CoreLimitsResult(limits: []) }
    func findingsKept() async throws -> CoreKeptFindings { CoreKeptFindings(kept: []) }

    func rulesSnapshot(scope: CoreRuleScope, dir: String?, refreshProjects: Bool) async throws -> CoreRulesSnapshot {
        if scenario == .scanning { try await Task.sleep(for: .seconds(3600)) }
        if scenario == .failed { throw CoreError("The core could not read ~/.claude/settings.json.", status: 500) }
        let file = FrameScope(scope: scope, dir: dir)
        let texts = scenario == .empty ? [] : Self.rules(file, worst: scenario == .worst)
        let rules = texts.map { Self.rule($0.1, verdict: $0.0, file: file) }
        let invalid = scenario == .problem && file == .global
        return CoreRulesSnapshot(
            projectDirs: scenario == .noProjects ? [] : Self.projects.map(\.dir), globalRuleCount: Self.globalRules.count, scope: scope, dir: dir,
            fileLabel: file == .global ? "~/.claude/settings.json" : ".claude/settings\(scope == .local ? ".local" : "").json",
            exists: true, problems: invalid ? ["~/.claude/settings.json is not valid JSON (line 14). Fix it in an editor; SpaceVibe changes nothing until then."] : [],
            rules: rules, grid: Self.grid(rules, file: file), codex: scenario == .codexError ? Self.codexUnreadable : Self.codex,
            notReadable: false, globalNotReadable: false)
    }

    func rulesPreview(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreCapabilityPreview {
        // Push and deploy holds `Bash(git push:*)` as Ask in the mock's set; any other cell adds its bare rule.
        let current = Self.states(FrameScope(scope: scope, dir: dir))[capability] ?? CoreCapabilityState.none
        let own = capability == .push ? [CoreVerdictRule(verdict: .ask, rule: "Bash(git push:*)")] : []
        let replaces = own
        let writes = own.isEmpty ? [CoreVerdictRule(verdict: verdict, rule: Self.bare[capability] ?? "Bash")] : own.map { CoreVerdictRule(verdict: verdict, rule: $0.rule) }
        return CoreCapabilityPreview(capability: capability, verdict: verdict, scopeLabel: "~/.claude/settings.json", current: current,
                                     resulting: CoreCapabilityState(rawValue: verdict.rawValue) ?? .mixed, replaces: replaces, writes: writes)
    }

    func rulesCheck(rule: String) async throws -> CoreRuleCheck {
        rule.contains("(") && !rule.hasSuffix(")")
            ? CoreRuleCheck(valid: false, message: "That rule has an opening parenthesis without a closing one.") : CoreRuleCheck(valid: true, message: nil)
    }

    // MARK: Writes

    private func entry(_ label: String) throws -> CoreEntryResult {
        if scenario == .refused { throw CoreError(Self.refusal, status: 409) }
        return CoreEntryResult(entry: CoreJournalEntry(id: "shot-1", at: "2026-11-21T10:00:00.000Z", label: label, undone: false, count: 1))
    }

    func rulesSetCapability(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreSetCapabilityResult {
        CoreSetCapabilityResult(entry: try entry("Set \(capability.rawValue)").entry)
    }

    func rulesAdd(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult {
        if Self.rules(FrameScope(scope: scope, dir: dir), worst: false).contains(where: { $0.1 == rule }) {
            throw CoreError("\(rule) is already in allow. Change its verdict instead.", status: 409)
        }
        return try entry("Added \(rule)")
    }

    func rulesChangeVerdict(scope: CoreRuleScope, dir: String?, rule: String, from: CoreVerdict, to: CoreVerdict) async throws -> CoreEntryResult {
        try entry("Changed \(rule)")
    }

    func rulesRemoveMany(scope: CoreRuleScope, dir: String?, ids: [String]) async throws -> CoreEntryResult { try entry("Removed rules") }
    func rulesRemove(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult { throw refuse("rules.remove") }
    func rulesChangeVerdicts(scope: CoreRuleScope, dir: String?, to: CoreVerdict, rules: [CoreRuleMove]) async throws -> CoreEntryResult { throw refuse("rules.changeVerdicts") }
    func activityStop(cli: CoreCLI, id: String) async throws -> CoreStopResult { throw refuse("activity.stop") }
    func loadoutCopyToOther(id: String) async throws -> CoreEntryResult { throw refuse("loadout.copyToOther") }
    func loadoutRemoveItem(id: String) async throws -> CoreEntryResult { throw refuse("loadout.removeItem") }
    func loadoutRemoveDeadHooks(cli: CoreCLI) async throws -> CoreEntryResult { throw refuse("loadout.removeDeadHooks") }
    func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult { throw refuse("loadout.copyTo") }
    func loadoutRemoveFrom(id: String, clis: [String]) async throws -> CoreRemoveFromResult { throw refuse("loadout.removeFrom") }
    func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult { throw refuse("loadout.removeMany") }
    func journalUndo(id: String) async throws -> CoreUndoResult { throw refuse("journal.undo") }
    func findingsKeep(id: String) async throws -> CoreEntryResult { throw refuse("findings.keep") }
    func findingsUnkeep(id: String) async throws -> CoreEntryResult { throw refuse("findings.unkeep") }

    // MARK: Data

    static let projects = [
        RulesProject(dir: "/Users/sample/Development/payments-web", name: "payments-web"),
        RulesProject(dir: "/Users/sample/Development/ledger-api", name: "ledger-api"),
        RulesProject(dir: "/Users/sample/Development/ui-kit", name: "ui-kit"),
    ]

    static let globalRules: [(CoreVerdict, String)] = [
        (.allow, "Bash"), (.allow, "Bash(git status:*)"), (.allow, "Bash(pnpm test:*)"), (.allow, "Read(~/Documents/**)"),
        (.allow, "WebFetch(domain:github.com)"), (.ask, "Bash(git push:*)"), (.ask, "Edit(~/Development/**)"), (.deny, "Read(./.env)"),
        (.deny, "Bash(rm -rf:*)"), (.deny, "Edit(~/.ssh/**)"),
    ]

    /// The mock's break-ui set (`src/x-data.js`): a long command rule, a bare MCP name (never a whole tool) and 116 more.
    static let worstExtra: [(CoreVerdict, String)] = [
        (.allow, "Bash(docker compose -f infra/docker-compose.override.yml run --rm migrate:*)"), (.allow, "mcp__github__create_pull_request"),
    ] + (0..<116).map { index in
        ([CoreVerdict.allow, .ask, .deny][index % 3], "Bash(pnpm --filter @northwind/package-\(String(format: "%03d", index)) test:*)")
    }

    static func rules(_ file: FrameScope, worst: Bool) -> [(CoreVerdict, String)] {
        switch (file.dir.flatMap { dir in projects.first { $0.dir == dir }?.name }, file.scope) {
        case (nil, _): globalRules + (worst ? worstExtra : [])
        case ("payments-web", .local): [(.allow, "Bash")]
        case ("payments-web", _): [(.allow, "Bash(pnpm test:*)"), (.ask, "Bash(pnpm db:migrate)"), (.deny, "Read(./.env.production)")]
        case ("ledger-api", .project): [(.allow, "Bash(cargo test:*)"), (.deny, "Bash(git push:*)")]
        default: []
        }
    }

    static func rule(_ text: String, verdict: CoreVerdict, file: FrameScope) -> CoreRule {
        let open = text.firstIndex(of: "(")
        let tool = open.map { String(text[..<$0]) } ?? text
        let specifier = open.map { String(text[text.index(after: $0)..<text.index(before: text.endIndex)]) }
        let wide = specifier == nil && ["Bash", "Read", "Edit", "Write", "MultiEdit", "NotebookEdit", "WebFetch", "WebSearch"].contains(tool)
        return CoreRule(id: "\(file.scope.rawValue):\(verdict.rawValue):\(text)", scope: file.scope, dir: file.dir, file: "settings.json",
                        verdict: verdict, rule: text, tool: tool, specifier: specifier, wide: wide)
    }

    private static let bare: [CoreCapability: String] = [.read: "Read", .edit: "Edit", .run: "Bash", .network: "WebFetch", .secrets: "Read(./.env)"]
    private static let labels: [CoreCapability: String] = [
        .read: "Read files", .edit: "Edit files", .run: "Run commands", .network: "Network", .push: "Push and deploy", .secrets: "Secrets",
    ]

    /// The states the engine gives these sets (design-notes B4 for the global one).
    static func states(_ file: FrameScope) -> [CoreCapability: CoreCapabilityState] {
        switch rules(file, worst: false).map(\.1) {
        case let texts where texts.contains("Read(~/Documents/**)"): [.read: .mixed, .edit: .mixed, .run: .mixed, .network: .mixed, .push: .ask, .secrets: .deny]
        case let texts where texts == ["Bash"]: [.run: .allow, .push: .allow]
        case let texts where texts.contains("Bash(pnpm db:migrate)"): [.run: .mixed, .secrets: .deny]
        case let texts where texts.contains("Bash(cargo test:*)"): [.run: .mixed, .push: .deny]
        default: [:]
        }
    }

    /// The cells with their rules placed as the engine places them (`grid.go`, simplified to these sets).
    static func grid(_ rules: [CoreRule], file: FrameScope) -> [CoreCapabilityCell] {
        let states = states(file)
        return CoreCapability.allCases.map { capability in
            let placed = rules.filter { place($0).contains(capability) }
            let state = states[capability] ?? (placed.isEmpty ? CoreCapabilityState.none : .mixed)
            return CoreCapabilityCell(capability: capability, label: labels[capability] ?? capability.rawValue, state: state,
                                      editable: state != .mixed, rules: placed)
        }
    }

    private static func place(_ rule: CoreRule) -> [CoreCapability] {
        let spec = rule.specifier ?? ""
        switch rule.tool {
        case "Read": return rule.wide == true ? [.read, .secrets] : spec.contains(".env") ? [.secrets] : [.read]
        case "Edit", "Write", "MultiEdit": return [.edit]
        case "Bash": return rule.wide == true ? [.run, .push] : spec.hasPrefix("git push") ? [.push] : [.run]
        case "WebFetch", "WebSearch": return [.network]
        default: return []
        }
    }

    static let codex = CoreCodexPermissions(
        present: true, model: .legacy, unrestricted: false, warnings: [], approvalPolicy: .mode("on-request"), sandboxMode: "workspace-write",
        sandboxWorkspaceWrite: CoreWorkspaceWrite(networkAccess: false, writableRoots: []), defaultPermissions: nil, approvalsReviewer: nil,
        profiles: [], projects: [CoreCodexProject(path: "/Users/sample/Development/ledger-api", trustLevel: "trusted"),
                                 CoreCodexProject(path: "/Users/sample/Development/ui-kit", trustLevel: "trusted")],
        rules: CoreCodexRulesSummary(files: 0, allow: 0, prompt: 0, forbidden: 0, other: 0, unreadable: 0, folderNotReadable: false),
        notReadable: false, skippedLines: 0)

    static let codexUnreadable = CoreCodexPermissions(
        present: true, model: .legacy, unrestricted: false, warnings: [], approvalPolicy: nil, sandboxMode: nil, sandboxWorkspaceWrite: nil,
        defaultPermissions: nil, approvalsReviewer: nil, profiles: [], projects: [],
        rules: CoreCodexRulesSummary(files: 0, allow: 0, prompt: 0, forbidden: 0, other: 0, unreadable: 0, folderNotReadable: false),
        notReadable: true, skippedLines: 0)
}
