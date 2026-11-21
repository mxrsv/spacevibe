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
        for page in FramePage.allCases where page != .activity {
            let figure = world.figure(for: page, loading: store.loading, failed: store.failedEmpty)
            #expect(figure != .pending && figure != .failed, "\(page): \(figure)")
        }
        // The Skills hero is the Never ran skill rows, and Inbox's Clean up rows are the suggested ones of the same set.
        #expect(world.figure(for: .skills, loading: [], failed: []) == .count(world.neverRan(.skill).count, tone: world.neverRan(.skill).isEmpty ? nil : .attention))
        #expect(Set(world.findings.filter { $0.job == .cleanUp }.map(\.id)) == world.suggested.subtracting(world.facts.findings.kept))
    }
}
