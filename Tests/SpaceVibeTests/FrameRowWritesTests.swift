import Foundation
import Testing
@testable import SpaceVibe

/// What a test sees of the write path at each core call: the call, whether the control is pending, and the toast shown.
@MainActor
final class WritePathLog {
    private(set) var lines: [String] = []
    func add(_ line: String) { lines.append(line) }
}

/// The new frame's writes over the fake core (RB-E3, RB-E4, RB-E5; AR4): pending at the control during the call, then the
/// toast built from the core's answer with one Undo, then exactly the touched sources read again; a refusal is the
/// refused-write toast and still reads again.
@Suite("Frame writes: per-CLI, batch and Keep")
@MainActor
struct FrameRowWritesTests {
    typealias D = FrameTestData

    private let registry = D.registry + [D.cli("cursor")]

    private func setUp() async -> (FrameFakeCore, FrameStore, FrameWrites, ToastCenter) {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        core.reset()
        let toasts = ToastCenter(announce: false)
        return (core, store, FrameWrites(core: core, store: store, toasts: toasts), toasts)
    }

    private func row(_ items: [CoreInventoryItem], hooks: [CoreInventoryHook] = []) -> [FrameRow] {
        FrameRow.rows(from: D.loadout(items, hooks: hooks))
    }

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    @Test("copyTo: pending during the call, then the toast naming who reads the same folder, then the loadout read again")
    func copyToSequence() async {
        let (core, store, writes, toasts) = await setUp()
        let a = row([D.item("a", cells: ["claude": D.sessions(1), "codex": .missing])])[0]
        let log = WritePathLog()
        core.alsoReaders = ["cursor"]
        core.onCall = { name in await MainActor.run { log.add("\(name) pending=\(writes.isPending("copyTo:skill::a")) toast=\(toasts.current?.message ?? "-")") } }
        let ok = await writes.perform(.copyTo(a, targets: ["codex"], registry: registry))
        let toast = "Added a to Codex. Cursor reads the same folder, so it has it too"
        #expect(ok)
        #expect(log.lines.first == "loadout.copyTo pending=true toast=-", "nothing shows before the core answers")
        #expect(Set(log.lines.dropFirst()) == Set(["inventory.read", "loadout.rows", "journal.history"].map { "\($0) pending=true toast=\(toast)" }))
        #expect(core.sent["loadout.copyTo"] == "claude:skill:a [\"codex\"]")
        #expect(toasts.current?.message == toast && toasts.undoStack.count == 1 && writes.pending.isEmpty)
        core.onCall = nil
        core.reset()
        toasts.undoLast()
        #expect(await eventually { core.count("loadout.rows") == 1 && !toasts.isUndoing })
        #expect(core.calls.first == "journal.undo:e1")
        store.stop()
    }

    @Test("copyTo into a folder nobody else reads names only the targets")
    func copyToAlone() async {
        let (_, store, writes, toasts) = await setUp()
        let a = row([D.item("a", cells: ["claude": D.sessions(1), "codex": .missing])])[0]
        await writes.perform(.copyTo(a, targets: ["codex", "cursor"], registry: registry))
        #expect(toasts.current?.message == "Added a to Codex and Cursor")
        store.stop()
    }

    @Test("removeFrom names who lost the item (the mock's toggle toast); nobody lost it is a copy")
    func removeFromToast() async {
        let (core, store, writes, toasts) = await setUp()
        let a = row([D.item("a", cells: ["claude": D.sessions(1), "codex": D.sessions(0)]), D.item("a", cli: .codex, cells: [:])])[0]
        core.lost = ["codex"]
        core.stillHave = ["claude"]
        await writes.perform(.removeFrom(a, clis: ["codex"], registry: registry))
        #expect(toasts.current?.message == "Removed a from Codex")
        #expect(core.sent["loadout.removeFrom"] == "claude:skill:a [\"codex\"]")
        core.lost = []
        core.stillHave = ["claude", "codex"]
        await writes.perform(.removeFrom(a, clis: ["codex"], registry: registry))
        #expect(toasts.current?.message == "Removed a copy of a")
        store.stop()
    }

