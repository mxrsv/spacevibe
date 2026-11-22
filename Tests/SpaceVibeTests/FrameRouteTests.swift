import Foundation
import Testing
@testable import SpaceVibe

/// The one route value (AR5, RD39, FE7) and the store against the real core on the fixture home (S-R1).
@Suite("Frame route")
@MainActor
struct FrameRouteTests {
    @Test("⌘1 to ⌘8 open the pages in sidebar order: 1 Inbox, 2 Clean, 7 Limits, 8 Activity (RD39)")
    func shortcuts() {
        #expect((1...8).compactMap(FrameRoute.page(forShortcut:)) == FramePage.allCases)
        #expect(FrameRoute.page(forShortcut: 1) == .inbox && FrameRoute.page(forShortcut: 2) == .clean)
        #expect(FrameRoute.page(forShortcut: 7) == .limits && FrameRoute.page(forShortcut: 8) == .activity)
        #expect(FrameRoute.page(forShortcut: 0) == nil && FrameRoute.page(forShortcut: 9) == nil)
        let router = FrameRouter()
        #expect(router.open(shortcut: 6) && router.route.page == .rules)
        #expect(!router.open(shortcut: 9) && router.route.page == .rules)
    }

    @Test("selecting a row never changes the page; another page starts with nothing selected and keeps the scope")
    func selection() {
        let router = FrameRouter(FrameRoute(page: .skills))
        router.select("skill::a")
        #expect(router.route == FrameRoute(page: .skills, selection: "skill::a"))
        router.setScope(.shared("/p"))
        #expect(router.route.selection == nil && router.route.page == .skills)
        router.select("x")
        router.open(.skills)
        #expect(router.route.selection == "x", "opening the page that shows keeps its selection")
        router.open(.rules)
        #expect(router.route == FrameRoute(page: .rules, selection: nil, scope: .shared("/p")))
    }

    @Test("the glance widget and the countdown pill route to a session and a Window")
    func entryPoints() {
        let router = FrameRouter()
        router.go(to: .session("codex:s1"))
        #expect(router.route.page == .activity && router.route.selection == "codex:s1")
        router.go(to: .window("claude:5-hour"))
        #expect(router.route.page == .limits && router.route.selection == "claude:5-hour")
    }

    @Test("an outside route keeps the current scope: a widget click never resets Rules to Global")
    func outsideRouteKeepsScope() {
        let router = FrameRouter(FrameRoute(page: .rules, scope: .shared("/p")))
        router.go(to: .session("claude:s1"))
        #expect(router.route == FrameRoute(page: .activity, selection: "claude:s1", scope: .shared("/p")))
        router.go(to: .window("claude:5-hour"))
        #expect(router.route.scope == .shared("/p"))
    }

    @Test("dialogs close on a page change or an outside route only: a selection, the first-row rule and a scope never count")
    func revisionCountsPagesAndOutsideRoutes() {
        let router = FrameRouter(FrameRoute(page: .inbox))
        let opened = router.revision
        router.select("a")
        router.keepSelection(onPage: .inbox, among: ["b", "c"])
        router.setScope(.shared("/p"))
        router.open(.inbox)
        #expect(router.route.selection == nil && router.revision == opened, "the automatic re-selection keeps a dialog open")
        router.open(.clean)
        #expect(router.revision == opened + 1)
        router.go(to: FrameRoute(page: .clean))
        #expect(router.revision == opened + 2, "an outside route to the page showing still closes a dialog over it")
    }

    @Test("another page's first-row rule never judges with the old page's search: the router clears it first")
    func searchClearedBeforeFirstRow() {
        let search = FrameSearch()
        let router = FrameRouter(FrameRoute(page: .skills), search: search)
        search.text = "lint"
        router.open(.skills)
        #expect(search.text == "lint", "the page showing keeps its search")
        router.open(.hooks)
        #expect(search.text.isEmpty, "cleared inside open, before the new page's rows are judged")
        search.text = "x"
        router.go(to: .session("claude:s1"))
        #expect(search.text.isEmpty, "an outside route clears a search that could hide its row")
    }

