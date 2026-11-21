import Foundation
import Testing
@testable import SpaceVibe

/// The redesign's Rules page model (RB-R4): what the page shows in each state, the hero counting every file and saying where,
/// the capability rows, which actions are offered, and the other CLIs read only in their own terms. Pure: built from
/// snapshots, no store.
@Suite("Rules frame model")
struct RulesFrameModelTests {
    typealias D = FrameTestData

    static let dir = "/p/payments-web"
    static let shared = FrameScope.shared(dir), local = FrameScope.local(dir)

    private func snapshot(global: [CoreRule], shared: [CoreRule]? = nil, local: [CoreRule]? = nil, projects: [String] = [dir],
                          grid: [CoreCapabilityCell] = [], codex: CoreCodexPermissions = D.codex, registry: [CoreRegistryCLI] = D.registry,
                          problems: [String] = []) -> FrameSnapshot {
        var snap = D.snapshot(D.loadout(), registry: registry)
        var g = D.rules(global, projects: projects)
        g.grid = grid
        g.codex = codex
        g.problems = problems
        snap.rules = [.global: g]
        if let shared { snap.rules[Self.shared] = D.rules(shared, file: Self.shared, projects: projects) }
        if let local { snap.rules[Self.local] = D.rules(local, file: Self.local, projects: projects) }
        return snap
    }

    private func model(_ snap: FrameSnapshot, file: FrameScope = .global, view: RulesViewState = RulesViewState(),
                       states: [FrameSource: FrameSourceState] = [:]) -> RulesListModel {
        let world = FrameWorld(snapshot: snap, now: D.now)
        let loading = Set(states.filter { $0.value == .loading }.keys)
        let failed = Set(states.filter { if case .failed = $0.value { true } else { false } }.keys)
        return RulesListModel(world: world, states: states, file: file, view: view,
                              figure: world.figure(for: .rules, loading: loading, failed: failed))
    }

    @Test("the hero counts every file's whole-tool allows and says where; the sidebar reads the same figure")
    func heroEveryFile() {
        let snap = snapshot(global: [D.rule("Bash", wide: true), D.rule("Read(~/Documents/**)"), D.rule("mcp__github__create_issue")],
                            shared: [], local: [D.rule("Bash", file: Self.local, wide: true)])
        let list = model(snap)
        #expect(list.hero == .value("2", unit: nil))
        #expect(list.heroLabel == "rules allow a whole tool \u{00B7} 1 in Global, 1 in a project")
        let world = FrameWorld(snapshot: snap, now: D.now)
        #expect(FrameSidebarValue(figure: world.figure(for: .rules, loading: [], failed: []), page: .rules).text == "2")
    }

    @Test("one global rule: the singular, no where; none: 0 rules")
    func heroWording() {
        #expect(model(snapshot(global: [D.rule("Bash", wide: true)])).heroLabel == "rule allows a whole tool")
        let none = model(snapshot(global: [D.rule("Bash(git status:*)")]))
        #expect(none.hero == .value("0", unit: nil) && none.heroLabel == "rules allow a whole tool")
    }

    @Test("a bare MCP tool name is never a whole-tool rule, and a deny of a whole tool is not an allow (RD-R17 Honesty)")
    func honesty() {
        let list = model(snapshot(global: [D.rule("mcp__github__create_issue"), D.rule("Bash", verdict: .deny, wide: true)]))
        #expect(list.rows.allSatisfy { !$0.isWideAllow })
        #expect(list.hero == .value("0", unit: nil))
    }

    @Test("the hero waits for the global file and is Unmeasurable when it failed")
    func heroStates() {
        var snap = snapshot(global: [])
        snap.rules = [:]
        #expect(model(snap, states: [.rules(.global): .loading]).hero == .scanning)
        let failed = model(snap, states: [.rules(.global): .failed("no")])
        #expect(failed.hero == .unmeasurable && failed.phase == .failed("no") && failed.primary == .none)
    }

    @Test("phases: loading, empty with no primary in the toolbar, normal with Add Rule…")
    func phases() {
        #expect(model(snapshot(global: []), file: Self.shared).phase == .loading)
        let empty = model(snapshot(global: []))
        #expect(empty.phase == .empty && empty.primary == .none && empty.isWritable)
        let normal = model(snapshot(global: [D.rule("Bash", wide: true)]))
        #expect(normal.phase == .normal && normal.primary == .addRule)
    }

