import Foundation
import Testing
@testable import SpaceVibe

/// Serves the store's reads with a fixed rule set per file and records every Rules call with what it was sent, so a test
/// can say exactly which file each write went to. Writes answer an entry unless `refusal` is set.
final class RulesFakeCore: UnservedCore, @unchecked Sendable {
    typealias D = FrameTestData
    static let dir = "/p/payments-web"

    private let lock = NSLock()
    private var _calls: [String] = []
    var refusal: String?
    var check = CoreRuleCheck(valid: true, message: nil)
    var preview: CoreCapabilityPreview?

    var calls: [String] { lock.withLock { _calls } }
    func reset() { lock.withLock { _calls = [] } }
    /// The calls of one method, with their params.
    func sent(_ method: String) -> [String] { calls.filter { $0.hasPrefix(method + " ") } }

    private func record(_ line: String) { lock.withLock { _calls.append(line) } }
    private func answer(_ label: String) throws -> CoreEntryResult {
        if let refusal = lock.withLock({ refusal }) { throw CoreError(refusal, status: 409) }
        return CoreEntryResult(entry: D.entry("e1", label: label))
    }

    override func clisRegistry() async throws -> CoreRegistryResult { CoreRegistryResult(clis: D.registry) }
    override func inventoryRead() async throws -> CoreInventorySnapshot { CoreInventorySnapshot(items: [], hooks: [], problems: [], events: [:], roots: [:]) }
    override func loadoutRows() async throws -> CoreLoadoutRows { D.loadout() }
    override func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }
    override func limitsRead() async throws -> CoreLimitsResult { CoreLimitsResult(limits: []) }
    override func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    override func activityRead() async throws -> CoreActivityReport { D.activity([]) }
    override func activitySubscribe() -> AsyncThrowingStream<CoreActivityReport, Error> { AsyncThrowingStream { $0.yield(D.activity([])) } }
    override func findingsKept() async throws -> CoreKeptFindings { CoreKeptFindings(kept: []) }

    /// The global file's rules; nil is the default set.
    var globalRules: [CoreRule]?

    override func rulesSnapshot(scope: CoreRuleScope, dir: String?, refreshProjects: Bool) async throws -> CoreRulesSnapshot {
        let file = FrameScope(scope: scope, dir: dir)
        let rules = file == .global
            ? lock.withLock { globalRules } ?? [D.rule("Bash", wide: true), D.rule("Bash(git status:*)"), D.rule("Read(./.env)", verdict: .deny)]
            : [D.rule("Bash", file: file, wide: true)]
        var snap = D.rules(rules, file: file, projects: [Self.dir])
        snap.grid = [CoreCapabilityCell(capability: .push, label: "Push and deploy", state: .ask, editable: true, rules: [])]
        return snap
    }

    override func rulesPreview(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreCapabilityPreview {
        record("rules.preview \(scope.rawValue) \(dir ?? "") \(capability.rawValue) \(verdict.rawValue)")
        let same = [CoreVerdictRule(verdict: .ask, rule: "Bash(git push:*)")]
        return lock.withLock { preview } ?? CoreCapabilityPreview(
            capability: capability, verdict: verdict, scopeLabel: "~/.claude/settings.json", current: .ask,
            resulting: CoreCapabilityState(rawValue: verdict.rawValue) ?? .mixed, replaces: same,
            writes: verdict == .ask ? same : [CoreVerdictRule(verdict: verdict, rule: "Bash(git push:*)")])
    }
    override func rulesSetCapability(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreSetCapabilityResult {
        record("rules.setCapability \(scope.rawValue) \(dir ?? "") \(capability.rawValue) \(verdict.rawValue)")
        if let delay = lock.withLock({ capabilityDelay }) { try await Task.sleep(for: delay) }
        return CoreSetCapabilityResult(entry: try answer("Set").entry)
    }
    /// How long `rules.check` and `rules.setCapability` take before they answer: a sheet or a dial a test can press while
    /// they run.
    var checkDelay: Duration?
    var capabilityDelay: Duration?
    override func rulesChangeVerdict(scope: CoreRuleScope, dir: String?, rule: String, from: CoreVerdict, to: CoreVerdict) async throws -> CoreEntryResult {
        record("rules.changeVerdict \(scope.rawValue) \(dir ?? "") \(rule) \(from.rawValue) \(to.rawValue)")
        if let delay = lock.withLock({ verdictDelay }) { try await Task.sleep(for: delay) }
        return try answer("Changed")
    }
    /// How long `rules.changeVerdict` takes before it answers: a write a test can press again while it is pending.
    var verdictDelay: Duration?
    override func rulesRemoveMany(scope: CoreRuleScope, dir: String?, ids: [String]) async throws -> CoreEntryResult {
        record("rules.removeMany \(scope.rawValue) \(dir ?? "") \(ids)")
        return try answer("Removed")
    }
    override func rulesCheck(rule: String) async throws -> CoreRuleCheck {
        record("rules.check \(rule)")
        if let delay = lock.withLock({ checkDelay }) { try await Task.sleep(for: delay) }
        return lock.withLock { check }
    }
    override func rulesAdd(scope: CoreRuleScope, dir: String?, verdict: CoreVerdict, rule: String) async throws -> CoreEntryResult {
        record("rules.add \(scope.rawValue) \(dir ?? "") \(verdict.rawValue) \(rule)")
        return try answer("Added")
    }
}

/// The Rules page's writes, each through the one write path (AR4) to the file shown: every write path the page calls,
/// the preview before a capability change, the refusals and what each leaves on screen.
@Suite("Rules frame writes")
@MainActor
struct RulesFrameWritesTests {
    typealias D = FrameTestData

    private func setUp() async -> (RulesFakeCore, FrameModel, RulesPageState, ToastCenter) {
        let core = RulesFakeCore()
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: .rules))
        await model.store.start()
        core.reset()
        return (core, model, RulesPageState(model: model), toasts)
    }

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<300 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    @Test("a capability change previews first (rules.preview writes nothing), then rules.setCapability to that file, with Undo")
    func capability() async throws {
        let (core, model, state, toasts) = await setUp()
        let list = try #require(state.list())
        let push = try #require(list.capabilities.first)
        state.requestPreview(push, to: .deny)
        #expect(await eventually { if case .ready = state.preview?.phase { true } else { false } })
        #expect(core.calls == ["rules.preview global  push deny"])
        state.confirmPreview(push, fileName: list.fileName)
        #expect(await eventually { !core.sent("rules.setCapability").isEmpty && toasts.current != nil })
        #expect(core.sent("rules.setCapability") == ["rules.setCapability global  push deny"])
        #expect(toasts.current?.message == "Push and deploy: Bash(git push:*) now Deny in ~/.claude/settings.json")
        #expect(toasts.current?.action?.title == "Undo" && state.preview == nil)
        model.store.stop()
    }

    @Test("a same-value press reads Nothing to change and writes nothing")
    func nothingToChange() async throws {
        let (core, model, state, _) = await setUp()
        let list = try #require(state.list())
        let push = try #require(list.capabilities.first)
        state.requestPreview(push, to: .ask)
        #expect(await eventually { if case .ready = state.preview?.phase { true } else { false } })
        guard case .ready(let answer) = state.preview?.phase else { return }
        #expect(RulesPreviewText(row: push, preview: answer, fileName: list.fileName).isNothing)
        state.confirmPreview(push, fileName: list.fileName)
        try await Task.sleep(for: .milliseconds(30))
        #expect(core.sent("rules.setCapability").isEmpty && state.preview == nil)
        model.store.stop()
    }

    @Test("Change to Ask on a whole-tool allow: rules.changeVerdict from allow to ask in the file shown")
    func changeToAsk() async throws {
        let (core, model, state, toasts) = await setUp()
        let list = try #require(state.list())
        let bash = try #require(list.row("global::Bash"))
        try #require(RulesFrame.actions(for: bash, list: list, state: state).first).perform()
        #expect(await eventually { toasts.current != nil })
        #expect(core.sent("rules.changeVerdict") == ["rules.changeVerdict global  Bash allow ask"])
        #expect(toasts.current?.message == "Changed Bash from Allow to Ask in ~/.claude/settings.json")
        model.store.stop()
    }

    @Test("a second dial press while a verdict change is pending sends nothing, so no stale `from` reaches the core")
    func dialPressWhilePending() async throws {
        let (core, model, state, toasts) = await setUp()
        core.verdictDelay = .milliseconds(300)
        let list = try #require(state.list())
        // The row as the inspector drew it before the first write: it still says Allow on every press below.
        let bash = try #require(list.row("global::Bash")).rule
        model.router.select("global::Bash")
        state.change(bash, to: .ask, fileName: list.fileName)
        // The dial shows the step being written at once, and takes no press until the write is done.
        #expect(state.pendingVerdict(bash) == .ask && !PermissionDial.takesPress(pending: state.pendingVerdict(bash)))
        state.change(bash, to: .deny, fileName: list.fileName)
        try await Task.sleep(for: .milliseconds(60))
        state.change(bash, to: .deny, fileName: list.fileName)
        #expect(await eventually { toasts.current != nil && state.pendingVerdict(bash) == nil })
        #expect(core.sent("rules.changeVerdict") == ["rules.changeVerdict global  Bash allow ask"])
        #expect(PermissionDial.takesPress(pending: state.pendingVerdict(bash)))
        // The row id carries no verdict, so the changed rule stays selected.
        #expect(model.router.route.selection == "global::Bash")
        model.store.stop()
    }

    @Test("a verdict change and its Undo keep the rule selected: the row id carries the file and the text, not the verdict")
    func verdictChangeKeepsSelection() async throws {
        let (_, model, state, toasts) = await setUp()
        let list = try #require(state.list())
        let bash = try #require(list.row("global::Bash"))
        model.router.select(bash.id)
        state.change(bash.rule, to: .ask, fileName: list.fileName)
        #expect(await eventually { toasts.current != nil && state.pendingVerdict(bash.rule) == nil })
        var asked = bash.rule
        asked.verdict = .ask
        asked.id = "global:ask:Bash"
        #expect(RulesRuleRow.rowIDs([asked], in: .global) == RulesRuleRow.rowIDs([bash.rule], in: .global))
        #expect(model.router.route.selection == bash.id)
        model.router.keepSelection(onPage: .rules, among: RulesRuleRow.rowIDs([asked], in: .global))
        #expect(model.router.route.selection == bash.id, "the first-row rule finds it after the change and after its Undo")
        model.store.stop()
    }

    @Test("a hand-edited file with one text under two verdicts: two rows, and the dial changes the entry the selected row shows")
    func sameTextTwoVerdicts() async throws {
        let core = RulesFakeCore()
        core.globalRules = [D.rule("Bash", wide: true), D.rule("Bash", verdict: .deny)]
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: .rules))
        await model.store.start()
        core.reset()
        let state = RulesPageState(model: model)
        let list = try #require(state.list())
        #expect(Set(list.rows.map(\.id)).count == 2, "no two rows share an id")
        let deny = try #require(list.rows.first { $0.rule.verdict == .deny })
        model.router.select(deny.id)
        state.change(deny.rule, to: .ask, fileName: list.fileName)
        #expect(await eventually { toasts.current != nil })
        #expect(core.sent("rules.changeVerdict") == ["rules.changeVerdict global  Bash deny ask"], "from the deny entry, not the allow one")
        model.store.stop()
    }

    @Test("the Add Rule sheet closes on another page or an outside route, never on a re-selection; the preview closes on leaving")
    func addSheetFollowsRoute() async throws {
        let (_, model, state, _) = await setUp()
        state.openAdd()
        #expect(state.shownAddDraft != nil)
        model.router.select("global::Read(./.env)")
        model.router.keepSelection(onPage: .rules, among: ["global::Bash"])
        #expect(state.shownAddDraft != nil, "the first-row rule never closes the sheet")
        model.router.go(to: .session("claude:s1"))
        #expect(state.shownAddDraft == nil)
        model.router.open(.rules)
        #expect(state.shownAddDraft == nil, "it never comes back")
        state.pageLeft()
        #expect(state.addDraft == nil)
        let push = try #require(state.list()?.capabilities.first)
        state.requestPreview(push, to: .deny)
        state.pageLeft()
        #expect(state.preview == nil)
        model.store.stop()
    }

    @Test("a change starts from the verdict the store holds now, not the one a stale view drew")
    func changeStartsFromStore() async throws {
        let (core, model, state, toasts) = await setUp()
        let list = try #require(state.list())
        var stale = try #require(list.row("global::Bash")).rule
        stale.verdict = .deny
        state.change(stale, to: .ask, fileName: list.fileName)
        #expect(await eventually { toasts.current != nil })
        #expect(core.sent("rules.changeVerdict") == ["rules.changeVerdict global  Bash allow ask"])
        model.store.stop()
    }

    @Test("Remove N selected: one rules.removeMany with every ticked id of the one file, one Undo, ticks cleared")
    func removeSelected() async throws {
        let (core, model, state, toasts) = await setUp()
        state.toggle("global::Bash")
        state.toggle("global::Read(./.env)")
        let list = try #require(state.list())
        #expect(list.primary == .removeSelected(2))
        state.removeSelected(list.removal, fileName: list.fileName)
        #expect(await eventually { state.view.ticked.isEmpty })
        #expect(core.sent("rules.removeMany") == ["rules.removeMany global  [\"global:allow:Bash\", \"global:deny:Read(./.env)\"]"])
        #expect(toasts.current?.message == "Removed 2 Rules. settings.json was edited" && toasts.undoStack.count == 1)
        model.store.stop()
    }

    @Test("a refused removal keeps the ticks and shows the core's sentence")
    func refusedRemoval() async throws {
        let (core, model, state, toasts) = await setUp()
        core.refusal = "~/.claude/settings.json changed since SpaceVibe read it. Nothing changed."
        state.toggle("global::Bash")
        let list = try #require(state.list())
        state.removeSelected(list.removal, fileName: list.fileName)
        #expect(await eventually { toasts.current != nil })
        #expect(toasts.current?.tone == .danger && state.view.ticked == ["global::Bash"] && toasts.undoStack.isEmpty)
        model.store.stop()
    }

    @Test("Rules › Project: the route's scope moves to the project's Shared file, then Local; writes go to that file")
    func projectFile() async throws {
        let (core, model, state, toasts) = await setUp()
        state.toggle("global::Bash")
        let projects = try #require(state.list()).projects
        state.pick(scopeIsProject: true, projects: projects)
        #expect(model.router.route.scope == .shared(RulesFakeCore.dir) && state.view.ticked.isEmpty)
        state.pick(local: true)
        #expect(model.router.route.scope == .local(RulesFakeCore.dir))
        let list = try #require(state.list())
        #expect(list.fileName == "payments-web/.claude/settings.local.json")
        let bash = try #require(list.rows.first)
        state.remove(bash.rule, fileName: list.fileName)
        #expect(await eventually { toasts.current != nil })
        #expect(core.sent("rules.removeMany") == ["rules.removeMany local /p/payments-web [\"local:allow:Bash\"]"])
        state.pick(scopeIsProject: false, projects: projects)
        #expect(model.router.route.scope == .global)
        model.store.stop()
    }

    @Test("Add Rule: an invalid shape is refused next to the field by rules.check, and nothing is written")
    func addInvalid() async throws {
        let (core, model, state, toasts) = await setUp()
        core.check = CoreRuleCheck(valid: false, message: "That rule has an opening parenthesis without a closing one.")
        state.openAdd()
        state.addDraft?.text = "Bash(git log:*"
        state.submitAdd(fileName: "~/.claude/settings.json")
        #expect(await eventually { state.addDraft?.refusal != nil })
        #expect(state.addDraft?.refusal == "That rule has an opening parenthesis without a closing one." && state.addDraft?.isChecking == false)
        #expect(core.calls == ["rules.check Bash(git log:*"] && toasts.current == nil)
        model.store.stop()
    }

    @Test("Add Rule: a duplicate refused by rules.add stays in the sheet, not in a toast")
    func addDuplicate() async throws {
        let (core, model, state, toasts) = await setUp()
        core.refusal = "Bash is already in allow. Change its verdict instead."
        state.openAdd()
        state.addDraft?.text = "Bash"
        state.submitAdd(fileName: "~/.claude/settings.json")
        #expect(await eventually { state.addDraft?.refusal != nil })
        #expect(state.addDraft?.refusal == "Bash is already in allow. Change its verdict instead.")
        #expect(core.sent("rules.add") == ["rules.add global  ask Bash"] && toasts.current == nil)
        model.store.stop()
    }

    @Test("Add Rule: a valid rule goes to the file the sheet was opened for, the sheet closes, the toast offers Undo")
    func addValid() async throws {
        let (core, model, state, toasts) = await setUp()
        state.openAdd()
        state.addDraft?.text = "  Bash(git log:*) "
        state.addDraft?.verdict = .allow
        // The page moves while the sheet is open: the write still goes to the sheet's file.
        model.router.setScope(.shared(RulesFakeCore.dir))
        state.submitAdd(fileName: "~/.claude/settings.json")
        #expect(await eventually { state.addDraft == nil })
        #expect(core.sent("rules.add") == ["rules.add global  allow Bash(git log:*)"])
        #expect(toasts.current?.message == "Added Bash(git log:*) as Allow in ~/.claude/settings.json" && toasts.current?.action?.title == "Undo")
        model.store.stop()
    }

    @Test("the capability dial shows the step it is moving to while rules.setCapability runs, and opens no preview then (FE-L2)")
    func capabilityPending() async throws {
        let (core, model, state, _) = await setUp()
        core.capabilityDelay = .milliseconds(300)
        let list = try #require(state.list())
        let push = try #require(list.capabilities.first)
        #expect(state.pendingCapability(.push) == nil)
        state.requestPreview(push, to: .deny)
        #expect(await eventually { if case .ready = state.preview?.phase { true } else { false } })
        state.confirmPreview(push, fileName: list.fileName)
        #expect(state.pendingCapability(.push) == .deny, "pending before confirm returns")
        core.reset()
        state.requestPreview(push, to: .allow)
        #expect(state.preview == nil && core.calls.isEmpty, "a press while the write runs previews nothing")
        #expect(await eventually { state.pendingCapability(.push) == nil })
        #expect(core.sent("rules.setCapability") == ["rules.setCapability global  push deny"])
        model.store.stop()
    }

    @Test("Add Rule: while the check runs the field and the dial take no change, so the write sends what the sheet shows (Q-003)")
    func addFrozenWhileChecking() async throws {
        let (core, model, state, _) = await setUp()
        core.checkDelay = .milliseconds(200)
        state.openAdd()
        state.setAddText("Bash(git log:*)")
        state.setAddVerdict(.allow)
        state.submitAdd(fileName: "~/.claude/settings.json")
        #expect(state.addDraft?.isChecking == true)
        state.setAddVerdict(.deny)
        state.setAddText("Read")
        #expect(state.addDraft?.verdict == .allow && state.addDraft?.text == "Bash(git log:*)", "the sheet keeps what it sends")
        #expect(await eventually { state.addDraft == nil })
        #expect(core.sent("rules.add") == ["rules.add global  allow Bash(git log:*)"])
        model.store.stop()
    }

    @Test("Add Rule: the field and the dial change the draft while nothing runs, and a new text clears the refusal")
    func addEdits() async {
        let (_, model, state, _) = await setUp()
        state.openAdd()
        state.addDraft?.refusal = "Refused"
        state.setAddText("Bash")
        state.setAddVerdict(.deny)
        #expect(state.addDraft?.text == "Bash" && state.addDraft?.verdict == .deny && state.addDraft?.refusal == nil)
        model.store.stop()
    }

    @Test("a preview that answers after the page moved to another file is dropped")
    func latePreview() async throws {
        let (_, model, state, _) = await setUp()
        let push = try #require(state.list()?.capabilities.first)
        state.requestPreview(push, to: .deny)
        state.pick(scopeIsProject: true, projects: try #require(state.list()).projects)
        try await Task.sleep(for: .milliseconds(30))
        #expect(state.preview == nil)
        model.store.stop()
    }
}