    @Test("a refused removeFrom: the core's sentence in a danger toast, no Undo, and the loadout read again")
    func removeFromRefused() async {
        let (core, store, writes, toasts) = await setUp()
        let a = row([D.item("a", cells: ["claude": D.sessions(1), "codex": .missing])])[0]
        let sentence = "a is one file that Claude Code and Codex read, so it can only be removed from all of them at once. Nothing was changed."
        core.writeResult = .failure(CoreError(sentence, status: 409))
        let ok = await writes.perform(.removeFrom(a, clis: ["claude"], registry: registry))
        #expect(!ok)
        #expect(core.calls.first == "loadout.removeFrom")
        #expect(Set(core.calls.dropFirst()) == ["inventory.read", "loadout.rows", "journal.history"])
        #expect(toasts.current?.message == sentence && toasts.current?.tone == .danger && toasts.undoStack.isEmpty)
        store.stop()
    }

    @Test("Remove N selected: one call with every member id of each row, one toast that counts rows, one Undo")
    func removeManySelection() async {
        let (core, store, writes, toasts) = await setUp()
        let agents = D.item("a", cli: .codex, cells: [:], removable: false, id: "codex:skill:agents:a")
        let rows = row([D.item("a", cells: ["claude": D.sessions(0), "codex": D.sessions(0)]), agents, D.item("b", kind: .agent, cells: [:])],
                       hooks: [D.hook("hh", cells: ["claude": D.runs(0)])])
        core.lost = ["claude", "codex"]
        await writes.perform(.removeMany(rows, registry: registry))
        #expect(core.sent["loadout.removeMany"] == "[\"claude:skill:a\", \"codex:skill:agents:a\", \"claude:agent:b\", \"claude:hook:hh\"]")
        #expect(core.count("loadout.removeMany") == 1)
        #expect(toasts.current?.message == "Removed Skill a, Subagent b and Hook \(rows[2].name) from Claude and Codex. settings.json was edited")
        #expect(toasts.undoStack.count == 1)
        await writes.perform(.removeMany([rows[0]], registry: registry))
        #expect(toasts.current?.message == "Removed Skill a from Claude and Codex")
        store.stop()
    }

    @Test("the removal set takes a row whose only copy is in ~/.agents/skills: the new methods may remove it")
    func removalSetTakesSharedSkills() {
        let agents = D.item("s", cli: .codex, cells: ["claude": .missing, "codex": D.sessions(0)], removable: false, id: "codex:skill:agents:s")
        var loadout = D.loadout()
        loadout.extraItems = [agents]
        let world = FrameWorld(snapshot: D.snapshot(loadout), now: D.now)
        #expect(world.rows.first?.removableMembers.isEmpty == true)
        #expect(world.removalSet(selected: ["skill::s"], shown: world.rows).map(\.id) == ["skill::s"])
        let plugin = FrameRow.rows(from: D.loadout([D.item("p", owner: "a-plugin", cells: [:], removable: false)]))
        #expect(world.removalSet(selected: ["skill::p"], shown: plugin).isEmpty)
    }

    @Test("rules.removeMany is one write per file and reads only that file again")
    func removeRules() async {
        let (core, store, writes, toasts) = await setUp()
        let file = FrameScope.shared("/p")
        let rules = [D.rule("Bash", file: file, wide: true), D.rule("Read", file: file, wide: true)]
        await writes.perform(.removeRules(rules, in: file))
        #expect(core.calls.first == "rules.removeMany")
        #expect(Set(core.calls.dropFirst()) == ["rules.snapshot:project:/p", "journal.history"])
        #expect(core.sent["rules.removeMany"] == "project /p [\"project:allow:Bash\", \"project:allow:Read\"]")
        #expect(toasts.current?.message == "Removed 2 Rules" && toasts.undoStack.count == 1)
        await writes.perform(.removeRules([rules[0]], in: file))
        #expect(toasts.current?.message == "Removed Rule Bash")
        store.stop()
    }

