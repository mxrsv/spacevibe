import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// A Skills core whose `loadout.copyTo` waits until the test releases it, so a write can be held in flight.
private final class HeldEquipCore: UnservedCore, @unchecked Sendable {
    let registry = EquipShotData.registry(count: 2)
    let rows: CoreLoadoutRows
    private let lock = NSLock()
    private var _copies = 0
    private var _released = false
    var copies: Int { lock.withLock { _copies } }

    override init() {
        rows = EquipShotData.loadout(.skill, specs: EquipShotData.skills, registry: EquipShotData.registry(count: 2), now: Date())
        super.init()
    }

    func release() { lock.withLock { _released = true } }

    override func clisRegistry() async throws -> CoreRegistryResult { CoreRegistryResult(clis: registry) }
    override func loadoutRows() async throws -> CoreLoadoutRows { rows }
    override func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }
    override func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    override func findingsKept() async throws -> CoreKeptFindings { CoreKeptFindings(kept: []) }
    override func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult {
        lock.withLock { _copies += 1 }
        while !lock.withLock({ _released }) { try await Task.sleep(for: .milliseconds(5)) }
        return CoreCopyToResult(entry: FrameTestData.entry("e1"), alsoReaders: [])
    }
}

/// The integration pass over the regions: the window-level dialog slot, the app's one model, the page-state holder, the
/// blocks with one source each, the tile grid's width, the pending logo, search, keys, the toast wording and Clean off the
/// refresh.
@Suite("Frame integration")
@MainActor
struct FrameIntegrationTests {
    typealias D = FrameTestData
    typealias S = InboxSynthetic

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<400 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    private static var sources: URL { StyleBoundaryTests.appSources }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: sources.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: 1. The window-level dialog slot

    @Test("Esc cancels the dialog before anything else, then the overlay inspector and the help")
    func escapeOrder() {
        #expect(FrameEscape.target(hasDialog: true, presentation: .overlay, isHelpOpen: true) == .dialog)
        #expect(FrameEscape.target(hasDialog: false, presentation: .overlay, isHelpOpen: false) == .overlays)
        #expect(FrameEscape.target(hasDialog: false, presentation: .docked, isHelpOpen: true) == .overlays)
        #expect(FrameEscape.target(hasDialog: false, presentation: .docked, isHelpOpen: false) == .nothing)
    }

    @Test("focus goes back where it was before the dialog, the list when that was nothing")
    func focusReturns() {
        #expect(FrameFocusTarget.returning(to: .inspector) == .inspector)
        #expect(FrameFocusTarget.returning(to: .content) == .content)
        #expect(FrameFocusTarget.returning(to: nil) == .content)
        #expect(FrameFocusTarget.returning(to: .dialog) == .content)
    }

    @Test("an open dialog makes the menu bar's commands wait")
    func modalCommands() {
        let model = FrameModel(core: UnservedCore(), toasts: ToastCenter(announce: false))
        let chrome = FrameChrome()
        let target = FrameCommandTarget(model: model, chrome: chrome)
        #expect(!target.isModal)
        chrome.isDialogOpen = true
        #expect(target.isModal)
    }

