import Foundation
import Testing
@testable import SpaceVibe

/// Rows, their status over measured CLIs, the readers map (via, losers, last copy) and the cell wire shape (RD-R10, RD-R11,
/// RD-R12, RD31). Port of the reference mock's `itemStatus` and the tile rules of `consistency.js`, and of the core's
/// readers-map rules.
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

    @Test("RD-R10: a Hook is judged over the CLIs that hold it, so an unreadable Codex never turns a Claude Code-only Never ran Hook unknown; a Skill still does (mock m-model.js:45, :48)")
    func hookIgnoresOtherCLIsUnknown() {
        let hook = FrameRow.rows(from: D.loadout(hooks: [D.hook("aa", cells: ["claude": D.runs(0), "codex": .unknown])]))[0]
        #expect(hook.status == .neverRan && hook.isCandidate)
        #expect(hook.presence("codex") == .unknown)
        #expect(row(["claude": D.sessions(0), "codex": .unknown]).status == .unknown)
        // Its own CLI unreadable: unknown, as the mock's `x.unread`.
        var codex = D.hook("bb", cells: ["claude": .missing, "codex": .unknown])
        codex.cli = .codex
        codex.id = "codex:hook:bb"
        #expect(FrameRow.rows(from: D.loadout(hooks: [codex]))[0].status == .unknown)
    }

    @Test("RD46: a Hook key two CLIs hold is one row per CLI, each <key>@<cli> with its own cell")
    func hookOneCLIPerRow() {
        let cells: CoreCLICells = ["claude": D.runs(0), "codex": .unmeasurable(reason: "Codex logs no hook runs"), "cli2": .notSupported]
        var codex = D.hook("both", cells: cells)
        codex.cli = .codex
        codex.id = "codex:hook:both"
        let loadout = D.loadout(hooks: [codex, D.hook("both", cells: cells), D.hook("solo", cells: ["claude": D.runs(3), "codex": .missing])])
        let rows = FrameRow.rows(from: loadout)
        #expect(rows.map(\.id) == ["hook::both@codex", "hook::both@claude", "hook::solo@claude"])
        #expect(rows[0].hooks.map(\.cli) == [.codex] && rows[1].hooks.map(\.cli) == [.claude])
        #expect(rows[0].cells == ["claude": .missing, "codex": .unmeasurable(reason: "Codex logs no hook runs"), "cli2": .notSupported])
        #expect(rows[1].cells == ["claude": D.runs(0), "codex": .missing, "cli2": .notSupported])
        #expect(rows[0].status == .unmeasurable && rows[1].status == .neverRan)
        #expect(rows[0].presence("claude") == .off && rows[1].presence("codex") == .off)
        // Only Claude Code's row is a candidate SpaceVibe may suggest.
        #expect(rows[1].isSuggested(kept: []) && !rows[0].isSuggested(kept: []))
    }

    @Test("a Hook part keeps its id when another CLI's member of the key comes or goes (build-review M2)")
    func hookIDsStable() {
        let cells: CoreCLICells = ["claude": D.runs(0), "codex": D.runs(0)]
        var codex = D.hook("both", cells: cells)
        codex.cli = .codex
        codex.id = "codex:hook:both"
        let together = FrameRow.rows(from: D.loadout(hooks: [D.hook("both", cells: cells), codex])).map(\.id)
        let codexAlone = FrameRow.rows(from: D.loadout(hooks: [codex])).map(\.id)
        let claudeAlone = FrameRow.rows(from: D.loadout(hooks: [D.hook("both", cells: cells)])).map(\.id)
        #expect(together == ["hook::both@claude", "hook::both@codex"])
        #expect(codexAlone == ["hook::both@codex"], "Codex's part never takes the id Claude Code's had")
        #expect(claudeAlone == ["hook::both@claude"], "Claude Code's part arriving never takes Codex's id")
    }

    @Test("kept Hook findings under the old ids move to the per-CLI ids: Clean up and failing, the bare key's holder only")
    func keptHookIDMoves() {
        let cells: CoreCLICells = ["claude": D.runs(0), "codex": D.runs(0)]
        var codex = D.hook("both", cells: cells)
        codex.cli = .codex
        codex.id = "codex:hook:both"
        var codexOnly = D.hook("cx", cells: cells)
        codexOnly.cli = .codex
        codexOnly.id = "codex:hook:cx"
        let loadout = D.loadout([D.item("s", cells: cells)], hooks: [D.hook("both", cells: cells), codex, codexOnly])
        let kept: Set<String> = ["hook::both", "hook::both@codex:fail", "hook::cx:fail", "skill::s", "hook::gone", "W:claude:5h:1"]
        let moves = FrameRow.keptHookIDMoves(kept: kept, loadout: loadout)
        #expect(moves == [
            FrameRow.KeptIDMove(old: "hook::both", new: "hook::both@claude"),
            FrameRow.KeptIDMove(old: "hook::cx:fail", new: "hook::cx@codex:fail"),
        ], "the key's holder was Claude Code where it has a member, else the only CLI; other ids and gone Hooks stay")
        let migrated = kept.subtracting(moves.map(\.old)).union(moves.map(\.new))
        #expect(FrameRow.keptHookIDMoves(kept: migrated, loadout: loadout).isEmpty, "a second run moves nothing")
        // The moved ids are the ones the findings now carry.
        let rows = FrameRow.rows(from: loadout)
        #expect(rows.map(\.id).contains("hook::both@claude") && rows.map(\.id).contains("hook::cx@codex"))
    }

    @Test("a failing Hook's 7-day errors are its own CLI's, by its row id")
    func hookErrorsPerRow() {
        let week = [CoreHookDay(day: "2026-01-07", runs: 2, errors: 2)]
        let cells: CoreCLICells = ["claude": .runs(count: 4, errors: 2, last: "2026-01-07", note: nil, week: week),
                                   "codex": .runs(count: 9, errors: 5, last: "2026-01-07", note: nil, week: [CoreHookDay(day: "2026-01-07", runs: 9, errors: 5)])]
        var codex = D.hook("both", cells: cells)
        codex.cli = .codex
        codex.id = "codex:hook:both"
        let errors = FindingFacts.hookErrorsLastWeek(in: D.loadout(hooks: [D.hook("both", cells: cells), codex]))
        #expect(errors == ["hook::both@claude": 2, "hook::both@codex": 5])
    }

    @Test("members of one row key become one row, items before Hooks, in the core's order")
    func grouping() {
        let cells: CoreCLICells = ["claude": D.sessions(1), "codex": D.sessions(2)]
        let rows = FrameRow.rows(from: D.loadout([D.item("b", cells: cells), D.item("a", cells: cells), D.item("b", cli: .codex, cells: cells)], hooks: [D.hook("h", cells: [:])]))
        #expect(rows.map(\.id) == ["skill::b", "skill::a", "hook::h@claude"])
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

    @Test("tile heat is 0 to 3 relative to the item's top CLI, as consistency.js computes it, through the one HeatStep rule")
    func heat() {
        let r = row(["claude": D.sessions(100), "codex": D.sessions(20), "c3": D.sessions(50), "c4": D.sessions(0), "c5": .missing])
        let steps = ["claude", "codex", "c3", "c4", "c5"].map(r.heatStep)
        #expect(steps.map(\.rawValue) == [3, 1, 2, 0, 0])
        #expect(steps == ["claude", "codex", "c3", "c4", "c5"].map { HeatStep.step(sessions: r.cell($0).count ?? 0, top: 100) })
    }

    @Test("the tile grid never exceeds 3 rows at 2, 3, 6 and 10 CLIs (the one rule, CLITileGridLayout)")
    func tileRows() {
        for n in [2, 3, 6, 10, 11] {
            let columns = CLITileGridLayout.columns(n)
            #expect(columns >= 3 && (n + columns - 1) / columns <= 3, "N=\(n) columns \(columns)")
            #expect(CLITileGridLayout.rows(n) <= 3, "N=\(n)")
        }
    }

    // MARK: Readers map (ports of TestReadersMapLosers and TestReadersMapVia, core/internal/inventory/readers-map_test.go)

    private static let claudeSkills = D.folder("/h/.claude/skills", readBy: ["claude"], ownedBy: "claude")
    private static let codexSkills = D.folder("/h/.codex/skills", readBy: ["codex"], ownedBy: "codex")
    private static let agentsSkills = D.folder("/h/.agents/skills", readBy: ["codex"], ownedBy: "codex")
    private static let never: CoreCLICells = ["claude": D.sessions(0), "codex": D.sessions(0)]

    private func claudeCopy(realPath: String = "/h/.claude/skills/s") -> CoreInventoryItem {
        D.item("s", cells: Self.never, folder: "/h/.claude/skills", realPath: realPath)
    }

    private func agentsCopy(realPath: String = "/h/.agents/skills/s") -> CoreInventoryItem {
        D.item("s", cli: .codex, cells: Self.never, removable: false, id: "codex:skill:agents:s", folder: "/h/.agents/skills", realPath: realPath)
    }

    /// The world over one row `skill::s`, the extra items read with the v5 ones.
    private func world(_ items: [CoreInventoryItem], extra: [CoreInventoryItem] = [], folders: [CoreReadersFolder]) -> (FrameWorld, FrameRow) {
        var loadout = D.loadout(items)
        loadout.extraItems = extra
        loadout.folders = folders
        let world = FrameWorld(snapshot: D.snapshot(loadout), now: D.now)
        return (world, world.rows[0])
    }

    @Test("a copy in ~/.claude/skills and one in ~/.agents/skills: two files, each removal loses its own reader")
    func claudeAndAgents() {
        let (w, row) = world([claudeCopy()], extra: [agentsCopy()], folders: [Self.agentsSkills, Self.claudeSkills, Self.codexSkills])
        #expect(w.rows.count == 1 && row.items.count == 2, "items and extraItems are one row")
        #expect(w.fileCount(of: row) == .known(2))
        #expect(w.losers(of: row, removing: ["claude:skill:s"]) == .known(["claude"]))
        #expect(w.losers(of: row, removing: ["codex:skill:agents:s"]) == .known(["codex"]))
        #expect(w.isLastCopy(of: row, turningOff: "codex") == .known(false))
    }

    @Test("Codex reads it from two folders: one removal alone loses nobody, both lose Codex, and that is the last file")
    func codexTwoFolders() {
        let own = D.item("s", cli: .codex, cells: Self.never, folder: "/h/.codex/skills", realPath: "/h/.codex/skills/s")
        let (w, row) = world([own], extra: [agentsCopy()], folders: [Self.agentsSkills, Self.claudeSkills, Self.codexSkills])
        #expect(own.id != "codex:skill:agents:s")
        #expect(w.losers(of: row, removing: [own.id]) == .known([]))
        #expect(w.losers(of: row, removing: [own.id, "codex:skill:agents:s"]) == .known(["codex"]))
        #expect(w.isLastCopy(of: row, turningOff: "codex") == .known(true))
        #expect(w.via(of: row, cli: "codex") == .known(nil))
    }

    @Test("~/.agents/skills is a link to ~/.claude/skills: one file both CLIs read, so either removal loses both")
    func agentsLinkedToClaude() {
        let linked = D.folder("/h/.agents/skills", readBy: ["codex"], ownedBy: "codex", realPath: "/h/.claude/skills")
        let (w, row) = world([claudeCopy()], extra: [agentsCopy(realPath: "/h/.claude/skills/s")], folders: [linked, Self.claudeSkills, Self.codexSkills])
        #expect(w.fileCount(of: row) == .known(1))
        #expect(w.losers(of: row, removing: ["claude:skill:s"]) == .known(["claude", "codex"]))
        #expect(w.losers(of: row, removing: ["codex:skill:agents:s"]) == .known(["claude", "codex"]))
        #expect(w.isLastCopy(of: row, turningOff: "claude") == .known(true))
    }

    @Test("Codex's copy is a link to Claude's: removing the link loses Codex only, removing the file loses both")
    func codexLinkToClaude() {
        let link = D.item("s", cli: .codex, owner: "link", cells: Self.never, folder: "/h/.codex/skills", realPath: "/h/.claude/skills/s")
        let (w, row) = world([claudeCopy(), link], folders: [Self.agentsSkills, Self.claudeSkills, Self.codexSkills])
        #expect(w.fileCount(of: row) == .known(1))
        #expect(w.losers(of: row, removing: [link.id]) == .known(["codex"]))
        #expect(w.losers(of: row, removing: ["claude:skill:s"]) == .known(["claude", "codex"]), "the link would dangle")
        #expect(w.isLastCopy(of: row, turningOff: "codex") == .known(false))
        #expect(w.isLastCopy(of: row, turningOff: "claude") == .known(true))
    }

    @Test("via is a pure function of the table: with Claude Code and Codex nobody is via; another CLI's reader is (RD31)")
    func via() throws {
        let (w, row) = world([claudeCopy()], extra: [agentsCopy()], folders: [Self.agentsSkills, Self.claudeSkills, Self.codexSkills])
        #expect(w.via(of: row, cli: "claude") == .known(nil) && w.via(of: row, cli: "codex") == .known(nil))
        let table = [
            D.folder("/h/.claude/skills", readBy: ["claude", "cursor"], ownedBy: "claude"),
            D.folder("/h/.agents/skills", readBy: ["codex", "cursor"], ownedBy: "codex"),
            D.folder("/h/.cursor/skills", readBy: ["cursor"], ownedBy: "cursor"),
        ]
        let shared = try #require(ItemReaders(row: row, folders: table))
        #expect(shared.via("cursor") == ["claude", "codex"])
        let cursorCopy = D.item("s", cli: .codex, cells: Self.never, id: "cursor:skill:s", folder: "/h/.cursor/skills", realPath: "/h/.cursor/skills/s")
        let own = try #require(ItemReaders(row: FrameRow.rows(from: D.loadout([claudeCopy(), cursorCopy]))[0], folders: table))
        #expect(own.via("cursor") == nil, "a CLI with its own copy is not via")
        #expect(shared.losers(removing: shared.expand(["claude:skill:s"]), among: ["claude", "codex", "cursor"]) == ["claude"])
    }

    @Test("a member the table does not name, or a core without the map, answers unknown, never a guess")
    func unknownWithoutMap() {
        let (w, row) = world([claudeCopy()], folders: [])
        #expect(w.losers(of: row, removing: ["claude:skill:s"]) == .unknown)
        #expect(w.via(of: row, cli: "codex") == .unknown)
        #expect(w.isLastCopy(of: row, turningOff: "claude") == .unknown)
        let (partial, partialRow) = world([claudeCopy(), D.item("s", cli: .codex, cells: Self.never)], folders: [Self.claudeSkills])
        #expect(partial.fileCount(of: partialRow) == .unknown)
    }

    @Test("a hidden CLI's rows leave the list, but it still loses the file (Show guard)")
    func hiddenStillLoses() {
        var loadout = D.loadout([D.item("a", cells: ["claude": D.sessions(1), "codex": .missing], folder: "/h/.claude/skills", realPath: "/h/.claude/skills/a")])
        loadout.folders = [Self.claudeSkills]
        var facts = FrameFacts()
        facts.hidden = ["claude"]
        let hidden = FrameWorld(snapshot: D.snapshot(loadout), facts: facts, now: D.now)
        #expect(hidden.rows.isEmpty)
        let row = FrameRow.rows(from: loadout)[0]
        #expect(hidden.losers(of: row, removing: ["claude:skill:a"]) == .known(["claude"]))
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
