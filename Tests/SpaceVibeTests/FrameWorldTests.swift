import Foundation
import Testing
@testable import SpaceVibe

/// The reference mock's `consistency.js` rules that apply to the model: one Never ran set on every surface, hero = sidebar,
/// Inbox can reach zero, page figures while scanning or failed, Clean locks, the N-CLI shape (RD-A6, RD-A9, RD-R10).
@Suite("Frame world consistency")
struct FrameWorldTests {
    typealias D = FrameTestData

    /// A mixed loadout over `registry`: used, Never ran, just added, plugin, project, unknown in Codex, a dead and a Never
    /// ran Hook, a used Hook.
    private func mixed(_ registry: [CoreRegistryCLI] = D.registry) -> FrameSnapshot {
        func cells(_ claude: CoreCLICell, _ codex: CoreCLICell) -> CoreCLICells {
            var out: CoreCLICells = ["claude": claude, "codex": codex]
            for cli in registry.dropFirst(2) { out[cli.id] = cli.supports.skill ? (cli.supports.logs ? .missing : .unmeasurable(reason: "x")) : .notSupported }
            return out
        }
        let never = cells(D.sessions(0), .missing)
        return D.snapshot(D.loadout([
            D.item("used", cells: cells(D.sessions(5), D.sessions(2))),
            D.item("never", cells: never),
            D.item("agent-never", kind: .agent, cells: never),
            D.item("fresh", cells: cells(D.sessions(0, note: "Added in the last 24 hours"), .missing)),
            D.item("plug", owner: "a-plugin", cells: never),
            D.item("proj", project: "/p", cells: never),
            D.item("unread", cells: cells(D.sessions(0), .unknown)),
        ], hooks: [
            D.hook("dead", dead: true, cells: ["claude": D.runs(0)]),
            D.hook("quiet", cells: ["claude": D.runs(0)]),
            D.hook("busy", cells: ["claude": D.runs(7)]),
        ]), registry: registry)
    }

    @Test("one Never ran / Dead set: Inbox Clean up = the suggested candidates, Clean's Agents rows = every candidate")
    func oneSet() {
        for registry in [D.registry, D.registry(count: 3), D.registry(count: 6), D.registry(count: 10)] {
            let w = FrameWorld(snapshot: mixed(registry), now: D.now)
            let inbox = Set(w.findings.filter { $0.job == .cleanUp }.map(\.id))
            #expect(inbox == w.suggested, "N=\(registry.count)")
            #expect(Set(w.clean.agentRows.map(\.id)) == Set(w.candidates.map(\.id)))
            #expect(!w.candidates.contains { $0.id == "skill::used" || $0.id == "hook::busy@claude" })
            #expect(!w.candidates.contains { $0.id == "skill::unread" }, "an unknown cell never makes an item Never ran")
            #expect(w.suggested == ["skill::never", "agent::agent-never", "hook::dead@claude", "hook::quiet@claude"])
        }
    }

    @Test("hero = sidebar: one function gives both, and the Inbox count equals the rows its groups show")
    func heroIsSidebar() {
        let w = FrameWorld(snapshot: mixed(), now: D.now)
        #expect(w.figure(for: .inbox, loading: [], failed: []) == .count(w.groups.map(\.findings.count).reduce(0, +), tone: .critical))
        #expect(w.figure(for: .skills, loading: [], failed: []) == .count(4, tone: .attention))
        #expect(w.figure(for: .subagents, loading: [], failed: []) == .count(1, tone: .attention))
        #expect(w.figure(for: .hooks, loading: [], failed: []) == .count(2, tone: .critical))
        #expect(w.figure(for: .rules, loading: [], failed: []) == .count(0, tone: nil))
        #expect(w.figure(for: .limits, loading: [], failed: []) == .unmeasurable)
        #expect(w.figure(for: .activity, loading: [], failed: []) == .count(0, tone: nil))
        #expect(w.figure(for: .clean, loading: [], failed: []) == .notMeasured, "no clean.scan yet: no byte figure is made up")
    }

    @Test("Inbox can reach zero: an empty home and a home where every finding is kept both read 0 (RD-A9)")
    func zero() {
        let empty = FrameWorld(snapshot: D.snapshot(D.loadout()), now: D.now)
        #expect(empty.findings.isEmpty && empty.groups.isEmpty)
        #expect(empty.figure(for: .inbox, loading: [], failed: []) == .count(0, tone: nil))
        var facts = FrameFacts()
        facts.findings.kept = Set(FrameWorld(snapshot: mixed(), now: D.now).findings.map(\.id))
        let kept = FrameWorld(snapshot: mixed(), facts: facts, now: D.now)
        #expect(kept.figure(for: .inbox, loading: [], failed: []) == .count(0, tone: nil))
        #expect(kept.keptFindings.count == facts.findings.kept.count)
    }

