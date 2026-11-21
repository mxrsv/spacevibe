import Foundation
import Testing
@testable import SpaceVibe

/// The redesign's Hooks page (RB-R3): what each state shows, that the hero equals the rows, how rows group by lifecycle
/// stage at 2 and 10 CLIs, which rows may be written and which actions they offer, and the removal writes.
@Suite("Hooks page model")
@MainActor
struct HooksListModelTests {
    static let claudeEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "PostToolUseFailure",
                               "Notification", "SubagentStart", "SubagentStop", "Elicitation", "ElicitationResult", "TeammateIdle",
                               "PreCompact", "PostCompact", "Stop", "StopFailure", "SessionEnd"]
    static let codexEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "SubagentStart",
                              "SubagentStop", "Interrupt", "Stop", "SessionEnd"]

    static func hook(
        _ hash: String, cli: CoreCLI = .claude, event: String = "PreToolUse", command: String? = nil, dead: Bool = false,
        owner: String = "user", project: String? = nil, avg: Int? = nil, cells: CoreCLICells
    ) -> CoreInventoryHook {
        let file = project.map { "\($0)/.claude/settings.json" } ?? (cli == .claude ? "/h/.claude/settings.json" : "/h/.codex/hooks.json")
        return CoreInventoryHook(
            id: "\(cli.rawValue):hook:\(hash)\(project ?? "")", cli: cli, kind: .hook, event: event, matcher: nil,
            command: command ?? "~/.\(cli.rawValue)/hooks/\(hash).sh", timeout: nil, async: false, owner: owner,
            removable: owner == "user" && project == nil, dead: dead, paths: [], hash: hash, file: file,
            scope: project == nil ? .global : .project, project: project, key: "hook:\(project ?? ""):\(hash)", cells: nil, cliCells: cells,
            usage: avg.map { CoreHookUsage(runs: 1, avgMs: $0, totalMs: 0, errors: 0, last: nil) }
        )
    }

    static func runs(_ n: Int, errors: Int = 0, week: [Int]? = nil, note: String? = nil) -> CoreCLICell {
        .runs(count: n, errors: errors, last: n > 0 ? "2026-01-14" : nil, note: note,
              week: week.map { $0.enumerated().map { CoreHookDay(day: "2026-01-0\($0.offset + 1)", runs: 1, errors: $0.element) } } ?? [])
    }

    static let codexUM = CoreCLICell.unmeasurable(reason: "Codex logs no hook runs")

    /// The mock's set (`src/a-core.js` HOOKS), trimmed: two dead, one never ran, one failing, healthy ones, a project's, two Codex.
    static var sample: [CoreInventoryHook] {
        [
            hook("lint", event: "PreToolUse", dead: true, cells: ["claude": runs(0), "codex": .missing]),
            hook("notify", event: "Stop", dead: true, cells: ["claude": runs(0), "codex": .missing]),
            hook("guard", event: "PreToolUse", command: "python3 ~/.claude/hooks/guard.py", cells: ["claude": runs(1204, errors: 6, week: [0, 0, 0, 0, 0, 0, 0]), "codex": .missing]),
            hook("format", event: "PostToolUse", avg: 214, cells: ["claude": runs(812, errors: 14, week: [2, 2, 2, 2, 2, 2, 2]), "codex": .missing]),
            hook("load", event: "SessionStart", avg: 120, cells: ["claude": runs(96), "codex": .missing]),
            hook("prompt", event: "UserPromptSubmit", cells: ["claude": runs(0), "codex": .missing]),
            hook("lint-p", event: "PostToolUse", project: "/w/payments-web", cells: ["claude": runs(0), "codex": .missing]),
            hook("cx-guard", cli: .codex, event: "PreToolUse", cells: ["claude": .missing, "codex": codexUM]),
            hook("cx-int", cli: .codex, event: "Interrupt", cells: ["claude": .missing, "codex": codexUM]),
        ]
    }

    /// As the core sends them: one cell per registry CLI, Missing or Not supported where the test gave none.
    static func loadout(_ hooks: [CoreInventoryHook], usage: CoreLoadoutRows.UsageState = .ready,
                        registry: [CoreRegistryCLI] = FrameTestData.registry) -> CoreLoadoutRows {
        let filled = hooks.map { hook -> CoreInventoryHook in
            var copy = hook
            for cli in registry where copy.cliCells?[cli.id] == nil { copy.cliCells?[cli.id] = cli.supports.hook ? .missing : .notSupported }
            return copy
        }
        var rows = FrameTestData.loadout(hooks: filled, usage: usage)
        rows.events = ["claude": claudeEvents, "codex": codexEvents]
        rows.roots = ["claude": "/h/.claude", "codex": NSHomeDirectory() + "/.codex"]
        return rows
    }

    static func model(_ given: [CoreInventoryHook]? = nil, registry: [CoreRegistryCLI] = FrameTestData.registry,
                      view: HooksViewState = HooksViewState(), usage: CoreLoadoutRows.UsageState = .ready,
                      loading: Set<FrameSource> = [], failed: Set<FrameSource> = []) -> HooksListModel {
        let hooks = given ?? sample
        let world = FrameWorld(snapshot: FrameTestData.snapshot(loadout(hooks, usage: usage, registry: registry), registry: registry), now: FrameTestData.now)
        return HooksListModel(world: world, loading: loading, failed: failed, failure: failed.isEmpty ? nil : "No hook file could be read.",
                              view: view, now: FrameTestData.now)
    }

    // MARK: Lifecycle

    @Test("the firing order merges both CLIs' lists: Codex's Interrupt lands before Stop, as the mock's HEV_ALL")
    func firingOrder() {
        let order = HooksLifecycle.firingOrder(["claude": Self.claudeEvents, "codex": Self.codexEvents], registry: ["claude", "codex"])
        #expect(order == ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "PostToolUseFailure",
                          "Notification", "SubagentStart", "SubagentStop", "Elicitation", "ElicitationResult", "TeammateIdle",
                          "PreCompact", "PostCompact", "Interrupt", "Stop", "StopFailure", "SessionEnd"])
        #expect(HooksLifecycle.firingOrder([:], registry: ["claude"]) == HooksLifecycle.commonEvents)
    }

    @Test("the strip draws the six common events and every other event that has a Hook, in firing order, each with its state")
    func strip() {
        let list = Self.model()
        #expect(list.nodes.map(\.event) == ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Interrupt", "Stop"])
        let byEvent = Dictionary(uniqueKeysWithValues: list.nodes.map { ($0.event, $0) })
        #expect(byEvent["PreToolUse"]?.mark == .critical && byEvent["PreToolUse"]?.count == 3)
        #expect(byEvent["PostToolUse"]?.mark == .attention)
        #expect(byEvent["Notification"]?.mark == .empty && byEvent["Notification"]?.count == 0)
        #expect(byEvent["PreToolUse"]?.spoken == "PreToolUse: 3 Hooks, one is dead")
        #expect(byEvent["PostToolUse"]?.spoken == "PostToolUse: 2 Hooks, one is failing")
        #expect(byEvent["Notification"]?.spoken == "Notification: 0 Hooks")
    }

    // MARK: Hero and rows

    @Test("the hero equals the dead or never ran rows, the group head and the sidebar value")
    func heroEqualsRows() {
        let list = Self.model()
        let world = FrameWorld(snapshot: FrameTestData.snapshot(Self.loadout(Self.sample)), now: FrameTestData.now)
        let figure = world.figure(for: .hooks, loading: [], failed: [])
        // lint and notify dead; prompt and the project's lint-p never ran.
        #expect(list.deadOrNeverRan.count == 4)
        #expect(list.hero == .value("4", unit: nil))
        #expect(FrameSidebarValue(figure: figure, page: .hooks).text == "4")
        #expect(list.visible.filter(\.isDeadOrNeverRan).count == 4)
        #expect(list.deadHeadSeverity == .critical)
    }

    @Test("rows group by lifecycle stage in firing order at 2 and at 10 CLIs: one shape")
    func groupsByStage() {
        for registry in [FrameTestData.registry, FrameTestData.registry(count: 10)] {
            let list = Self.model(registry: registry)
            #expect(list.stages.map(\.stage) == ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Interrupt", "Stop"])
            #expect(list.stages.first { $0.stage == "PreToolUse" }?.rows.map(\.id) == ["hook::lint", "hook::guard", "hook::cx-guard"])
            #expect(list.visible.count == 9)
        }
    }

    @Test("a Hook is named by the script it runs; the sub-line names the project or says Every event")
    func names() {
        let list = Self.model()
        #expect(list.row("hook::guard")?.label == "guard.py")
        #expect(list.row("hook::guard")?.subLine(foldsStatus: false) == "Every event")
        #expect(list.row("hook:/w/payments-web:lint-p")?.subLine(foldsStatus: false) == "Project · payments-web")
        #expect(list.row("hook::lint")?.subLine(foldsStatus: true) == "Script missing")
        #expect(list.row("hook::format")?.subLine(foldsStatus: true) == "14 errors · 7 days")
    }

    @Test("the Runs and Status cells: counted bar, zero for dead and never ran, Unmeasurable for Codex, failing first")
    func cells() throws {
        let list = Self.model()
        let guardRow = try #require(list.row("hook::guard"))
        #expect(guardRow.runs == .count(1204, share: 1))
        #expect(guardRow.statusLine == HooksStatusLine(tone: .quiet, text: "6 errors, none in 7 days"))
        #expect(list.row("hook::format")?.statusLine == HooksStatusLine(tone: .attention, text: "14 errors · 7 days"))
        #expect(list.row("hook::load")?.statusLine.text == "120 ms avg")
        #expect(list.row("hook::lint")?.runs == .zero)
        #expect(list.row("hook::lint")?.statusLine == HooksStatusLine(tone: .critical, text: "Script missing"))
        #expect(list.row("hook::prompt")?.statusLine.text == "Never ran")
        #expect(list.row("hook::cx-guard")?.runs == .unmeasurable)
        #expect(list.row("hook::cx-guard")?.statusLine.text == "No run log")
        #expect(RunsCell.spoken(.zero) == "0 runs" && RunsCell.spoken(.count(1204, share: 1)) == "1,204 runs")
    }

    @Test("failing means errors in the last 7 days: lifetime errors without a week never count (RD26)")
    func failingIsSevenDays() {
        let hooks = [Self.hook("old", cells: ["claude": Self.runs(40, errors: 9), "codex": .missing])]
        let list = Self.model(hooks)
        #expect(list.row("hook::old")?.errorsLastWeek == nil)
        #expect(list.row("hook::old")?.statusLine.tone == .quiet)
        #expect(list.nodes.first { $0.event == "PreToolUse" }?.mark == .plain)
    }

    @Test("a dead Hook with runs in the logs shows them (inventory.md: counted like any other)")
    func deadWithRuns() {
        let list = Self.model([Self.hook("gone", dead: true, cells: ["claude": Self.runs(3), "codex": .missing])])
        #expect(list.row("hook::gone")?.runs == .count(3, share: 1))
        #expect(list.row("hook::gone")?.status == .dead)
    }

    // MARK: Writes offered

    @Test("only Claude Code Hooks outside projects and plugins are writable; Codex, project and plugin rows offer nothing")
    func writable() {
        let hooks = Self.sample + [Self.hook("plug", owner: "acme", cells: ["claude": Self.runs(0), "codex": .missing])]
        let list = Self.model(hooks)
        let state = HooksPageState()
        #expect(list.row("hook::lint")?.isWritable == true)
        #expect(list.row("hook::lint")?.removalIDs == ["claude:hook:lint"])
        #expect(list.row("hook::cx-guard")?.readOnly == .notClaudeCode)
        #expect(list.row("hook:/w/payments-web:lint-p")?.readOnly == .project("payments-web"))
        #expect(list.row("hook::plug")?.readOnly == .plugin)
        for id in ["hook::cx-guard", "hook:/w/payments-web:lint-p", "hook::plug"] {
            let row = list.row(id)!
            #expect(!row.isWritable && HooksFrame.actions(for: row, state: state).isEmpty)
            #expect(HooksRemoval.write([row], registry: list.registry) == nil)
        }
        let actions = HooksFrame.actions(for: list.row("hook::lint")!, state: state)
        #expect(actions.map(\.title) == ["Remove from Claude Code"] && actions[0].isDestructive)
        #expect(FrameRowAction.conflicts(in: actions).isEmpty)
    }

    @Test("nothing is pre-selected; Select N Suggested ticks the dead and never ran Claude Code rows, not projects or new ones")
    func suggested() {
        let hooks = Self.sample + [Self.hook("fresh", event: "Stop", cells: ["claude": Self.runs(0, note: "Added today: may be too new for the logs."), "codex": .missing])]
        var view = HooksViewState()
        let list = Self.model(hooks, view: view)
        #expect(list.view.ticked.isEmpty && list.removal.isEmpty)
        #expect(Set(list.suggested) == ["hook::lint", "hook::notify", "hook::prompt"])
        view = view.togglingAll(list.suggested)
        let ticked = Self.model(hooks, view: view)
        #expect(ticked.allSuggestedTicked && ticked.removal.count == 3)
        #expect(HooksFrame.removeSelectedTitle(ticked.removal.count) == "Remove 3 selected")
        #expect(HooksFrame.removeSelectedTitle(0) == "Select rows to remove")
        #expect(view.togglingAll(list.suggested).ticked.isEmpty)
    }

    @Test("a filter clears the ticks, and a tick the filter hides never reaches a removal")
    func filters() {
        let view = HooksViewState().toggling("hook::lint").toggling("hook::notify")
        let stopOnly = Self.model(view: HooksViewState(ticked: view.ticked, event: "Stop"))
        #expect(stopOnly.removal.map(\.id) == ["hook::notify"])
        #expect(stopOnly.subtitle == "Stop only")
        #expect(view.filtering(event: "Stop").ticked.isEmpty)
        #expect(view.filtering(cli: "codex").ticked.isEmpty)
        let codex = Self.model(view: HooksViewState(cli: "codex"))
        #expect(codex.visible.map(\.id) == ["hook::cx-guard", "hook::cx-int"])
        #expect(codex.hero == .value("4", unit: nil))
    }

    @Test("the lines under the table name the CLIs with no Hooks and the CLIs without Hooks")
    func notes() {
        let claudeOnly = Self.model(Self.sample.filter { $0.cli == .claude })
        #expect(claudeOnly.noHooks.map(\.id) == ["codex"] && claudeOnly.notSupported.isEmpty)
        let ten = Self.model(registry: FrameTestData.registry(count: 10))
        #expect(ten.notSupported.map(\.id) == ["cli3", "cli5", "cli7", "cli9"])
        #expect(ten.noHooks.map(\.id) == ["cli2", "cli4", "cli6", "cli8"])
        #expect(ten.cliOptions.filter { !$0.isSupported }.map(\.cli.id) == ["cli3", "cli5", "cli7", "cli9"])
    }

    // MARK: States

    @Test("each state: the first read and the scan are scanning, a failed read is failed, no Hook is empty")
    func phases() {
        #expect(Self.model(loading: [.loadout]).phase == .scanning)
        #expect(Self.model(loading: [.loadout]).hero == .scanning)
        let scanning = Self.model(usage: .scanning)
        #expect(scanning.phase == .scanning && !scanning.all.isEmpty)
        #expect(Self.model(failed: [.loadout]).phase == .failed("No hook file could be read."))
        #expect(Self.model(failed: [.loadout]).hero == .unmeasurable)
        let empty = Self.model([])
        #expect(empty.phase == .empty && empty.nodes.isEmpty && empty.hero == .value("0", unit: nil))
        #expect(Self.model().phase == .normal)
    }

    @Test("an unreadable Codex hook file names Codex in the banner and never as No Hooks")
    func unreadable() {
        let hooks = Self.sample.filter { $0.cli == .claude }.map { hook -> CoreInventoryHook in
            var copy = hook
            copy.cliCells?["codex"] = .unknown
            return copy
        }
        let list = Self.model(hooks)
        #expect(list.unreadable.map(\.id) == ["codex"])
        #expect(list.noHooks.isEmpty)
    }

    @Test("the worst case: a 4.8M-run Hook, a long command, a right-to-left label and 60 rows keep one shape")
    func worstCase() {
        let long = "python3 ~/.claude/hooks/guard.py --deny 'rm -rf' --deny 'git push --force' --log ~/Library/Logs/claude-guard/guard.jsonl"
        var hooks = [Self.hook("big", command: long, cells: ["claude": Self.runs(4_830_112, week: [0, 0, 0, 0, 0, 0, 1]), "codex": .missing])]
        hooks += (0..<60).map { Self.hook("h\($0)", event: Self.claudeEvents[$0 % 17], cells: ["claude": Self.runs($0), "codex": .missing]) }
        let list = Self.model(hooks)
        #expect(list.row("hook::big")?.label == "guard.py")
        #expect(list.row("hook::big")?.runs == .count(4_830_112, share: 1))
        #expect(NumberWording.compactCount(4_830_112) == "4.8M")
        #expect(list.visible.count == 61)
        #expect(list.nodes.count == 17)
    }

    // MARK: Writes

    @Test("removals are one loadout.removeMany write naming only Claude Code members; the control shows pending at its button")
    func writes() throws {
        let shared = [Self.hook("both", cells: ["claude": Self.runs(0), "codex": Self.codexUM]),
                      Self.hook("both", cli: .codex, cells: ["claude": Self.runs(0), "codex": Self.codexUM])]
        let list = Self.model(Self.sample + shared)
        let lint = list.row("hook::lint")!, notify = list.row("hook::notify")!
        #expect(HooksRemoval.write([lint], registry: list.registry)?.control == "hooks:remove:hook::lint")
        #expect(HooksRemoval.write([lint, notify], registry: list.registry)?.control == HooksRemoval.selectedControl)
        let both = try #require(list.row("hook::both"))
        #expect(both.clis == ["claude", "codex"] && both.removalIDs == ["claude:hook:both"])
    }

    @Test("one Hook removes at once with Undo (Hooks never ask); a refusal is the core's sentence")
    func removeOne() async throws {
        let core = FrameFakeCore()
        core.loadout = Self.loadout(Self.sample)
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: .hooks))
        await model.store.start()
        let list = HooksListModel.from(model.store, view: HooksViewState())
        let write = try #require(HooksRemoval.write([list.row("hook::lint")!], registry: list.registry))
        #expect(await model.writes.perform(write))
        #expect(core.count("loadout.removeMany") == 1)
        #expect(core.sent["loadout.removeMany"] == "[\"claude:hook:lint\"]")
        #expect(toasts.current?.message == "Removed lint.sh from Claude")
        #expect(toasts.canUndoByKey)

        core.writeResult = .failure(CoreError("Couldn’t remove lint.sh: ~/.claude/settings.json changed since SpaceVibe read it. Nothing changed.", status: 409))
        #expect(await model.writes.perform(write) == false)
        #expect(toasts.current?.tone == .danger)
        #expect(toasts.current?.message.hasPrefix("Couldn’t remove lint.sh") == true)
    }

    @Test("Remove N selected is one write and one Undo for every ticked row shown")
    func removeSelected() async throws {
        let core = FrameFakeCore()
        core.loadout = Self.loadout(Self.sample)
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: .hooks))
        await model.store.start()
        let list = HooksListModel.from(model.store, view: HooksViewState().togglingAll(["hook::lint", "hook::notify", "hook::cx-guard"]))
        #expect(list.removal.map(\.id) == ["hook::lint", "hook::notify"])
        let write = try #require(HooksRemoval.write(list.removal, registry: list.registry, control: HooksRemoval.selectedControl))
        #expect(await model.writes.perform(write))
        #expect(core.count("loadout.removeMany") == 1)
        #expect(core.sent["loadout.removeMany"].map { $0.contains("claude:hook:lint") && $0.contains("claude:hook:notify") } == true)
        #expect(toasts.current?.message == "Removed 2 Hooks from Claude")
    }

    @Test("the page state is one per frame model and drops a removed row's tick and selection")
    func pageState() async throws {
        let core = FrameFakeCore()
        core.loadout = Self.loadout(Self.sample)
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false), route: FrameRoute(page: .hooks))
        await model.store.start()
        let state = HooksPageState.of(model)
        #expect(HooksPageState.of(model) === state)
        state.toggle("hook::lint")
        model.router.select("hook::lint")
        state.pressNode("Stop")
        #expect(state.view.event == "Stop" && state.view.ticked.isEmpty)
        state.pressNode("Stop")
        #expect(state.view.event == nil)
        state.toggle("hook::lint")
        let list = HooksListModel.from(model.store, view: state.view)
        state.remove(list.row("hook::lint")!)
        for _ in 0..<200 where !state.view.ticked.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(state.view.ticked.isEmpty)
        #expect(model.router.route.selection == nil)
    }

    @Test("the inspector's facts: runs, a missing script, errors in 7 days and in all, the file, a project's scope")
    func inspector() {
        let list = Self.model()
        let format = list.row("hook::format")!
        let facts = HooksInspectorFacts.facts(format, holders: list.holders(of: format), now: FrameTestData.now)
        #expect(facts.first { $0.key == "Runs" }?.value == "812")
        #expect(facts.first { $0.key == "Errors" }?.value == "14 in 7 days · 14 of 812 runs in all")
        #expect(facts.first { $0.key == "Average" }?.value == "214 ms")
        #expect(HooksInspectorFacts.headline(format, holders: list.holders(of: format)) == "PostToolUse · Claude") // FrameTestData names a CLI by its capitalized id
        let lint = list.row("hook::lint")!
        #expect(HooksInspectorFacts.facts(lint, holders: [], now: FrameTestData.now).contains(HooksInspectorFact(key: "Script", value: "File is missing")))
        let codex = list.row("hook::cx-guard")!
        #expect(HooksInspectorFacts.facts(codex, holders: list.holders(of: codex), now: FrameTestData.now).first?.value
                == "Unmeasurable: Codex logs no Hook runs")
        let project = list.row("hook:/w/payments-web:lint-p")!
        #expect(HooksInspectorFacts.facts(project, holders: [], now: FrameTestData.now).last?.value == "Project payments-web, read-only here")
    }
}
