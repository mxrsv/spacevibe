import Foundation
import Testing
@testable import SpaceVibe

/// The Inbox page (RB-R1; RD3, RD-R4, RD26, RD-A9, RD30, RD36, RD40, RD41): what each RD-R13 state shows, that the hero counts
/// the rows shown, which actions each finding offers, and that removals ask only for a shared file.
@Suite("Inbox page")
struct InboxPageTests {
    typealias S = InboxSynthetic
    typealias D = FrameTestData

    private func page(_ state: S.State, clis: Int = 2, ticked: Set<String> = [], showsKept: Bool = false,
                      hasHost: @escaping (Int) -> Bool = { _ in true }) -> (InboxPage, FrameWorld) {
        let world = S.world(state, clis: clis)
        let figure = world.figure(for: .inbox, loading: [], failed: [])
        return (InboxPage(world: world, figure: figure, ticked: ticked, showsKept: showsKept, hasHost: hasHost, now: S.now), world)
    }

    private func row(_ page: InboxPage, _ id: String) -> InboxRowModel? { page.row(id) }

    // MARK: Hero and groups

    @Test("the hero counts the rows shown, the same figure as the sidebar, at every state and CLI count", arguments: [2, 10])
    func heroEqualsRows(clis: Int) {
        for state in S.State.allCases where state != .scanning {
            let (page, world) = page(state, clis: clis)
            guard case .count(let n, _) = world.figure(for: .inbox, loading: [], failed: []) else {
                Issue.record("\(state): no count")
                continue
            }
            #expect(page.rows.count == n, "\(state) at \(clis) CLIs")
            if n == 0 { #expect(page.hero == .clear("Clear")) } else { #expect(page.hero == .value(NumberWording.count(n), unit: nil)) }
        }
    }

    @Test("groups by job in page order, severity once at the head, Select N Suggested on Clean up only")
    func groups() {
        let (page, _) = page(.normal)
        #expect(page.groups.map(\.job) == [.cleanUp, .control, .watch], "no Balance without two pins")
        #expect(page.groups.map(\.severity) == [.critical, .attention, .attention])
        let clean = page.groups[0]
        #expect(clean.suggested == clean.rows.map(\.id) && !clean.suggested.isEmpty)
        let rest = page.groups.dropFirst().allSatisfy { $0.suggested.isEmpty }
        #expect(rest)
        #expect(page.heroLabel == "need you")
        #expect(page.isBalanceOff)
    }

    @Test("nothing is ticked at first; Remove N selected counts ticked rows shown, ignores ticks on other rows")
    func primary() {
        let (start, _) = page(.normal)
        #expect(start.primary == .remove(count: 0))
        #expect(start.primary.title(narrow: false) == "Select rows to remove")
        #expect(start.primary.title(narrow: true) == "Select rows")
        let ids = start.groups[0].suggested
        let (ticked, _) = page(.normal, ticked: Set(ids + ["R::global:allow:Bash", "gone"]))
        #expect(ticked.ticked == ids)
        #expect(ticked.primary.title(narrow: false) == "Remove \(ids.count) selected")
    }

    // MARK: Rows and actions

    @Test("Clean up: Dead and Never ran, Keep then Remove; at 2 CLIs nothing is shared, so it goes at once")
    func cleanUpRows() {
        let (page, _) = page(.normal)
        let dead = row(page, "hook::h1")
        #expect(dead?.glyph.icon == .prohibit && dead?.evidence == "Script file is missing" && dead?.isMono == true)
        #expect(dead?.actions == [.keep, .remove(title: "Remove from Claude Code", asks: false)])
        let never = row(page, "skill::pdf-extract")
        #expect(never?.glyph.icon == .circleDashed && never?.evidence == "Never ran" && never?.isRemovable == true)
        #expect(never?.sub == "Skill · added 41 days ago")
        #expect(never?.actions == [.keep, .remove(title: "Remove from Claude Code and Codex", asks: false)])
        #expect(row(page, "skill::code-review") == nil, "an item that ran is no finding")
    }

    @Test("a file read by several CLIs asks first, naming every reader (10 CLIs, ~/.agents/skills)")
    func sharedAsks() {
        let (page, world) = page(.normal, clis: 10)
        #expect(row(page, "skill::pdf-extract")?.actions.last == .remove(title: "Remove…", asks: true))
        let item = world.rows.first { $0.id == "skill::pdf-extract" }!
        let wording = InboxWording(world: world, now: S.now)
        #expect(wording.losers(item).map(wording.name) == ["Claude Code", "Codex", "Cursor CLI", "Amp"])
        #expect(row(page, "agent::release-captain")?.actions.last == .remove(title: "Remove from Claude Code and Codex", asks: false))
    }

    @Test("Control and Watch rows: failing Hook, whole-tool Rules in Global and a project, Window behind pace, waiting session")
    func otherRows() {
        let (page, _) = page(.normal, hasHost: { _ in false })
        let failing = row(page, "hook::h4:fail")
        #expect(failing?.evidence == "2 failures in 7 days" && failing?.isRemovable == false)
        #expect(failing?.actions == [.keep, .copyCommand("pnpm prettier --write \"$CLAUDE_FILE\"")])
        let global = row(page, "R::global:allow:Bash")
        #expect(global?.sub == "Rule · Claude Code · Global" && global?.evidence == "Allows every Bash call")
        #expect(global?.actions == [.keep, .changeToAsk])
        let local = page.rows.first { $0.id.hasPrefix("R:\(S.project):") }
        #expect(local?.sub == "Rule · Claude Code · payments-web · Local")
        let window = page.rows.first { $0.id.hasPrefix("W:codex:") }
        #expect(window?.title == "Codex · 5-hour Window" && window?.sub == "Faster than time passes")
        #expect(window?.evidence.hasPrefix("77% left · resets ") == true)
        #expect(window?.actions == [.keep, .showInLimits(windowID: "codex:primary")])
        let session = row(page, "S:claude:s-waiting")
        #expect(session?.glyph == InboxRowGlyph(icon: .chatCircleDots, ink: .sessionWaiting))
        #expect(session?.sub == "Claude Code session · payments-web" && session?.evidence == "Waiting 4 min")
        #expect(session?.actions == [.keep, .terminalNotFound], "no host app: the button is disabled (RD36)")
        #expect(InboxAction.terminalNotFound.isEnabled == false && InboxAction.terminalNotFound.title == "Terminal app not found")
        let (hosted, _) = self.page(.normal)
        #expect(hosted.row("S:claude:s-waiting")?.actions.last == .showTerminal(pid: 47_812))
    }

    @Test("Keep and Stop Keeping share ⌘K, which the frame does not hold")
    func shortcuts() {
        let (page, _) = page(.normal)
        for row in page.rows {
            #expect(FrameRowAction.conflicts(in: row.actions.map { FrameRowAction(id: $0.id, title: $0.title, shortcut: $0.shortcut) {} }).isEmpty)
        }
        #expect(InboxAction.keep.shortcut == FrameShortcut("k") && InboxAction.stopKeeping.shortcut == FrameShortcut("k"))
    }

    // MARK: States

    @Test("Clear: nothing needs you, the sidebar shows 0, the kept finding is listed with Stop Keeping (RD-A9)")
    func clear() {
        let (page, world) = page(.empty, showsKept: true)
        #expect(page.hero == .clear("Clear") && page.heroLabel == "Nothing needs you" && page.isClear)
        #expect(page.primary == .hidden)
        #expect(FrameSidebarValue(figure: world.figure(for: .inbox, loading: [], failed: []), page: .inbox).text == "0")
        #expect(page.kept.map(\.id) == ["skill::changelog-writer"] && page.showsKept)
        #expect(page.kept[0].actions.first == .stopKeeping && !page.kept[0].isRemovable)
        #expect(page.order == ["skill::changelog-writer"])
        let (hidden, _) = self.page(.empty)
        #expect(hidden.order.isEmpty, "the arrow keys skip kept rows while they are hidden")
    }

    @Test("scanning: an ellipsis, the scanning band, no list and no button")
    func scanning() {
        let (page, _) = page(.scanning)
        #expect(page.hero == .scanning && page.banner == .scanning && !page.showsList && page.primary == .hidden)
    }

    @Test("a source that could not be read: Unmeasurable with the core's sentence, never Clear")
    func failed() {
        let world = S.world(.normal, clis: 2)
        let page = InboxPage(world: world, figure: .failed, failure: "The core could not be started.", now: S.now)
        #expect(page.hero == .unmeasurable && page.banner == .failed("The core could not be started.") && !page.isClear)
        #expect(page.banner?.title == "Unmeasurable" && page.primary == .hidden)
    }

    @Test("an unreadable Codex folder: the band names the folder, the list still shows")
    func unreadable() {
        let (page, _) = page(.error)
        #expect(page.banner == .unreadable(names: ["Codex"], paths: ["~/.codex"]))
        #expect(page.banner?.title == "Codex folder could not be read")
        #expect(page.banner?.detail == "~/.codex could not be read, so every Codex figure is Unmeasurable here, not zero.")
        #expect(page.showsList)
    }

    @Test("worst case: over the limit is critical, long names stay whole in the model")
    func worst() {
        let (page, world) = page(.worst, clis: 10)
        let window = page.rows.first { $0.id.hasPrefix("W:codex:") }
        #expect(window?.sub == "Over the limit")
        #expect(page.groups.first { $0.job == .watch }?.severity == .critical)
        #expect(page.rows.contains { $0.title.hasPrefix(S.longName) })
        let pace = world.windows.first { $0.cli == "codex" }!
        #expect(InboxInspectorFacts.window(pace, entry: nil, now: S.now).first == InspectorFact(key: "Left", value: "0% · over by 4.5%"))
    }

    // MARK: Model rules

    @Test("D25: a dead Hook only Codex holds is a Hooks fact, never an Inbox finding, never suggested")
    func codexOnlyHook() {
        var codexHook = D.hook("cx", command: "~/.codex/hooks/x.sh", dead: true, cells: ["claude": .missing, "codex": D.runs(0)])
        codexHook.cli = .codex
        let claudeHook = D.hook("cl", command: "~/.claude/hooks/y.sh", dead: true, cells: ["claude": D.runs(0), "codex": .missing])
        let world = FrameWorld(snapshot: D.snapshot(D.loadout(hooks: [codexHook, claudeHook])), now: D.now)
        #expect(world.deadHooks.count == 2)
        #expect(world.findings.map(\.id) == ["hook::cl"])
        #expect(world.suggested == ["hook::cl"])
        #expect(InboxWording.removableMembers(world.rows) == ["claude:hook:cl"])
    }

    @Test("Balance: the most-used item missing in a pinned CLI, Add to it; none with fewer than two pins")
    func balance() {
        let item = D.item("deploy", cells: ["claude": D.sessions(9), "codex": .missing])
        var facts = FrameFacts()
        facts.findings.pinned = ["claude", "codex"]
        let world = FrameWorld(snapshot: D.snapshot(D.loadout([item])), facts: facts, now: D.now)
        let page = InboxPage(world: world, figure: world.figure(for: .inbox, loading: [], failed: []), now: D.now)
        let balance = page.groups.first { $0.job == .balance }
        #expect(balance?.severity == GroupSeverity.none && balance?.suggested.isEmpty == true)
        #expect(balance?.rows.first?.actions == [.keep, .addTo(cli: "codex", title: "Add to Codex")])
        #expect(balance?.rows.first?.evidence == "Missing in Codex" && balance?.rows.first?.sub == "Skill · ran in 9 sessions")
        #expect(!page.isBalanceOff)
    }

    @Test("wording helpers")
    func wording() {
        #expect(InboxWording.percent(77) == "77%" && InboxWording.percent(4.5) == "4.5%")
        #expect(InboxWording.settingsFile(.global) == "~/.claude/settings.json")
        #expect(InboxWording.settingsFile(.local("/p/web")) == "/p/web/.claude/settings.local.json")
        #expect(InboxWording.place(.shared("/p/web")) == "web · Shared")
        #expect(FindingRowLayout.showsEvidence(listWidth: 700) && !FindingRowLayout.showsEvidence(listWidth: 699))
        #expect(SkeletonRows.share(0) == 0.46 && SkeletonRows.share(3) == 0.85)
    }

    @Test("the CLI tiles at 10 CLIs: one per CLI, Not supported for a CLI without Skills, shared readers named")
    func tiles() {
        let world = S.world(.normal, clis: 10)
        let item = world.rows.first { $0.id == "skill::pdf-extract" }!
        let tiles = CLIToggleStates.states(of: item, in: world)
        #expect(tiles.count == 10)
        #expect(tiles.first { $0.cli.id == "aider" }?.presence == .notSupported(noun: "Skills"))
        let codex = tiles.first { $0.cli.id == "codex" }!
        #expect(codex.presence == .on(.neverRan) && codex.sharedWith == ["Cursor CLI", "Amp"])
        #expect(tiles.first { $0.cli.id == "cursor" }?.hold == .via(["Codex"]))
        #expect(tiles.first { $0.cli.id == "kiro" }?.presence == .off)
    }
}

/// The Inbox's presses over the fake core: Remove goes at once with Undo when no file is shared and asks otherwise; Keep
/// moves the selection to the next finding; the head's pick ticks and clears (RD40, RD41, AR4).
@Suite("Inbox actions")
@MainActor
struct InboxActionsTests {
    typealias S = InboxSynthetic