    @Test("Keep and Undo: journaled, the Keep list read again, and the finding leaves the count")
    func keepAndUndo() async {
        let (core, store, writes, toasts) = await setUp()
        await writes.perform(.keep(findingID: "skill::old"))
        #expect(core.calls.first == "findings.keep" && core.sent["findings.keep"] == "skill::old")
        #expect(Set(core.calls.dropFirst()) == ["findings.kept", "journal.history"])
        #expect(store.facts.findings.kept == ["skill::old"])
        #expect(toasts.current?.message == "Kept. It no longer counts in Inbox; Show Kept lists it." && toasts.undoStack.count == 1)
        core.reset()
        core.kept = []
        toasts.undoLast()
        #expect(await eventually { core.count("findings.kept") == 1 && !toasts.isUndoing })
        #expect(core.calls.first == "journal.undo:e1")
        #expect(store.facts.findings.kept.isEmpty)
        await writes.perform(.unkeep(findingID: "skill::old"))
        #expect(toasts.current?.message == "Counted in Inbox again.")
        store.stop()
    }
}

/// The store fills the derivations' engine inputs (RB-E5): the Keep list and hook errors in the last 7 days.
@Suite("Frame store: Keep list and hook errors")
@MainActor
struct FrameStoreEngineFactsTests {
    typealias D = FrameTestData

    @Test("start reads the Keep list into the facts; kept findings leave Inbox's count")
    func keptAtStart() async {
        let core = FrameFakeCore()
        core.kept = ["skill::old"]
        core.loadout = D.loadout([D.item("old", cells: ["claude": D.sessions(0), "codex": .missing])])
        let store = FrameStore(core: core)
        await store.start()
        #expect(core.count("findings.kept") == 1)
        #expect(store.facts.findings.kept == ["skill::old"])
        let world = store.world(now: D.now)
        #expect(world.findings.isEmpty && world.keptFindings.map(\.id) == ["skill::old"])
        store.stop()
    }

    @Test("a Keep list never read that fails makes Inbox failed; one read before stays when a later read fails")
    func keptFailure() async {
        let core = FrameFakeCore()
        core.failing = ["findings.kept"]
        let store = FrameStore(core: core)
        await store.start()
        #expect(store.failedEmpty.contains(.kept))
        #expect(store.world(now: D.now).figure(for: .inbox, loading: store.loading, failed: store.failedEmpty) == .failed)
        core.failing = []
        core.kept = ["x"]
        await store.reread([.kept])
        core.failing = ["findings.kept"]
        await store.reread([.kept])
        #expect(store.facts.findings.kept == ["x"] && !store.failedEmpty.contains(.kept))
        store.stop()
    }

    @Test("Inbox waits for the Keep list: kept findings are never counted first")
    func inboxWaitsForKept() {
        let world = FrameWorld(snapshot: D.snapshot(D.loadout()), now: D.now)
        #expect(world.figure(for: .inbox, loading: [.kept], failed: []) == .pending)
    }

    @Test("each loadout.rows fills the hook errors of the last 7 days from the cells; a Hook erring this week fails")
    func hookErrors() async {
        let core = FrameFakeCore()
        let week = [CoreHookDay(day: "2026-11-19", runs: 4, errors: 0), CoreHookDay(day: "2026-11-20", runs: 3, errors: 2)]
        core.loadout = D.loadout(hooks: [
            D.hook("hh", cells: ["claude": .runs(count: 7, errors: 9, last: nil, note: nil, week: week)]),
            D.hook("ok", cells: ["claude": .runs(count: 7, errors: 9, last: nil, note: nil, week: [CoreHookDay(day: "2026-11-20", runs: 7, errors: 0)])]),
            D.hook("old", cells: ["claude": D.runs(7, errors: 9)]),
        ])
        let store = FrameStore(core: core)
        await store.start()
        #expect(store.facts.findings.hookErrorsLastWeek == ["hook::hh@claude": 2, "hook::ok@claude": 0], "a cell with no week is unknown, not 0")
        let failing = store.world(now: D.now).findings.filter { $0.job == .control }
        #expect(failing.map(\.id) == ["hook::hh@claude:fail"])
        if case .failingHook(_, let errors)? = failing.first?.subject { #expect(errors == 2) } else { Issue.record("no failing Hook") }
        store.stop()
    }
}

/// `firstSeen` (RB-E5), `statusline.at` and links to one file from another row (RB-E3) in the pure model.
@Suite("Frame world: firstSeen, status line age, links from other rows")
struct FrameWorldEngineFieldsTests {
    typealias D = FrameTestData

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func item(_ name: String, seen: TimeInterval?, note: String? = nil) -> CoreInventoryItem {
        var item = D.item(name, cells: ["claude": D.sessions(0, note: note), "codex": .missing])
        item.firstSeen = seen.map { Self.iso(D.now.addingTimeInterval(-$0)) }
        return item
    }