    @Test("Inbox's confirmation, the per-CLI sheet and Add Rule are the page's dialog, nil while closed")
    func regionDialogs() async {
        let model = FrameModel(core: FrameFakeCore(), toasts: ToastCenter(announce: false), route: FrameRoute(page: .inbox))
        let world = S.world(.normal, clis: 2)
        let inputs = InboxInputs(world: world, figure: world.figure(for: .inbox, loading: [], failed: []), now: S.now)
        let inbox = InboxPageState()
        #expect(FramePageContent.inbox(model: model, fixed: inputs, host: InboxShots.host(.normal), state: inbox).dialog == nil)
        inbox.confirming = InboxConfirmation(items: [], write: .keep(findingID: "x"), rowIDs: [])
        #expect(FramePageContent.inbox(model: model, fixed: inputs, host: InboxShots.host(.normal), state: inbox).dialog?.id == "inbox.confirm")
        inbox.confirming = nil

        let equip = EquipPageState.of(model, kind: .skills)
        #expect(EquipFrame.content(.skills, model: model).dialog == nil)
        equip.openSheet(.add, rows: ["skill::pdf-extract"])
        #expect(EquipFrame.content(.skills, model: model).dialog?.id == "skills.sheet")
        equip.cancelSheet()
        #expect(EquipFrame.content(.skills, model: model).dialog == nil)

        await model.store.start()
        model.store.stop()
        let rules = RulesPageState.of(model)
        #expect(RulesFrame.content(model: model).dialog == nil)
        rules.openAdd()
        #expect(RulesFrame.content(model: model).dialog?.id == "rules.add")
        rules.closeAdd()
        #expect(RulesFrame.content(model: model).dialog == nil)
    }

    @Test("no list draws its own scrim, sheet or overlay host, and no toolbar control waits on a sheet")
    func noRegionScrims() throws {
        for path in ["Inbox/InboxList.swift", "Skills/EquipList.swift", "Rules/RulesList.swift"] {
            let text = try Self.source(path)
            for needle in ["RemoveConfirmation(", "PerCLISheet(", "RulesAddSheet(", ".overlayHost()", "scrimFill"] {
                #expect(!text.contains(needle), "\(path) still holds \(needle)")
            }
        }
        for path in ["Skills/EquipFrame.swift", "Rules/RulesFrame.swift", "Rules/RulesList.swift"] {
            let text = try Self.source(path)
            #expect(!text.contains("sheet != nil)") && !text.contains("addDraft != nil)"), "\(path) still disables a control while a sheet is open")
        }
        #expect(try Self.source("Shell/AppFrame.swift").contains(".overlayHost()"), "the frame hosts every page's popovers")
    }

    // MARK: 2. The app owns the model

    @Test("the app makes the model once and hands it to its windows; no running-store registry is left")
    func appOwnsModel() throws {
        let model = SpaceVibeFrameApp.makeModel(AppEnvironment(toasts: ToastCenter(announce: false), makeCoreClient: { UnservedCore() }))
        _ = AppFrame(model: model)
        _ = SettingsWindowFrame(model: model)
        _ = JournalWindow(model: model)
        let app = try Self.source("App/SpaceVibeApp.swift")
        #expect(app.contains("AppFrame(model: model)") && app.contains("SettingsWindowFrame(model: model)") && app.contains("JournalWindow(model: model)"))
        for path in ["Shell/FrameStore.swift", "Shell/SettingsWindowFrame.swift", "Settings/JournalWindow.swift"] {
            let text = try Self.source(path)
            #expect(!text.contains("FrameStore.running") && !text.contains("weak var running"), "\(path) still reaches a running store")
        }
    }

    // MARK: 3. One page-state holder

    @Test("one page state per type per model, one per page where a type serves two")
    func pageStates() {
        let one = FrameModel(core: UnservedCore(), toasts: ToastCenter(announce: false))
        let two = FrameModel(core: UnservedCore(), toasts: ToastCenter(announce: false))
        #expect(InboxPageState.of(one) === InboxPageState.of(one))
        #expect(InboxPageState.of(one) !== InboxPageState.of(two))
        #expect(HooksPageState.of(one) === HooksPageState.of(one))
        #expect(RulesPageState.of(one) === RulesPageState.of(one))
        #expect(ActivityPageState.of(one) === ActivityPageState.of(one))
        #expect(EquipPageState.of(one, kind: .skills) === EquipPageState.of(one, kind: .skills))
        #expect(EquipPageState.of(one, kind: .skills) !== EquipPageState.of(one, kind: .subagents))
        #expect(one.pageState(InboxPageState.self) { InboxPageState() } === InboxPageState.of(one))
    }