    @Test("Project with no project known says so; a project no longer listed is not read as global")
    func projects() {
        let none = model(snapshot(global: [], projects: []), view: RulesViewState(wantsProjects: true))
        #expect(none.phase == .noProjects && !none.isGlobal)
        let gone = model(snapshot(global: [], projects: ["/other"]), file: Self.shared)
        #expect(gone.phase == .projectGone && gone.rows.isEmpty)
    }

    @Test("a project file: its own rules, its name, Shared and Local in the scope title and the file name")
    func projectFile() {
        let snap = snapshot(global: [D.rule("Read")], shared: [D.rule("Bash(pnpm test:*)", file: Self.shared)],
                            local: [D.rule("Bash", file: Self.local, wide: true)])
        let shared = model(snap, file: Self.shared)
        #expect(shared.rows.map(\.rule.rule) == ["Bash(pnpm test:*)"])
        #expect(shared.fileName == "payments-web/.claude/settings.json" && shared.scopeTitle == "Project \u{00B7} payments-web \u{00B7} Shared")
        let local = model(snap, file: Self.local)
        #expect(local.fileName == "payments-web/.claude/settings.local.json" && local.rows.first?.isWideAllow == true)
    }

    @Test("rows sort by rule; ticks count only rows shown; Remove N selected replaces Add Rule…")
    func ticks() {
        let snap = snapshot(global: [D.rule("Read"), D.rule("Bash", wide: true), D.rule("Edit(~/.ssh/**)", verdict: .deny)])
        var view = RulesViewState()
        view.ticked = ["global:allow:Bash", "global:allow:Read", "project:allow:Gone"]
        let list = model(snap, view: view)
        #expect(list.rows.map(\.rule.rule) == ["Bash", "Edit(~/.ssh/**)", "Read"])
        #expect(list.removal.map(\.rule) == ["Bash", "Read"] && list.primary == .removeSelected(2))
    }

    @Test("a file that does not parse: the band, nothing writable, no dial pressable, no row action")
    @MainActor
    func problem() {
        let cell = CoreCapabilityCell(capability: .run, label: "Run commands", state: .allow, editable: true, rules: [D.rule("Bash", wide: true)])
        let list = model(snapshot(global: [D.rule("Bash", wide: true)], grid: [cell], problems: ["~/.claude/settings.json is not valid JSON."]))
        #expect(list.problem == "~/.claude/settings.json is not valid JSON.")
        #expect(!list.isWritable && list.primary == .none && list.capabilities.allSatisfy { !$0.isEditable })
        #expect(RulesFrame.actions(for: list.rows[0], list: list, state: RulesPageState()).isEmpty)
    }

    @Test("capability rows: Mixed says which rules disagree and is locked; others count their rules")
    func capabilities() {
        let run = CoreCapabilityCell(capability: .run, label: "Run commands", state: .mixed, editable: false,
                                     rules: [D.rule("Bash", wide: true), D.rule("Bash(rm -rf:*)", verdict: .deny), D.rule("Bash(pnpm test:*)")])
        let push = CoreCapabilityCell(capability: .push, label: "Push and deploy", state: .mixed, editable: false,
                                      rules: [D.rule("Bash", wide: true), D.rule("Bash(git push:*)", verdict: .ask)])
        let edit = CoreCapabilityCell(capability: .edit, label: "Edit files", state: .ask, editable: true, rules: [D.rule("Edit", verdict: .ask, wide: true)])
        let network = CoreCapabilityCell(capability: .network, label: "Network", state: .none, editable: true, rules: [])
        let rows = model(snapshot(global: [D.rule("Bash", wide: true)], grid: [run, push, edit, network])).capabilities
        #expect(rows[0].why == "Read-only: any: allow \u{00B7} scoped: allow/deny" && rows[0].isMixed && !rows[0].isEditable && rows[0].selection == nil)
        #expect(rows[1].why == "Read-only: any: allow \u{00B7} own: ask")
        #expect(rows[2].why == "1 rule" && rows[2].selection == .ask && rows[2].isEditable && rows[2].icon == .fileText)
        #expect(rows[3].why == "No rules" && rows[3].selection == nil)
    }

    @Test("actions: a whole-tool allow gets Change to Ask and a red Remove Rule; any other rule a quiet Remove Rule only")
    @MainActor
    func actions() {
        let list = model(snapshot(global: [D.rule("Bash", wide: true), D.rule("Bash(git status:*)")]))
        let state = RulesPageState()
        let wide = RulesFrame.actions(for: list.rows[0], list: list, state: state)
        #expect(wide.map(\.title) == ["Change to Ask", "Remove Rule"] && wide[1].isDestructive)
        #expect(RulesFrame.rowButtons(wide).map(\.title) == ["Remove Rule"])
        let narrow = RulesFrame.actions(for: list.rows[1], list: list, state: state)
        #expect(narrow.map(\.title) == ["Remove Rule"] && !narrow[0].isDestructive)
    }