    @Test("added in the last day is one rule: the D63 note, or firstSeen under 24 hours where no cell has the note")
    func addedRule() {
        var dead = D.hook("dd", dead: true, cells: ["claude": D.runs(4)])
        dead.firstSeen = Self.iso(D.now.addingTimeInterval(-3_600))
        let snapshot = D.snapshot(D.loadout([
            item("new", seen: 2 * 3_600), item("old", seen: 30 * 3_600), item("unseen", seen: nil),
            item("late", seen: 30 * 3_600, note: "Added after the newest log"),
        ], hooks: [dead]))
        let world = FrameWorld(snapshot: snapshot, now: D.now)
        #expect(world.findings.map(\.id) == ["skill::old", "skill::unseen"])
        #expect(world.rows.first { $0.id == "hook::dd@claude" }?.isRecentlyAdded == true, "a dead Hook that ran has no note; firstSeen decides")
        #expect(world.suggested == ["skill::old", "skill::unseen"])
        #expect(FrameRow.rows(from: snapshot.loadout!).first { $0.id == "skill::new" }?.isRecentlyAdded == false, "without a clock only the note decides")
    }

    @Test("statusline.at is the age Settings › Limits shows, not the Claude entry's at")
    func statuslineAt() {
        var snapshot = D.snapshot(D.loadout())
        #expect(FrameWorld(snapshot: snapshot, now: D.now).statuslineAt == nil)
        snapshot.limits = CoreLimitsResult(limits: [D.limits(used: 10, readAgo: 60)], statusline: CoreLimitsStatusline(at: D.now.timeIntervalSince1970 - 720))
        #expect(FrameWorld(snapshot: snapshot, now: D.now).statuslineAt == D.now.addingTimeInterval(-720))
    }

    /// The engine's `TestRemoveFromSeesALinkInAnotherRow`: Codex's `bar` is a link to Claude's `foo` (its SKILL.md has no
    /// name, so each is named after its folder and they are two rows).
    @Test("a link in another row to the row's file: removing the file loses that link's reader too, as the engine refuses")
    func linkInAnotherRow() throws {
        let foo = D.item("foo", cells: ["claude": D.sessions(0), "codex": .missing], folder: "/h/.claude/skills", realPath: "/h/.claude/skills/foo")
        let bar = D.item("bar", cli: .codex, owner: "link", cells: ["claude": .missing, "codex": D.sessions(0)], folder: "/h/.codex/skills",
                         realPath: "/h/.claude/skills/foo")
        var loadout = D.loadout([foo, bar])
        loadout.folders = [D.folder("/h/.claude/skills", readBy: ["claude"], ownedBy: "claude"), D.folder("/h/.codex/skills", readBy: ["codex"], ownedBy: "codex")]
        let world = FrameWorld(snapshot: D.snapshot(loadout), now: D.now)
        let fooRow = try #require(world.rows.first { $0.id == "skill::foo" })
        let barRow = try #require(world.rows.first { $0.id == "skill::bar" })
        #expect(world.losers(of: fooRow, removing: [foo.id]) == .known(["claude", "codex"]), "Codex would keep a dangling link")
        #expect(world.fileReaders(of: fooRow, removing: [foo.id]) == .known(["claude", "codex"]))
        let readers = try #require(world.readers(of: fooRow))
        #expect(readers.expand([foo.id]) == [foo.id, bar.id] && readers.reachesOtherRows(readers.expand([foo.id])))
        #expect(world.isLastCopy(of: fooRow, turningOff: "claude") == .known(true), "the link is not a copy of the row")
        #expect(world.losers(of: barRow, removing: [bar.id]) == .known(["codex"]), "removing the link takes only the link")
        #expect(world.readers(of: barRow)?.elsewhere.isEmpty == true, "a link's own file is not the row's to take")
    }
}