    @Test("no page keeps a registry of its own")
    func noRegistries() throws {
        for path in ["Inbox/InboxRegion.swift", "Hooks/HooksPageState.swift", "Rules/RulesPageState.swift", "Skills/EquipPageState.swift",
                     "Activity/ActivityPageState.swift"] {
            let text = try Self.source(path)
            #expect(!text.contains("private static var") && !text.contains("objc_"), "\(path) still keeps its own registry")
        }
    }

    // MARK: 4. One block per job

    @Test("a row's logos and the inspector's tiles come from one source, on Skills and Inbox alike")
    func oneToggleSource() {
        let world = S.world(.normal, clis: 10)
        let row = world.rows.first { $0.id == "skill::pdf-extract" }!
        let list = EquipListModel.make(kind: .skills, world: world, loading: [], failed: [], failure: nil, view: EquipViewState(), now: S.now)
        #expect(list.row(row.id)?.toggles == CLIToggleStates.states(of: row, in: world))
    }

    @Test("paths, commands and rule text are mono facts; two facts may share a key")
    func monoFacts() {
        #expect(InspectorFact(key: "File", value: "~/.claude/settings.json", isMono: true).valueRole == .mono)
        #expect(InspectorFact(key: "Runs", value: "4").valueRole == .quiet)
        let rows = HooksListModel(world: FrameWorld(snapshot: D.snapshot(D.loadout(hooks: [D.hook("h1", cells: ["claude": D.runs(2)])])), now: D.now),
                                  loading: [], failed: [], failure: nil, view: HooksViewState(), now: D.now)
        let facts = HooksInspectorFacts.facts(rows.all[0], holders: [], now: D.now)
        #expect(facts.first { $0.key == "File" }?.isMono == true)
    }

    // MARK: 5. The tile grid in the inspector