    private func setUp(clis: Int) async -> (FrameFakeCore, FrameModel, InboxPageState, InboxActions, InboxPage) {
        let core = FrameFakeCore()
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false))
        let world = S.world(.normal, clis: clis)
        let page = InboxPage(world: world, figure: world.figure(for: .inbox, loading: [], failed: []), now: S.now)
        let state = InboxPageState()
        let actions = InboxActions(model: model, state: state, page: page, world: world, host: InboxShots.host(.normal))
        return (core, model, state, actions, page)
    }

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    @Test("Remove N selected at 2 CLIs: one removeMany with the ticked rows' members, ticks cleared after")
    func removeAtOnce() async {
        let (core, _, state, actions, page) = await setUp(clis: 2)
        state.pickSuggested(page.groups[0].suggested)
        let ticked = InboxPage(world: actions.world, figure: .count(page.rows.count, tone: nil), ticked: state.ticked, now: S.now)
        InboxActions(model: actions.model, state: state, page: ticked, world: actions.world, host: actions.host).removeTicked()
        #expect(await eventually { core.count("loadout.removeMany") == 1 })
        #expect(state.confirming == nil)
        #expect(core.sent["loadout.removeMany"]?.contains("claude:hook:h1") == true)
        #expect(await eventually { state.ticked.isEmpty })
    }

    @Test("a shared file asks first; Cancel writes nothing, confirming writes once")
    func removeAsks() async {
        let (core, _, state, actions, page) = await setUp(clis: 10)
        let row = page.row("skill::pdf-extract")!
        actions.perform(row.actions.last!, on: row)
        #expect(state.confirming?.items.first?.losers == ["Claude Code", "Codex", "Cursor CLI", "Amp"])
        actions.cancelConfirmation()
        #expect(state.confirming == nil && core.count("loadout.removeMany") == 0)
        actions.perform(row.actions.last!, on: row)
        actions.confirm()
        #expect(await eventually { core.count("loadout.removeMany") == 1 && state.confirming == nil })
    }

    @Test("Keep stores the finding id and moves the selection to the next finding")
    func keep() async {
        let (core, model, _, actions, page) = await setUp(clis: 2)
        let first = page.rows[0]
        model.router.select(first.id)
        actions.perform(.keep, on: first)
        #expect(await eventually { core.sent["findings.keep"] == first.id && model.router.route.selection == page.rows[1].id })
    }

    @Test("the head's pick ticks every suggested row, then clears them")
    func pick() {
        let state = InboxPageState()
        state.pickSuggested(["a", "b"])
        #expect(state.ticked == ["a", "b"])
        state.toggleTick("a")
        state.pickSuggested(["a", "b"])
        #expect(state.ticked == ["a", "b"])
        state.pickSuggested(["a", "b"])
        #expect(state.ticked.isEmpty)
    }

    @Test("Show in Limits routes to Limits with the Window selected (AR5)")
    func showInLimits() async {
        let (_, model, _, actions, page) = await setUp(clis: 2)
        let window = page.rows.first { $0.id.hasPrefix("W:") }!
        actions.perform(.showInLimits(windowID: "codex:primary"), on: window)
        #expect(model.router.route == FrameRoute.window("codex:primary"))
    }
}

