import Foundation
import Testing
@testable import SpaceVibe

/// Inbox findings (RD-R4 "What counts", RD26, RD-A9; "Inferred, not decided": Keep, Balance finding, Keep on watch
/// findings, Project rules in Inbox).
@Suite("Inbox findings")
struct FindingsTests {
    typealias D = FrameTestData

    private func world(_ snapshot: FrameSnapshot, facts: FrameFacts = FrameFacts()) -> FrameWorld {
        FrameWorld(snapshot: snapshot, facts: facts, now: D.now)
    }

    private let never: CoreCLICells = ["claude": D.sessions(0), "codex": .missing]

    // MARK: Rules

    /// The rules of the frozen `rules-wide.json` (fixture `rules-home/main` and the shared HOME), with the `wide` the core
    /// gives each: only those flagged wide and allowed are Control findings, whatever their text looks like.
    @Test("a whole-tool rule is the core's `wide` flag on an allow rule (RD-R17); the shell never re-derives it")
    func wholeTool() {
        let file = D.rules([
            D.rule("Read", wide: true), D.rule("Read(*)", wide: true), D.rule("WebSearch", wide: true),
            D.rule("Bash(git status:*)"), D.rule("mcp__demo__lookup"), D.rule("not a rule!"),
            D.rule("WebFetch(domain:github.com)"), D.rule("Bash(git push *)", verdict: .ask),
            D.rule("Edit", verdict: .ask, wide: true), D.rule("Read(.env*)", verdict: .deny),
        ])
        #expect(WholeToolRule.allows(in: file, file: .global).map(\.rule) == ["Read", "Read(*)", "WebSearch"])
        #expect(WholeToolRule.isWide(D.rule("Edit", verdict: .ask, wide: true)), "wide is independent of the verdict")
    }

    @Test("allow rules that allow a whole tool count in every file read, global and each project's Shared and Local")
    func projectFiles() {
        var snapshot = D.snapshot(D.loadout())
        snapshot.rules = [
            .global: D.rules([D.rule("Bash", wide: true), D.rule("Bash", verdict: .deny, wide: true), D.rule("Read(./src/**)")], projects: ["/p"]),
            .shared("/p"): D.rules([D.rule("Bash", file: .shared("/p"), wide: true)], file: .shared("/p")),
            .local("/p"): D.rules([D.rule("Edit", file: .local("/p"), wide: true)], file: .local("/p")),
        ]
        let w = world(snapshot)
        #expect(w.wideAllows.map(\.file) == [.global, .shared("/p"), .local("/p")])
        #expect(Set(w.findings.map(\.id)).count == 3, "one rule id in two files must give two findings")
        #expect(w.figure(for: .rules, loading: [], failed: []) == .count(3, tone: .attention))
    }

    @Test("a reading of another file than the one asked (an unknown project read as global) adds nothing")
    func misreadFile() {
        let read = D.rules([D.rule("Bash", wide: true)])
        #expect(WholeToolRule.allows(in: read, file: .shared("/gone")).isEmpty)
        #expect(WholeToolRule.allows(in: read, file: .global).count == 1)
    }

    // MARK: What counts

    @Test("Clean up: dead Hooks critical, Never ran attention; just added, plugin and project items are never findings")
    func cleanUp() {
        let snapshot = D.snapshot(D.loadout([
            D.item("old", cells: never),
            D.item("fresh", cells: ["claude": D.sessions(0, note: "Added in the last 24 hours"), "codex": .missing]),
            D.item("plug", owner: "a-plugin", cells: never),
            D.item("proj", project: "/p", cells: never),
            D.item("used", cells: ["claude": D.sessions(4), "codex": .missing]),
        ], hooks: [D.hook("dd", dead: true, cells: ["claude": D.runs(0)])]))
        let w = world(snapshot)
        #expect(w.findings.map(\.id) == ["hook::dd", "skill::old"])
        #expect(w.findings.map(\.severity) == [.critical, .attention])
        // The Skills hero still counts every Never ran row: plugin and project items are a fact, only never suggested (RD-R2).
        #expect(w.figure(for: .skills, loading: [], failed: []) == .count(4, tone: .attention))
        #expect(w.figure(for: .inbox, loading: [], failed: []) == .count(2, tone: .critical))
    }

