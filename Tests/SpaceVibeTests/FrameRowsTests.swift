import Foundation
import Testing
@testable import SpaceVibe

/// Rows, their status over measured CLIs, the readers map (via, losers, last copy) and the cell wire shape (RD-R10, RD-R11,
/// RD-R12, RD31). Port of the reference mock's `itemStatus`, `losersOf`, `isVia` and the tile rules of `consistency.js`.
@Suite("Frame rows and readers")
struct FrameRowsTests {
    typealias D = FrameTestData

    private func row(_ cells: CoreCLICells, kind: CoreKind = .skill, owner: String = "user", project: String? = nil) -> FrameRow {
        FrameRow.rows(from: D.loadout([D.item("a", kind: kind, owner: owner, project: project, cells: cells)]))[0]
    }

    // MARK: Status

    @Test("a row ran when any CLI counted a use; Never ran only when every counted cell is zero")
    func ranAndNeverRan() {
        #expect(row(["claude": D.sessions(3), "codex": D.sessions(0)]).status == .ran)
        #expect(row(["claude": D.sessions(0), "codex": .missing]).status == .neverRan)
    }

    @Test("Never ran is judged over measured CLIs only: unmeasurable never makes it, unknown beats it")
    func measuredOnly() {
        #expect(row(["claude": .unmeasurable(reason: "x"), "codex": .missing]).status == .unmeasurable)
        #expect(row(["claude": D.sessions(0), "codex": .unmeasurable(reason: "x")]).status == .neverRan)
        #expect(row(["claude": D.sessions(0), "codex": .unknown]).status == .unknown)
        #expect(row(["claude": D.sessions(2), "codex": .unknown]).status == .ran)
        #expect(row(["claude": .scanning, "codex": .missing]).status == .pending)
    }

    @Test("a dead Hook is dead whatever its counts, and a Hook counts runs")
    func hooks() {
        let rows = FrameRow.rows(from: D.loadout(hooks: [D.hook("aa", dead: true, cells: ["claude": D.runs(4)]), D.hook("bb", cells: ["claude": D.runs(0)])]))
        #expect(rows.map(\.status) == [.dead, .neverRan])
        #expect(rows[0].name == "guard.sh")
    }

    @Test("members of one row key become one row, items before Hooks, in the core's order")
    func grouping() {
        let cells: CoreCLICells = ["claude": D.sessions(1), "codex": D.sessions(2)]
        let rows = FrameRow.rows(from: D.loadout([D.item("b", cells: cells), D.item("a", cells: cells), D.item("b", cli: .codex, cells: cells)], hooks: [D.hook("h", cells: [:])]))
        #expect(rows.map(\.id) == ["skill::b", "skill::a", "hook::h"])
        #expect(rows[0].items.count == 2)
        #expect(rows[0].total == 3)
    }

    @Test("a registry CLI with no cell reads as unknown, never as Missing")
    func absentCell() {
        let r = row(["claude": D.sessions(1)])
        #expect(r.presence("codex") == .unknown)
        #expect(r.presence("claude") == .on)
        #expect(row(["claude": .notSupported]).presence("claude") == .notSupported)
        #expect(row(["claude": .missing]).presence("claude") == .off)
    }

    @Test("suggested: a candidate not just added, not plugin-owned, not a project item, not kept (RD26)")
    func suggested() {
        let never: CoreCLICells = ["claude": D.sessions(0), "codex": .missing]
        #expect(row(never).isSuggested(kept: []))
        #expect(!row(never).isSuggested(kept: ["skill::a"]))
        #expect(!row(never, owner: "some-plugin").isSuggested(kept: []))
        #expect(row(never, owner: "link").isSuggested(kept: []))
        #expect(!row(never, project: "/p").isSuggested(kept: []))
        let fresh = row(["claude": D.sessions(0, note: "Added in the last 24 hours"), "codex": .missing])
        #expect(fresh.status == .neverRan && fresh.isRecentlyAdded && !fresh.isSuggested(kept: []))
        #expect(!row(["claude": D.sessions(1)]).isSuggested(kept: []))
    }

    // MARK: Tiles (RD-R12)

    @Test("tile heat is 0 to 3 relative to the item's top CLI, as consistency.js computes it")
    func heat() {
        let r = row(["claude": D.sessions(100), "codex": D.sessions(20), "c3": D.sessions(50), "c4": D.sessions(0), "c5": .missing])
        #expect(["claude", "codex", "c3", "c4", "c5"].map(r.heatStep) == [3, 1, 2, 0, 0])
    }

    @Test("the tile grid never exceeds 3 rows at 2, 3, 6 and 10 CLIs")
    func tileRows() {
        for n in [2, 3, 6, 10, 11] {
            let columns = FrameRow.tileColumns(cliCount: n)
            #expect(columns >= 3 && (n + columns - 1) / columns <= 3, "N=\(n) columns \(columns)")
        }
    }

    // MARK: Readers (RB-E2 input)