/// The RB-V1 build-review findings on the Inbox: Balance offers no removal, removals and tiles name what the engine needs
/// (links from other rows, shared files), a press acts on the world after a write, a running dialog ignores Esc, and a route
/// changed from outside closes the dialog.
@Suite("Inbox build-review fixes")
@MainActor
struct InboxBuildReviewTests {
    typealias S = InboxSynthetic
    typealias D = FrameTestData

    /// Codex's `bar` is a link to Claude Code's never-ran `foo` (two rows: the link's SKILL.md has no name), the layout of the
    /// engine's `TestRemoveFromSeesALinkInAnotherRow`. `bar` ran, so only `foo` is a finding.
    nonisolated static func linkWorld() -> FrameWorld {
        let foo = D.item("foo", cells: ["claude": D.sessions(0), "codex": .missing], folder: "/h/.claude/skills", realPath: "/h/.claude/skills/foo")
        let bar = D.item("bar", cli: .codex, owner: "link", cells: ["claude": .missing, "codex": D.sessions(5)], folder: "/h/.codex/skills",
                         realPath: "/h/.claude/skills/foo")
        var loadout = D.loadout([foo, bar])
        loadout.folders = [D.folder("/h/.claude/skills", readBy: ["claude"], ownedBy: "claude"),
                           D.folder("/h/.codex/skills", readBy: ["codex"], ownedBy: "codex")]
        return FrameWorld(snapshot: D.snapshot(loadout), now: D.now)
    }