    @Test("a Hook fails only on errors in the last 7 days; lifetime errors never count (RD26)")
    func failingHooks() {
        let snapshot = D.snapshot(D.loadout(hooks: [D.hook("hh", cells: ["claude": D.runs(9, errors: 9)])]))
        #expect(world(snapshot).findings.isEmpty)
        var facts = FrameFacts()
        facts.findings.hookErrorsLastWeek = ["hook::hh": 2]
        let failing = world(snapshot, facts: facts).findings
        #expect(failing.map(\.id) == ["hook::hh:fail"])
        #expect(failing.first?.job == .control)
    }

    @Test("Watch: Windows behind pace and waiting sessions; a Window on pace and a running session are not findings")
    func watch() {
        var snapshot = D.snapshot(D.loadout())
        snapshot.limits = CoreLimitsResult(limits: [D.limits(id: "5-hour", used: 70), D.limits(.codex, id: "5-hour", used: 20)])
        snapshot.activity = D.activity([D.session("w", state: .waiting), D.session("r", state: .running)])
        let w = world(snapshot)
        #expect(w.findings.map(\.job) == [.watch, .watch])
        #expect(w.findings.map(\.id).contains("S:claude:w"))
        #expect(w.groups.map(\.job) == [.watch])
        #expect(w.figure(for: .activity, loading: [], failed: []) == .count(1, tone: .attention))
    }

    @Test("Balance: at most one, the most-used item missing in a pinned CLI, none below two pins")
    func balance() {
        let rows = FrameRow.rows(from: D.loadout([
            D.item("big", cells: ["claude": D.sessions(30), "codex": .missing]),
            D.item("small", cells: ["claude": D.sessions(3), "codex": .missing]),
            D.item("unknown", cells: ["claude": D.sessions(99), "codex": .unknown]),
            D.item("both", cells: ["claude": D.sessions(50), "codex": D.sessions(1)]),
        ]))
        #expect(Findings.balance(rows: rows, pinned: ["claude"]) == nil)
        let found = Findings.balance(rows: rows, pinned: ["claude", "codex"])
        #expect(found?.id == "bal:skill::big")
        #expect(found?.severity == .info)
        if case .balance(_, let missing, let sessions)? = found?.subject { #expect(missing == "codex" && sessions == 30) } else { Issue.record("no Balance subject") }
    }

    // MARK: Keep (RD-A9)

    @Test("a kept finding leaves the count and the groups, sits in kept, and comes back when no longer kept")
    func keep() {
        let snapshot = D.snapshot(D.loadout([D.item("old", cells: never)]))
        var facts = FrameFacts()
        facts.findings.kept = ["skill::old"]
        let kept = world(snapshot, facts: facts)
        #expect(kept.findings.isEmpty && kept.keptFindings.map(\.id) == ["skill::old"])
        #expect(kept.figure(for: .inbox, loading: [], failed: []) == .count(0, tone: nil))
        #expect(kept.clean.agentRows.map(\.isSuggested) == [false])
        facts.findings.kept = []
        #expect(world(snapshot, facts: facts).findings.map(\.id) == ["skill::old"])
    }

    @Test("a kept Window comes back with the next Window: its id carries the reset time")
    func keptWindowReturns() {
        var snapshot = D.snapshot(D.loadout())
        snapshot.limits = CoreLimitsResult(limits: [D.limits(used: 70, minutesLeft: 150)])
        let first = world(snapshot).findings[0].id
        var facts = FrameFacts()
        facts.findings.kept = [first]
        #expect(world(snapshot, facts: facts).findings.isEmpty)
        snapshot.limits = CoreLimitsResult(limits: [D.limits(used: 70, minutesLeft: 140)])
        #expect(world(snapshot, facts: facts).findings.count == 1)
    }

    @Test("the groups follow page order and carry their highest severity once")
    func groups() {
        var snapshot = D.snapshot(D.loadout([D.item("old", cells: never)], hooks: [D.hook("dd", dead: true, cells: ["claude": D.runs(0)])]))
        snapshot.rules = [.global: D.rules([D.rule("Bash", wide: true)])]
        snapshot.activity = D.activity([D.session("w", state: .waiting)])
        let groups = world(snapshot).groups
        #expect(groups.map(\.job) == [.cleanUp, .control, .watch])
        #expect(groups.map(\.severity) == [.critical, .attention, .attention])
        #expect(groups.map(\.findings.count).reduce(0, +) == world(snapshot).findings.count)
    }
}