    @Test("the CLI pop-up: Claude Code editable, Codex read only, a CLI without Rules disabled; an unsupported pick falls back")
    func cliPicker() {
        let registry = D.registry + [D.cli("cursor", supports: CoreRegistrySupports(skill: true, agent: true, hook: false, rule: false, logs: true, limits: false))]
        var view = RulesViewState()
        view.cli = "cursor"
        let list = model(snapshot(global: [], registry: registry), view: view)
        #expect(list.isClaudePage)
        let entries = CLIMenuEntries.picker(list.cliOptions, chosen: list.cli.id)
        #expect(entries.map(\.note) == [nil, "Read only", "Not supported"] && entries.map(\.isEnabled) == [true, true, false])
    }

    @Test("at 10 CLIs: three lines beside the hero and +N more; a CLI with no reading is Unmeasurable, never a stance")
    func manyCLIs() {
        let list = model(snapshot(global: [], registry: D.registry + (2..<10).map { D.cli("cli\($0)") }))
        #expect(list.others.count == 9 && list.shownSummaries.count == 3 && list.hiddenSummaryCount == 6)
        let other = list.others[1]
        #expect(other.hero == .unmeasurable && other.line == "Unmeasurable" && other.facts.isEmpty && other.source == nil)
    }

    static let codex = CoreCodexPermissions(
        present: true, model: .legacy, unrestricted: false, warnings: [], approvalPolicy: .mode("on-request"), sandboxMode: "workspace-write",
        sandboxWorkspaceWrite: CoreWorkspaceWrite(networkAccess: false, writableRoots: []), defaultPermissions: nil, approvalsReviewer: nil,
        profiles: [], projects: [CoreCodexProject(path: "/a", trustLevel: "trusted"), CoreCodexProject(path: "/b", trustLevel: nil)],
        rules: CoreCodexRulesSummary(files: 1, allow: 3, prompt: 1, forbidden: 0, other: 0, unreadable: 0, folderNotReadable: false),
        notReadable: false, skippedLines: 0)

    @Test("Codex in its own terms: the sandbox word as the hero, the approval policy, the settings as Codex names them")
    func codexPage() {
        var view = RulesViewState()
        view.cli = "codex"
        let list = model(snapshot(global: [], codex: Self.codex), view: view)
        let page = try! #require(list.readOnly)
        #expect(!list.isClaudePage && list.primary == .none)
        #expect(page.hero == .value("workspace-write", unit: nil) && page.heroLabel == "sandbox \u{00B7} asks on request")
        #expect(page.line == "on-request \u{00B7} workspace-write")
        #expect(page.facts.map(\.key) == ["Approval policy", "Sandbox", "Network access", "Trusted projects", "Command rules"])
        #expect(page.facts.map(\.value) == ["on-request", "workspace-write", "off", "1", "3 allow \u{00B7} 1 prompt \u{00B7} 0 forbidden"])
        #expect(page.source == "Read from ~/.codex/config.toml. Shown only, never edited.")
    }

    @Test("Codex unreadable: Unmeasurable with the band; a secret-looking value is never shown")
    func codexUnreadable() {
        var unreadable = Self.codex
        unreadable.notReadable = true
        let page = RulesReadOnlyPage.of(D.registry[1], global: snapshot(global: [], codex: unreadable).rules[.global], state: .ready)
        #expect(page.hero == .unmeasurable && page.banner?.title == "Codex settings could not be read" && page.line == "Unmeasurable")
        var secret = Self.codex
        secret.sandboxMode = "sk-live-1234567890abcdefXYZ"
        let shown = RulesReadOnlyPage.of(D.registry[1], global: snapshot(global: [], codex: secret).rules[.global], state: .ready)
        #expect(shown.hero == .value(CodexWording.hiddenText, unit: nil))
    }

    @Test("approval phrases follow Codex's AskForApproval")
    func approvalPhrases() {
        #expect(RulesReadOnlyPage.approvalPhrase("on-failure") == "asks on request")
        #expect(RulesReadOnlyPage.approvalPhrase("never") == "never asks")
        #expect(RulesReadOnlyPage.approvalPhrase(nil) == "approval not set")
    }
}