    @MainActor
    final class Models { var all: [FrameModel] = [] }
    private let models = Models()

    private func actions(_ world: FrameWorld, core: FrameFakeCore = FrameFakeCore()) -> (FrameFakeCore, FrameModel, InboxPageState, InboxActions) {
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false))
        models.all.append(model)
        let page = InboxPage(world: world, figure: world.figure(for: .inbox, loading: [], failed: []), now: S.now)
        let state = InboxPageState()
        return (core, model, state, InboxActions(model: model, state: state, page: page, world: world, host: InboxShots.host(.normal)))
    }

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<400 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    @Test("Balance: the inspector offers Add to <CLI> and Keep only, never Remove…; a Clean up row offers Remove…")
    func balanceInspector() throws {
        let item = D.item("deploy", cells: ["claude": D.sessions(9), "codex": .missing])
        var facts = FrameFacts()
        facts.findings.pinned = ["claude", "codex"]
        let world = FrameWorld(snapshot: D.snapshot(D.loadout([item])), facts: facts, now: D.now)
        let page = InboxPage(world: world, figure: world.figure(for: .inbox, loading: [], failed: []), now: D.now)
        let balance = try #require(page.rows.first { $0.finding.job == .balance })
        #expect(InboxInspectorFacts.itemActions(balance) == [.addTo(cli: "codex", title: "Add to Codex"), .keep])
        let normal = InboxPage(world: S.world(.normal, clis: 2), figure: .count(0, tone: nil), now: S.now)
        let never = try #require(normal.row("skill::pdf-extract"))
        #expect(InboxInspectorFacts.itemActions(never) == [.remove(title: "Remove from Claude Code and Codex", asks: false)])
    }

    @Test("a row another row's link reaches: Remove names the link too, after the confirmation names its readers")
    func removeNamesLinks() async throws {
        let world = Self.linkWorld()
        let foo = try #require(world.rows.first { $0.id == "skill::foo" })
        #expect(RowRemoval.members([foo], in: world) == ["claude:skill:foo", "codex:skill:bar"])
        let (core, _, state, actions) = actions(world)
        actions.remove([foo], control: InboxActions.removeControl(foo.id))
        #expect(state.confirming?.items.first?.losers == ["Claude", "Codex"], "Codex would keep a dangling link")
        actions.confirm()
        #expect(await eventually { core.count("loadout.removeMany") == 1 })
        #expect(core.sent["loadout.removeMany"] == "[\"claude:skill:foo\", \"codex:skill:bar\"]")
    }

    @Test("a tile turned off on a file another CLI reads: the confirmation, then one removeMany of exactly its members, never removeFrom")
    func sharedTile() async throws {
        let world = S.world(.normal, clis: 10)
        let item = try #require(world.rows.first { $0.id == "skill::pdf-extract" })
        let codex = try #require(CLIToggleStates.states(of: item, in: world).first { $0.cli.id == "codex" })
        guard case .confirm(let removal) = RowRemoval.toggle(codex, row: item, in: world) else {
            Issue.record("a shared file asks first")
            return
        }
        let (core, _, state, actions) = actions(world)
        #expect(actions.toggleTile(codex, row: item) == nil && state.confirming != nil && core.calls.isEmpty)
        actions.confirm()
        #expect(await eventually { core.count("loadout.removeMany") == 1 })
        #expect(core.count("loadout.removeFrom") == 0 && core.sent["loadout.removeMany"] == "\(removal.members)")
    }

    @Test("D53: a tile drawn before a write landed is judged on the world after it: the last copy is not removed")
    func staleTile() async throws {
        let world = S.world(.normal, clis: 2)
        let item = try #require(world.rows.first { $0.id == "skill::pdf-extract" })
        let tiles = CLIToggleStates.states(of: item, in: world)
        let claude = try #require(tiles.first { $0.cli.id == "claude" })
        let codex = try #require(tiles.first { $0.cli.id == "codex" })
        #expect(claude.isToggle && codex.isToggle)
        let (core, _, _, made) = actions(world)
        var actions = made
        await actions.toggleTile(claude, row: item)?.value
        #expect(core.count("loadout.removeFrom") == 1)
        // The store's world after Claude Code's copy went: Codex holds the last copy.
        var built = S.snapshot(.normal, clis: 2)
        built.snapshot.loadout?.items.removeAll { $0.key == "skill::pdf-extract" && $0.cli == .claude }
        let after = FrameWorld(snapshot: built.snapshot, facts: built.facts, now: S.now)
        actions.liveWorld = { after }
        #expect(actions.toggleTile(codex, row: item) == nil)
        #expect(core.count("loadout.removeFrom") == 1)
    }

    @Test("Esc on a running confirmation does nothing: the dialog stays until the core answered")
    func escWhileRunning() async throws {
        let gate = PendingGate()
        let core = FrameFakeCore()
        core.onCall = { name in if name == "loadout.removeMany" { await gate.wait() } }
        let world = S.world(.normal, clis: 10)
        let (_, model, state, actions) = actions(world, core: core)
        let row = try #require(InboxPage(world: world, figure: .count(0, tone: nil), now: S.now).row("skill::pdf-extract"))
        actions.perform(row.actions.last!, on: row)
        actions.confirm()
        #expect(await eventually { actions.isConfirming })
        let content = FramePageContent.inbox(model: model, fixed: InboxInputs(world: world, figure: .count(0, tone: nil), now: S.now),
                                             host: InboxShots.host(.normal), state: state)
        content.dialog?.cancel()
        #expect(state.confirming != nil, "Esc reaches the dialog's cancel through the frame; it must wait for the write")
        await gate.open()
        #expect(await eventually { state.confirming == nil })
    }

    @Test("a route changed from outside (the glance widget) closes the dialog; it never comes back stale")
    func routeClosesDialog() throws {
        let world = S.world(.normal, clis: 10)
        let (_, model, state, actions) = actions(world)
        let row = try #require(InboxPage(world: world, figure: .count(0, tone: nil), now: S.now).row("skill::pdf-extract"))
        actions.perform(row.actions.last!, on: row)
        let fixed = InboxInputs(world: world, figure: .count(0, tone: nil), now: S.now)
        #expect(FramePageContent.inbox(model: model, fixed: fixed, host: InboxShots.host(.normal), state: state).dialog != nil)
        model.router.go(to: .window("codex:primary"))
        model.router.go(to: FrameRoute(page: .inbox))
        #expect(FramePageContent.inbox(model: model, fixed: fixed, host: InboxShots.host(.normal), state: state).dialog == nil)
    }

    @Test("RD-R16: Remove, Add to and Change to Ask each have a menu shortcut, not a plain letter")
    func rowShortcuts() {
        #expect(InboxAction.remove(title: "Remove…", asks: true).shortcut == .remove)
        #expect(InboxAction.addTo(cli: "codex", title: "Add to Codex").shortcut == .addTo)
        #expect(InboxAction.changeToAsk.shortcut == .changeToAsk)
    }
}