    @Test("the widget's session is revealed: Sessions tab, a CLI menu that hides it and the search cleared, then it stays selected")
    func widgetRevealsSession() async {
        let core = FrameFakeCore()
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false), route: FrameRoute(page: .activity),
                               cliPreferences: CLIPreferences(defaults: nil))
        await model.store.start()
        core.push(FrameTestData.activity([FrameTestData.session("s1", cli: .claude, state: .running),
                                          FrameTestData.session("s2", cli: .codex, state: .waiting)]))
        for _ in 0..<200 where model.store.snapshot.activity?.sessions.count != 2 { try? await Task.sleep(for: .milliseconds(5)) }
        let state = ActivityPageState.of(model)
        state.show(.failures, router: model.router)
        state.setScope("codex")
        model.search.text = "nothing matches this"
        model.router.go(to: .session("claude:s1"))
        #expect(state.tab == .sessions && state.scope == nil && model.search.text.isEmpty)
        let shown = ActivityPageData(state.input(model: model)).visibleIDs
        #expect(shown.contains("claude:s1"))
        model.router.keepSelection(onPage: .activity, among: shown)
        #expect(model.router.route.selection == "claude:s1", "the first-row rule keeps the revealed session")
        // A CLI menu on the session's own CLI stays.
        state.setScope("codex")
        model.router.go(to: .session("codex:s2"))
        #expect(state.scope == "codex")
        model.store.stop()
    }

    @Test("RD44: a page opens on its first row; a selection the filter, scope or search hid moves to the first shown row")
    func firstRowSelection() {
        #expect(FrameFirstRow.selection(current: nil, rows: ["a", "b"]) == "a", "the page just opened")
        #expect(FrameFirstRow.selection(current: "b", rows: ["a", "b"]) == "b", "a shown selection stays")
        #expect(FrameFirstRow.selection(current: "x", rows: ["a", "b"]) == "a", "the selected row was hidden")
        #expect(FrameFirstRow.selection(current: "x", rows: []) == nil, "nothing shown, nothing selected")

        let router = FrameRouter(FrameRoute(page: .skills))
        router.keepSelection(onPage: .skills, among: ["skill::a", "skill::b"])
        #expect(router.route.selection == "skill::a")
        router.select("skill::b")
        router.keepSelection(onPage: .skills, among: ["skill::a", "skill::b"])
        #expect(router.route.selection == "skill::b")
        // A search hides the selected row (reviewer B, M1): the inspector must not keep showing it.
        router.keepSelection(onPage: .skills, among: ["skill::a"])
        #expect(router.route.selection == "skill::a")
        // A list that is leaving the screen never selects on the page that replaced it.
        router.open(.hooks)
        router.keepSelection(onPage: .skills, among: ["skill::a"])
        #expect(router.route == FrameRoute(page: .hooks))
        var picked: [String?] = []
        router.keepSelection(onPage: .hooks, among: ["hook::x"]) { picked.append($0) }
        #expect(picked == ["hook::x"], "the page's own select runs instead of the router's")
    }

    @Test("the store on the fixture home: registry, rows with a cell per registry CLI after the scan, rules, and figures")
    func fixtureHome() async throws {
        let fixture = try await CoreFixtureHome.make()
        defer { fixture.remove() }
        let client = try fixture.client()
        defer { client.shutdown() }
        let store = FrameStore(core: client)
        await store.start()
        defer { store.stop() }
        #expect(store.snapshot.registry.map(\.id) == ["claude", "codex"])
        let loadout = try #require(store.snapshot.loadout)
        #expect(loadout.usage == .ready)
        let world = store.world()
        #expect(!world.rows.isEmpty)
        #expect(world.rows.allSatisfy { row in store.snapshot.registry.allSatisfy { row.cells[$0.id] != nil } })
        #expect(store.snapshot.rules[.global] != nil)
        // The readers map names every member's folder, so no row's via or losers is unknown.
        #expect(!loadout.folders.isEmpty)
        #expect(world.rows.allSatisfy { world.readers(of: $0) != nil })
        #expect(world.rows.filter { $0.kind != .hook }.allSatisfy { row in ["claude", "codex"].allSatisfy { world.via(of: row, cli: $0) == .known(nil) } })
        // The core's `wide` flag: the shared HOME allows `Read(*)` (wide) and `Bash(git status:*)` (not), per rules-wide.json.
        #expect(world.wideAllows.map(\.rule.id).contains("global:allow:Read(*)"))
        #expect(!world.wideAllows.map(\.rule.id).contains("global:allow:Bash(git status:*)"))
        for page in FramePage.allCases where page != .activity {
            let figure = world.figure(for: page, loading: store.loading, failed: store.failedEmpty)
            #expect(figure != .pending && figure != .failed, "\(page): \(figure)")
        }
        // The Skills hero is the Never ran skill rows, and Inbox's Clean up rows are the suggested ones of the same set.
        #expect(world.figure(for: .skills, loading: [], failed: []) == .count(world.neverRan(.skill).count, tone: world.neverRan(.skill).isEmpty ? nil : .attention))
        #expect(Set(world.findings.filter { $0.job == .cleanUp }.map(\.id)) == world.suggested.subtracting(world.facts.findings.kept))
    }
}