/// The capability preview's words (`rules.preview`, which writes nothing) and the blocks the page added.
@Suite("Rules preview wording")
struct RulesPreviewWordingTests {
    typealias D = FrameTestData

    private func row(_ capability: CoreCapability, label: String, state: CoreCapabilityState, rules: [CoreRule]) -> RulesCapabilityRow {
        RulesCapabilityRow(cell: CoreCapabilityCell(capability: capability, label: label, state: state, editable: true, rules: rules), isEditable: true)
    }

    private func preview(_ capability: CoreCapability, _ verdict: CoreVerdict, resulting: CoreCapabilityState,
                         replaces: [CoreVerdictRule], writes: [CoreVerdictRule]) -> CoreCapabilityPreview {
        CoreCapabilityPreview(capability: capability, verdict: verdict, scopeLabel: "~/.claude/settings.json", current: .ask,
                              resulting: resulting, replaces: replaces, writes: writes)
    }

    @Test("a change names the rules, the file, and that path and command rules stay")
    func change() {
        let push = row(.push, label: "Push and deploy", state: .ask, rules: [D.rule("Bash(git push:*)", verdict: .ask)])
        let text = RulesPreviewText(row: push, preview: preview(.push, .deny, resulting: .deny,
                                                                replaces: [CoreVerdictRule(verdict: .ask, rule: "Bash(git push:*)")],
                                                                writes: [CoreVerdictRule(verdict: .deny, rule: "Bash(git push:*)")]),
                                    fileName: "~/.claude/settings.json")
        #expect(text.title == "Push and deploy \u{2192} Deny")
        #expect(text.what == "Changes Bash(git push:*) to Deny in ~/.claude/settings.json. Path and command rules stay.")
        #expect(text.warning == nil && !text.isNothing && text.confirmTitle == "Change to Deny")
        #expect(text.doneLabel == "Push and deploy: Bash(git push:*) now Deny in ~/.claude/settings.json")
    }

    @Test("an empty cell adds its bare rule; the cell still reading Mixed names the rule that keeps it so")
    func addAndMixed() {
        let run = row(.run, label: "Run commands", state: .none, rules: [D.rule("Bash(rm -rf:*)", verdict: .deny)])
        let text = RulesPreviewText(row: run, preview: preview(.run, .allow, resulting: .mixed, replaces: [],
                                                               writes: [CoreVerdictRule(verdict: .allow, rule: "Bash")]),
                                    fileName: "f")
        #expect(text.what == "Adds Bash as Allow in f. Path and command rules stay.")
        #expect(text.warning == "The cell will read Mixed, because Bash(rm -rf:*) (deny) still applies.")
    }

    @Test("a same-value press is Nothing to change, and the button is disabled")
    func nothing() {
        let push = row(.push, label: "Push and deploy", state: .ask, rules: [D.rule("Bash(git push:*)", verdict: .ask)])
        let same = [CoreVerdictRule(verdict: .ask, rule: "Bash(git push:*)")]
        let text = RulesPreviewText(row: push, preview: preview(.push, .ask, resulting: .ask, replaces: same, writes: same), fileName: "f")
        #expect(text.isNothing && text.confirmTitle == "Nothing to change")
        #expect(text.what == "Nothing to change: the rules of this cell already say Ask.")
    }

    @Test("write wording and the Add Rule line before anything is written")
    func wording() {
        let rule = D.rule("Bash", wide: true)
        #expect(RulesWriteWording.changed(rule, to: .ask, in: "f") == "Changed Bash from Allow to Ask in f")
        // The mock's `removeIds` toast: what went, then the file that was edited.
        #expect(RulesWriteWording.removed([rule], from: "~/.claude/settings.json") == "Removed Rule Bash. settings.json was edited")
        #expect(RulesWriteWording.removed([rule, rule], from: "~/p/.claude/settings.local.json") == "Removed 2 Rules. settings.local.json was edited")
        #expect(RulesWriteWording.addPreview("  Bash(git log:*) ", as: .ask, to: "f") == "Writes Bash(git log:*) as Ask to f.")
    }

    @Test("blocks: the dial's words and the field's refusal hint")
    func blocks() {
        #expect(CoreVerdict.allCases.map(PermissionDial.title) == ["Allow", "Ask", "Deny"])
        #expect(PermissionDial.spoken(label: "Network", selection: nil) == "Network, not set")
        #expect(TextInputField.hint("Already there.") == "Not taken: Already there." && TextInputField.hint(nil).isEmpty)
    }
}