    @Test("the tile grid fits the 336 inspector at every CLI count, Glass and Solid, tiles at 72 while they fit")
    func tileGridWidths() {
        for look in [MaterialLook.glass, .solid] {
            let content = InspectorWidth.wide.points - RadiusRole.sidebarInset(look) - 2 * SpaceRole.step16
            for count in 1...12 {
                let width = CLITileGridLayout.width(count, available: content)
                #expect(width <= content, "\(count) CLIs need \(width) in \(content) (\(look))")
                #expect(CLITileGridLayout.rows(count) <= CLITileGridLayout.maxRows)
                if CLITileGridLayout.columns(count) == 3 { #expect(CLITileGridLayout.tileWidth(count, available: content) == BlockRole.tileWidth) }
            }
            #expect(CLITileGridLayout.columns(10) == 4 && CLITileGridLayout.tileWidth(10, available: content) < BlockRole.tileWidth)
        }
        #expect(CLITileGridLayout.width(10) == 306, "unmeasured, the grid keeps the 72 tiles")
        #expect(CLITileGridLayout.tileWidth(4, available: 0) == BlockRole.tileWidth)
    }

    // MARK: 6. The pending logo

    @Test("a logo whose write runs is pending, and a second press sends nothing")
    func pendingToggle() async throws {
        let core = HeldEquipCore()
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false), route: FrameRoute(page: .skills))
        await model.store.start()
        model.store.stop()
        let state = EquipPageState.of(model, kind: .skills)
        let row = try #require(state.list().row("skill::changelog-writer"))
        let codex = try #require(row.toggles.first { $0.cli.id == "codex" })
        let first = state.press(codex, on: row, from: .row)
        #expect(await eventually { core.copies == 1 })
        #expect(state.pendingToggles(row) == ["codex"])
        #expect(state.press(codex, on: row, from: .row) == nil, "the second press is ignored")
        #expect(!CLIToggleState.acceptsPress(isPending: true) && CLIToggleState.acceptsPress(isPending: false))
        core.release()
        await first?.value
        #expect(core.copies == 1)
        #expect(state.pendingToggles(row).isEmpty)
    }

    // MARK: 7. Search

    @Test("the query keeps rows whose name, description, command or path hold every word, ignoring case and accents")
    func query() {
        let query = FrameSearchQuery("  PDF  tables ")
        #expect(query.words == ["pdf", "tables"])
        #expect(query.matches(["pdf-extract", "Pull text and tables out of PDF files"]))
        #expect(!query.matches(["pdf-extract", nil]))
        #expect(FrameSearchQuery("cafe").matches(["Café"]))
        #expect(FrameSearchQuery("").matches([]))
        #expect(FrameSearchWording.noMatchTitle("skills") == "No skills match")
    }

    @Test("Skills: the search filters the rows, never the hero; nothing left is No skills match")
    func searchSkills() {
        let world = S.world(.normal, clis: 2)
        let all = EquipListModel.make(kind: .skills, world: world, loading: [], failed: [], failure: nil, view: EquipViewState(), now: S.now)
        let found = EquipListModel.make(kind: .skills, world: world, loading: [], failed: [], failure: nil, view: EquipViewState(),
                                        query: FrameSearchQuery("pdf"), now: S.now)
        #expect(found.visible.map(\.name) == ["pdf-extract"] && !found.isSearchMiss)
        #expect(found.heroFigure == all.heroFigure)
        let none = EquipListModel.make(kind: .skills, world: world, loading: [], failed: [], failure: nil, view: EquipViewState(),
                                       query: FrameSearchQuery("zzz-nothing"), now: S.now)
        #expect(none.visible.isEmpty && none.isSearchMiss && none.picked.isEmpty)
    }

    @Test("Hooks, Rules, Inbox and Activity filter their rows by the search and say when nothing matches")
    func searchOtherPages() {
        let hooks = D.loadout(hooks: [D.hook("h1", command: "~/.claude/hooks/lint.sh", cells: ["claude": D.runs(1)]),
                                      D.hook("h2", command: "~/.claude/hooks/notify.sh", cells: ["claude": D.runs(1)])])
        let hooksWorld = FrameWorld(snapshot: D.snapshot(hooks), now: D.now)
        let lint = HooksListModel(world: hooksWorld, loading: [], failed: [], failure: nil, view: HooksViewState(), query: FrameSearchQuery("lint"), now: D.now)
        #expect(lint.visible.map(\.id) == ["hook::h1"] && !lint.isSearchMiss)
        #expect(HooksListModel(world: hooksWorld, loading: [], failed: [], failure: nil, view: HooksViewState(), query: FrameSearchQuery("zzz"), now: D.now).isSearchMiss)

        var snapshot = D.snapshot(D.loadout())
        snapshot.rules = [.global: D.rules([D.rule("Bash"), D.rule("Read(./.env)", verdict: .deny)])]
        let rulesWorld = FrameWorld(snapshot: snapshot, now: D.now)
        let rules = RulesListModel(world: rulesWorld, states: [.rules(.global): .ready], file: .global, view: RulesViewState(),
                                   figure: rulesWorld.figure(for: .rules, loading: [], failed: []), query: FrameSearchQuery(".env"))
        #expect(rules.rows.map(\.rule.rule) == ["Read(./.env)"] && !rules.isSearchMiss)

        let world = S.world(.normal, clis: 2)
        let figure = world.figure(for: .inbox, loading: [], failed: [])
        let everything = InboxPage(world: world, figure: figure, now: S.now)
        let miss = InboxPage(world: world, figure: figure, query: FrameSearchQuery("zzz-nothing"), now: S.now)
        #expect(miss.groups.isEmpty && miss.isSearchMiss && !miss.isClear)
        #expect(miss.hero == everything.hero, "the hero counts every finding")

        let sessions = [D.session("a", state: .running), D.session("b", state: .waiting)]
        let input = ActivityPageInput(clis: D.registry, sessions: sessions, failures: [], hasReport: true, source: .ready,
                                      figure: .count(1, tone: .attention), query: FrameSearchQuery("task b"))
        let activity = ActivityPageData(input)
        #expect(activity.sessionRows.map(\.session.id) == ["b"] && !activity.isSearchMiss)
        var none = input
        none.query = FrameSearchQuery("zzz")
        #expect(ActivityPageData(none).isSearchMiss && ActivityPageData(none).searchItems == "sessions")
    }

    @Test("⌘F asks the field for the focus; another page starts with an empty field")
    func searchState() {
        let search = FrameSearch()
        search.text = "pdf"
        search.requestFocus()
        #expect(search.focusRequest == 1 && search.query.words == ["pdf"])
        search.clear()
        #expect(search.text.isEmpty)
        #expect(FrameShortcut.reserved.contains(FrameCommandMap.find))
    }

    // MARK: 8. Keys

    @Test("a plain-letter action is never a menu key equivalent; the list reads it instead, and only enabled")
    func plainKeys() {
        let stop = FrameRowAction(id: "stop", title: "Stop…", shortcut: FrameShortcut("s", modifiers: []), isDestructive: true) {}
        let keep = FrameRowAction(id: "keep", title: "Keep", shortcut: FrameShortcut("k")) {}
        #expect(stop.menuShortcut == nil && keep.menuShortcut == FrameShortcut("k"))
        #expect(FrameRowAction.plainKey("s", modifiers: [], in: [keep, stop])?.id == "stop")
        #expect(FrameRowAction.plainKey("S", modifiers: .shift, in: [stop])?.id == "stop")
        #expect(FrameRowAction.plainKey("s", modifiers: .command, in: [stop]) == nil)
        #expect(FrameRowAction.plainKey("k", modifiers: [], in: [keep]) == nil, "⌘K is not K")
        let disabled = FrameRowAction(id: "stop", title: "Stop…", shortcut: FrameShortcut("s", modifiers: []), isEnabled: false) {}
        #expect(FrameRowAction.plainKey("s", modifiers: [], in: [disabled]) == nil)
        for key in ["j", "k", "z", "a"] as [Character] {
            let action = FrameRowAction(id: "x", title: "X", shortcut: FrameShortcut(key, modifiers: [])) {}
            #expect(FrameRowAction.conflicts(in: [action]) == [FrameShortcut(key, modifiers: [])], "the frame reads \(key) itself")
        }
    }

    // MARK: 9. The toasts say the mock's sentences

    @Test("removal toasts: the kind and the edited file, the shared and toggle sentences of the mock")
    func toastWording() {
        let hook = FrameRow.rows(from: D.loadout(hooks: [D.hook("h1", command: "~/.claude/hooks/lint-staged.sh", cells: [:])]))
        #expect(FrameWrite.removeMany(hook, registry: D.registry).label == "Removed Hook lint-staged.sh. settings.json was edited")
        #expect(FrameWrite.removedLabel("pdf-extract", lost: ["codex"], D.registry) == "Removed pdf-extract from Codex")
        #expect(RulesWriteWording.removed([D.rule("Bash")], from: "~/.claude/settings.json") == "Removed Rule Bash. settings.json was edited")
    }

    // MARK: 10. Clean is never polled

    @Test("clean.scan runs on readClean and ⌘R only, never on start or the activation refresh")
    func cleanNotPolled() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        var scans = 0
        store.cleanScanner = {
            scans += 1
            return CleanScan()
        }
        let t0 = Date(timeIntervalSince1970: 1_000)
        await store.start(now: t0)
        #expect(scans == 0)
        await store.refresh(now: t0.addingTimeInterval(FrameStore.refreshInterval + 1))
        #expect(scans == 0, "the 10 s refresh never walks the logs")
        await store.readClean()
        #expect(scans == 1 && store.facts.clean == CleanScan() && store.states[.clean] == .ready)
        await store.refresh(force: true, now: t0.addingTimeInterval(2 * FrameStore.refreshInterval + 2))
        #expect(scans == 2, "⌘R reads Clean again")
        store.stop()
    }
}