    /// pdf-extract of the mock at 6 CLIs: Claude's copy in ~/.claude/skills (read by claude, cursor, opencode, amp), Codex's in
    /// ~/.agents/skills (read by codex, cursor, amp).
    private let shared = ItemReaders(members: [
        "claude:a": MemberFolder(path: "~/.claude/skills", realPath: "/r/claude/a", ownedBy: "claude", readBy: ["claude", "cursor", "opencode", "amp"], isLink: false),
        "codex:a": MemberFolder(path: "~/.agents/skills", realPath: "/r/agents/a", ownedBy: "codex", readBy: ["codex", "cursor", "amp"], isLink: false),
    ])

    @Test("via: a CLI that reads the item only through another CLI's folder (RD31)")
    func via() {
        #expect(shared.via("claude") == nil)
        #expect(shared.via("opencode") == ["claude"])
        #expect(shared.via("cursor") == ["codex", "claude"])
        #expect(shared.via("copilot") == nil)
    }

    @Test("losers: every CLI that reads the item and keeps no member once the removal is done")
    func losers() {
        let all = ["claude", "codex", "cursor", "opencode", "amp", "copilot"]
        #expect(shared.losers(removing: ["claude:a"], among: all) == ["claude", "opencode"])
        #expect(shared.losers(removing: ["claude:a", "codex:a"], among: all) == ["claude", "codex", "cursor", "opencode", "amp"])
        #expect(shared.turningOff("cursor") == ["claude:a", "codex:a"])
    }

    @Test("two members with one real file go together; a link goes alone; the last file is not a toggle (D53)")
    func filesAndLinks() {
        let one = ItemReaders(members: [
            "claude:a": MemberFolder(path: "~/.claude/skills", realPath: "/r/a", ownedBy: "claude", readBy: ["claude"], isLink: false),
            "codex:a": MemberFolder(path: "~/.codex/skills", realPath: "/r/a", ownedBy: "codex", readBy: ["codex"], isLink: false),
            "link:a": MemberFolder(path: "~/.claude/skills", realPath: "/r/a", ownedBy: "claude", readBy: ["claude"], isLink: true),
        ])
        #expect(one.expand(["claude:a"]) == ["claude:a", "codex:a"])
        #expect(one.expand(["link:a"]) == ["link:a"])
        #expect(one.isLastCopy(turningOff: "codex"))
        #expect(!shared.isLastCopy(turningOff: "codex"))
    }

    @Test("without the readers map the world answers unknown, never a guess")
    func unknownWithoutMap() {
        let world = FrameWorld(snapshot: D.snapshot(D.loadout([D.item("a", cells: ["claude": D.sessions(1), "codex": .missing])])), now: D.now)
        let r = world.rows[0]
        #expect(world.losers(of: r, removing: ["claude:skill:a"]) == .unknown)
        #expect(world.via(of: r, cli: "codex") == .unknown)
        var facts = FrameFacts()
        facts.readers = ["skill::a": ItemReaders(members: ["claude:skill:a": MemberFolder(path: "p", realPath: "/r", ownedBy: "claude", readBy: ["claude"], isLink: false)])]
        facts.hidden = ["claude"]
        let hidden = FrameWorld(snapshot: world.snapshot, facts: facts, now: D.now)
        // Claude Code is hidden, so the row leaves the list; it still loses the file ("Show guard").
        #expect(hidden.rows.isEmpty)
        #expect(hidden.losers(of: r, removing: ["claude:skill:a"]) == .known(["claude"]))
    }

    // MARK: Wire

    @Test("every cliCells map of the frozen golden decodes and encodes back to the same JSON")
    func goldenCells() throws {
        let golden = try #require(try CoreTestData.json("fixtures/golden/cli-cells.json") as? [String: Any])
        #expect(try CoreTestData.roundTripDifference(try #require(golden["registry"]), as: CoreRegistryResult.self) == nil)
        var counted = 0
        for phase in ["ready", "scanning"] {
            let rows = try #require(golden[phase] as? [String: Any])
            for (key, cells) in rows {
                #expect(try CoreTestData.roundTripDifference(cells, as: CoreCLICells.self) == nil, "\(phase) \(key)")
                counted += 1
            }
        }
        #expect(counted > 10)
    }

    @Test("the counted, note and unmeasurable shapes round-trip; a restart re-sends clis.registry as a read")
    func cellShapes() throws {
        for text in [
            #"{"state":"counted","sessions":0,"days":[],"last":null,"note":"Added in the last 24 hours"}"#,
            #"{"state":"counted","runs":3,"errors":1,"last":"2026-11-01"}"#,
            #"{"state":"unmeasurable","reason":"This CLI keeps no log SpaceVibe can count"}"#,
            #"{"state":"notSupported"}"#, #"{"state":"unknown"}"#, #"{"state":"scanning"}"#, #"{"state":"missing"}"#,
        ] {
            #expect(try CoreTestData.roundTripDifference(try JSONSerialization.jsonObject(with: Data(text.utf8)), as: CoreCLICell.self) == nil, "\(text)")
        }
        #expect(CoreConnection.readMethods.contains("clis.registry"))
    }
}