    @Test("while the usage scan runs, the usage pages and Inbox are pending; a source never read that failed is failed")
    func pendingAndFailed() {
        var snapshot = mixed()
        snapshot.loadout?.usage = .scanning
        let w = FrameWorld(snapshot: snapshot, now: D.now)
        for page in [FramePage.inbox, .skills, .subagents, .hooks, .clean] { #expect(w.figure(for: page, loading: [], failed: []) == .pending, "\(page)") }
        #expect(w.figure(for: .rules, loading: [], failed: []) == .count(0, tone: nil))
        #expect(w.figure(for: .limits, loading: [.limits], failed: []) == .pending)
        #expect(w.figure(for: .activity, loading: [], failed: [.activity]) == .failed)
        #expect(w.figure(for: .inbox, loading: [], failed: [.rules(.global)]) == .failed)
    }

    @Test("Limits: a Window at 5% left or less is the hero whatever its pace, and the sidebar shows its share (RD-A9)")
    func limitsHero() {
        var snapshot = mixed()
        snapshot.limits = CoreLimitsResult(limits: [D.limits(id: "weekly", used: 96, minutes: 10080, minutesLeft: 10000), D.limits(.codex, used: 70)])
        let w = FrameWorld(snapshot: snapshot, now: D.now)
        #expect(w.heroWindow?.id == "claude:weekly")
        #expect(w.figure(for: .limits, loading: [], failed: []) == .percentLeft(4, tone: .critical))
    }

    @Test("N CLIs: every row has a cell for every registry CLI, and Not supported is its own presence, not Off (RD-R10)")
    func manyCLIs() {
        for n in [2, 3, 6, 10] {
            let registry = D.registry(count: n)
            let w = FrameWorld(snapshot: mixed(registry), now: D.now)
            #expect(w.clis.count == n)
            for row in w.rows(.skill) { #expect(registry.allSatisfy { row.cells[$0.id] != nil }, "N=\(n) \(row.id)") }
            for cli in registry.dropFirst(2) where !cli.supports.skill {
                #expect(w.rows(.skill).allSatisfy { $0.presence(cli.id) == .notSupported })
            }
            // A CLI with no logs reads Unmeasurable: it never makes an item Never ran on its own (consistency: no counted cell).
            #expect(w.rows(.skill).filter { $0.status == .neverRan }.map(\.id).sorted() == ["skill:/p:proj", "skill::fresh", "skill::never", "skill::plug"])
        }
    }

    @Test("Show guard: a hidden CLI's rows and sessions leave the lists; at least one CLI stays shown")
    func show() {
        var snapshot = D.snapshot(D.loadout([D.item("codex-only", cli: .codex, cells: ["claude": .missing, "codex": D.sessions(1)])]))
        snapshot.activity = D.activity([D.session("w", cli: .codex, state: .waiting)])
        var facts = FrameFacts()
        facts.hidden = ["codex"]
        let w = FrameWorld(snapshot: snapshot, facts: facts, now: D.now)
        #expect(w.clis.map(\.id) == ["claude"] && w.rows.isEmpty && w.sessions.isEmpty)
        #expect(Set(w.clean.locks.logs.keys) == ["codex"], "a hidden CLI's sessions still lock its logs (RD27)")
        facts.hidden = ["claude", "codex"]
        #expect(FrameWorld(snapshot: snapshot, facts: facts, now: D.now).clis.map(\.id) == ["claude"])
    }

    @Test("a bulk removal takes only ticked rows that are shown and writable; it counts rows, not copies")
    func removalSet() {
        let w = FrameWorld(snapshot: mixed(), now: D.now)
        let shown = w.rows(.skill).filter { $0.status == .neverRan }
        let ticked: Set<String> = ["skill::never", "skill::plug", "skill:/p:proj", "agent::agent-never"]
        #expect(w.removalSet(selected: ticked, shown: shown).map(\.id) == ["skill::never"])
    }

    // MARK: Clean (RD27, RD35, CL-R5)

    @Test("locks come from clean.scan with their sentence; a session the live report adds after the scan locks too, never unlocks")
    func locks() {
        let registry = D.registry
        let held = CoreCleanLock(reason: "processes", sessions: [], message: "Codex is running (1 process), so its caches are in use.")
        let scan = D.cleanScan(codex: .init(cli: "codex", logs: .init(state: "measured", buckets: []), caches: [],
                                            locks: .init(logs: nil, caches: held)))
        let quiet = CleanLocks(scan: scan, activity: D.activity([]), registry: registry)
        #expect(quiet.logs.isEmpty, "no lock on the wire, no session: logs are open")
        #expect(quiet.caches["codex"] == CleanLock(reason: .processes, message: held.message), "the core's processes lock and its words")
        let idle = CleanLocks(scan: scan, activity: D.activity([D.session("i", state: .idle), D.session("u", cli: .codex, state: .unmeasurable)]),
                              registry: registry)
        #expect(idle.logs.isEmpty && Set(idle.caches.keys) == ["claude", "codex"], "RD35: an idle session holds its CLI's caches")
        #expect(idle.caches["codex"]?.reason == .processes, "the scan's lock wins over the live one")
        let busy = CleanLocks(scan: scan, activity: D.activity([D.session("r", state: .running), D.session("e", cli: .codex, state: .ended)]),
                              registry: registry)
        #expect(busy.logs["claude"]?.message == "Claude has 1 running session, so its logs stay until it ends.")
        #expect(busy.logs["claude"]?.sessionIDs == ["r"] && busy.logs["codex"] == nil)
        let unknown = CleanLocks(scan: nil, activity: D.activity([], unmeasurable: [CoreActivityLimit(cli: .codex, code: CleanLocks.processUnknownCode, text: "x")]),
                                 registry: registry)
        #expect(unknown.logs["codex"]?.reason == .processUnknown && unknown.caches["codex"]?.reason == .processUnknown)
        #expect(CleanLock(CoreCleanLock(reason: "somethingNew", sessions: [], message: "m")).reason == .processUnknown, "an unknown reason fails closed")
    }

    @Test("what can be cleaned: open rows only; locked and read-only rows never count; the selection is cut to them")
    func cleanable() {
        let w = FrameWorld(snapshot: mixed(), now: D.now)
        let codexLock = CoreCleanLock(reason: "sessions", sessions: ["r"], message: "Codex has 1 running session, so its logs stay until it ends.")
        let scan = D.cleanScan(
            claude: .init(cli: "claude", logs: .init(state: "measured", buckets: [.init(olderThanDays: 90, files: 10, bytes: 1_000)]),
                          caches: [.init(id: "claude:cache", path: "/h/.claude/cache", entries: 1, files: 1, bytes: 50)], locks: .init(logs: nil, caches: nil)),
            codex: .init(cli: "codex", logs: .init(state: "measured", buckets: [.init(olderThanDays: 30, files: 9, bytes: 900), .init(olderThanDays: 90, files: 4, bytes: 400)]),
                         caches: [], locks: .init(logs: codexLock, caches: nil)),
            items: ["skill::never": 7, "agent::agent-never": 3, "skill::plug": 1_000_000])
        let locks = CleanLocks(scan: scan, activity: nil, registry: D.registry)
        let plan = CleanPlan(candidates: w.candidates, kept: [], scan: scan, locks: locks, shownCLIs: ["claude", "codex"])
        // claude logs 1000 + cache 50 + never 7 + agent-never 3 + hooks 0; Codex logs are locked; plug is read-only.
        #expect(plan.cleanableBytes == 1_060)
        #expect(plan.lockedBytes == 400)
        #expect(plan.selectedBytes(["logs:codex", "skill::plug", "claude:cache"]) == 50)
        #expect(!plan.openIDs.contains("skill:/p:proj"))
        #expect(plan.agentRows.first { $0.id == "skill::plug" }?.readOnly == .plugin("a-plugin"))
        let older = CleanPlan(candidates: w.candidates, kept: [], scan: scan, locks: locks, shownCLIs: ["claude", "codex"], logAge: ["codex": 30])
        #expect(older.logs.first { $0.cli == "codex" }?.files == 9)
        let missingAge = CleanPlan(candidates: w.candidates, kept: [], scan: scan, locks: locks, shownCLIs: ["claude", "codex"], logAge: ["claude": 180])
        #expect(missingAge.logs.first { $0.cli == "claude" }?.ageDays == 90, "an age that holds no log falls back to 90 days")
        #expect(CleanPlan(candidates: w.candidates, kept: [], scan: nil, locks: locks, shownCLIs: ["claude"]).selectedBytes(["claude:cache"]) == nil)
    }

    @Test("the sidebar figure follows the log age the page picked (hero = sidebar), and a never-asked scan is no figure")
    func cleanFigureFollowsAge() {
        var snapshot = mixed()
        let scan = D.cleanScan(claude: .init(cli: "claude", logs: .init(state: "measured", buckets: [
            .init(olderThanDays: 30, files: 3, bytes: 3_000), .init(olderThanDays: 90, files: 1, bytes: 1_000)]),
                                             caches: [], locks: .init(logs: nil, caches: nil)), items: [:])
        snapshot.clean = scan
        var facts = FrameFacts()
        let at90 = FrameWorld(snapshot: snapshot, facts: facts, now: D.now).figure(for: .clean, loading: [], failed: [])
        facts.cleanLogAges = ["claude": 30]
        let at30 = FrameWorld(snapshot: snapshot, facts: facts, now: D.now).figure(for: .clean, loading: [], failed: [])
        #expect(at90 == .bytes(1_000) && at30 == .bytes(3_000))
        #expect(FrameWorld(snapshot: snapshot, now: D.now).figure(for: .clean, loading: [.clean], failed: []) == .pending)
        #expect(FrameWorld(snapshot: snapshot, now: D.now).figure(for: .clean, loading: [], failed: [.clean]) == .failed)
    }
}
