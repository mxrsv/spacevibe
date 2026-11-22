import Foundation
import Testing
@testable import SpaceVibe

/// Serves Clean's two writes and records them in order; reads answer empty so the re-read after a write succeeds.
private final class CleanFakeCore: UnservedCore, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [String] = []
    var removeResult: Result<CoreJournalEntry, CoreError> = .success(FrameTestData.entry("e-equip", label: "Removed 2 items"))
    var moveResult: Result<CoreCleanMoveResult, CoreError> = .success(CleanWriteTests.moved())
    /// The move waits for its cancel, then answers with what moved so far (`cancelled`), as the core does after a file.
    var blocksUntilCancelled = false
    /// The move refuses with -32800, as the core does when cancelled before the first file.
    var cancelledBeforeFirstFile = false
    var progressNotes: [CoreCleanProgress] = []

    var calls: [String] { lock.withLock { _calls } }
    private func record(_ call: String) { lock.withLock { _calls.append(call) } }

    override func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult {
        record("loadout.removeMany \(ids)")
        return CoreRemoveManyResult(entry: try removeResult.get(), lost: ["claude"])
    }
    override func cleanMove(logs: [CoreCleanLogPick], caches: [String], progress: (@Sendable (CoreCleanProgress) -> Void)?) async throws -> CoreCleanMoveResult {
        record("clean.move \(logs.map { "\($0.cli)/\($0.olderThanDays)" }) \(caches)")
        for note in progressNotes { progress?(note) }
        if cancelledBeforeFirstFile { throw CancellationError() }
        if blocksUntilCancelled {
            while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(5)) }
            return CleanWriteTests.moved(files: 1, bytes: 4_096, cancelled: true)
        }
        return try moveResult.get()
    }
    override func journalUndo(id: String) async throws -> CoreUndoResult {
        record("journal.undo \(id)")
        return CoreUndoResult(label: id == "e-move" ? "Moved 4 files to the Trash: Codex logs" : "Removed 2 items")
    }
    /// Holds every `clean.scan` until the test opens it: the re-read after a write is still running.
    var scanGate: PendingGate?
    override func cleanScan() async throws -> CoreCleanScan {
        record("clean.scan")
        if let scanGate { await scanGate.wait() }
        return FrameTestData.cleanScan()
    }
    override func inventoryRead() async throws -> CoreInventorySnapshot { CoreInventorySnapshot(items: [], hooks: [], problems: [], events: [:], roots: [:]) }
    override func loadoutRows() async throws -> CoreLoadoutRows { FrameTestData.loadout() }
    override func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    override func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0,
                               problems: ["The usage archive could not be read, so the logs Clean moved are not counted."])
    }
}

/// Clean's one write path (AR4, CL-R1, CL-R5, CL-R6): equipment first, then the move with progress and Cancel; one toast
/// and one Undo for both entries; refused, partial and cancelled answers say what changed.
@Suite("Clean write")
@MainActor
struct CleanWriteTests {
    nonisolated static func moved(files: Int = 4, bytes: Int64 = 28_672, cancelled: Bool = false, groups: [CoreCleanGroup]? = nil) -> CoreCleanMoveResult {
        CoreCleanMoveResult(entry: FrameTestData.entry("e-move", label: "Moved 4 files to the Trash: Codex logs"),
                            moved: CoreCleanAmount(files: files, bytes: bytes),
                            groups: groups ?? [CoreCleanGroup(id: "logs:codex", moved: CoreCleanAmount(files: files, bytes: bytes), stayed: 0, reason: nil)],
                            cancelled: cancelled, trash: "/t/SpaceVibe Clean 2026-11-21")
    }

    private let skill = FrameRow.rows(from: FrameTestData.loadout([FrameTestData.item("never", cells: ["claude": FrameTestData.sessions(0)])]))[0]

    private func request(rows: [FrameRow]? = nil, logs: [CoreCleanLogPick] = [CoreCleanLogPick(cli: "codex", olderThanDays: 90)],
                         caches: [String] = []) -> CleanRequest {
        let rows = rows ?? [skill]
        var names = ["logs:codex": "Codex session logs"]
        for cache in caches { names[cache] = "~/.codex/cache" }
        return CleanRequest(rows: rows, members: rows.flatMap(\.memberIDs), logs: logs, caches: caches, groupNames: names)
    }

    private func setUp(_ core: CleanFakeCore) -> (FrameWrites, ToastCenter, FrameStore, CleanMoveRun) {
        let toasts = ToastCenter(announce: false)
        let store = FrameStore(core: core)
        store.cleanScanner = { try await core.cleanScan() }
        return (FrameWrites(core: core, store: store, toasts: toasts), toasts, store, CleanMoveRun())
    }

    @Test("equipment first, then the move; one toast says what moved in bytes; one Undo reverts both, newest first")
    func bothThenUndo() async {
        let core = CleanFakeCore()
        let (writes, toasts, _, run) = setUp(core)
        let ok = await writes.perform(.clean(request(), run: run, registry: FrameTestData.registry))
        #expect(ok)
        #expect(core.calls.prefix(2) == ["loadout.removeMany [\"claude:skill:never\"]", "clean.move [\"codex/90\"] []"])
        #expect(core.calls.contains("clean.scan"), "a Clean write re-reads clean.scan")
        #expect(toasts.current?.message == "Removed never to SpaceVibe's trash and moved 29 KB of logs and caches to the macOS Trash")
        #expect(toasts.current?.tone == .info && toasts.current?.action?.title == "Undo")
        #expect(!toasts.current!.message.contains("freed"))
        #expect(!run.isRunning && run.progress == nil)
        toasts.undoLast()
        for _ in 0..<200 where !core.calls.contains("journal.undo e-equip") { try? await Task.sleep(for: .milliseconds(5)) }
        let undos = core.calls.filter { $0.hasPrefix("journal.undo") }
        #expect(undos == ["journal.undo e-move", "journal.undo e-equip"])
    }

    @Test("logs and caches alone: no removeMany; the toast says moved, not freed")
    func movesOnly() async {
        let core = CleanFakeCore()
        let (writes, toasts, _, run) = setUp(core)
        await writes.perform(.clean(request(rows: []), run: run, registry: FrameTestData.registry))
        #expect(!core.calls.contains { $0.hasPrefix("loadout.removeMany") })
        #expect(toasts.current?.message == "Moved 29 KB of logs and caches to the macOS Trash")
    }

    @Test("a refused removal changes nothing and never moves files")
    func removalRefused() async {
        let core = CleanFakeCore()
        core.removeResult = .failure(CoreError("~/.claude/skills/never changed since SpaceVibe read it. Nothing changed.", status: 409))
        let (writes, toasts, _, run) = setUp(core)
        let ok = await writes.perform(.clean(request(), run: run, registry: FrameTestData.registry))
        #expect(!ok && !core.calls.contains { $0.hasPrefix("clean.move") })
        #expect(toasts.current?.tone == .danger)
    }

    @Test("every row locked and no equipment: the core's 409 is the refused toast")
    func allLocked() async {
        let core = CleanFakeCore()
        core.moveResult = .failure(CoreError("Codex has 1 running session, so its logs stay until it ends. Nothing was moved.", status: 409))
        let (writes, toasts, _, run) = setUp(core)
        let ok = await writes.perform(.clean(request(rows: []), run: run, registry: FrameTestData.registry))
        #expect(!ok && toasts.current?.tone == .danger)
        #expect(toasts.current?.message == "Codex has 1 running session, so its logs stay until it ends. Nothing was moved.")
    }

    @Test("a refused move after the equipment went is a partial result with Undo, never a refusal")
    func refusedAfterEquipment() async {
        let core = CleanFakeCore()
        core.moveResult = .failure(CoreError("Codex has 1 running session, so its logs stay until it ends. Nothing was moved.", status: 409))
        let (writes, toasts, _, run) = setUp(core)
        let ok = await writes.perform(.clean(request(), run: run, registry: FrameTestData.registry))
        #expect(ok && toasts.current?.tone == .partial && toasts.current?.action?.title == "Undo")
        #expect(toasts.current?.message == "Removed never to SpaceVibe's trash. Logs and caches stayed in place: Codex has 1 running session, "
            + "so its logs stay until it ends. Nothing was moved. Undo puts back what moved.")
        #expect(FrameToastKind(toasts.current!) == .partial(action: "Undo") && FrameToastKind.partial(action: nil).staysUntilDismissed)
    }

    @Test("a row that stayed: \"Moved 2 of 3\" names it and the core's reason, with Undo for what moved")
    func partial() async {
        let core = CleanFakeCore()
        core.moveResult = .success(Self.moved(groups: [
            CoreCleanGroup(id: "logs:codex", moved: CoreCleanAmount(files: 4, bytes: 28_672), stayed: 0, reason: nil),
            CoreCleanGroup(id: "codex:cache", moved: CoreCleanAmount(files: 0, bytes: 0), stayed: 3, reason: "Codex has 1 open session, so its caches are in use."),
        ]))
        let (writes, toasts, _, run) = setUp(core)
        await writes.perform(.clean(request(caches: ["codex:cache"]), run: run, registry: FrameTestData.registry))
        #expect(toasts.current?.tone == .partial)
        #expect(toasts.current?.message == "Moved 2 of 3. ~/.codex/cache stayed in place: Codex has 1 open session, so its caches are in use. Undo puts back what moved.")
    }

    @Test("Cancel during the move stops it before the next file: the core answers what moved, and the toast says the rest stayed")
    func cancelMidMove() async {
        let core = CleanFakeCore()
        core.blocksUntilCancelled = true
        core.progressNotes = [CoreCleanProgress(phase: "moving", done: 1, total: 4, bytes: 4_096)]
        let (writes, toasts, _, run) = setUp(core)
        let task = Task { await writes.perform(.clean(request(rows: []), run: run, registry: FrameTestData.registry)) }
        for _ in 0..<400 where run.progress == nil { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(run.progress?.done == 1, "clean/progress reaches the band")
        #expect(writes.isPending(FrameWrite.cleanControl))
        run.cancel()
        #expect(await task.value)
        #expect(toasts.current?.tone == .partial)
        #expect(toasts.current?.message == "Cancelled: 1 file (4 KB) moved to the macOS Trash, the rest stayed in place. Undo puts back what moved.")
        #expect(!run.isRunning && !writes.isPending(FrameWrite.cleanControl))
    }

    @Test("Cancel before the first file: nothing moved, a notice without Undo; after equipment, a partial with Undo")
    func cancelBeforeFirstFile() async {
        let core = CleanFakeCore()
        core.cancelledBeforeFirstFile = true
        let (writes, toasts, _, run) = setUp(core)
        await writes.perform(.clean(request(rows: []), run: run, registry: FrameTestData.registry))
        #expect(toasts.current?.message == "Cancelled. Nothing was moved." && toasts.current?.action == nil)
        await writes.perform(.clean(request(), run: run, registry: FrameTestData.registry))
        #expect(toasts.current?.tone == .partial && toasts.current?.message.contains("cancelled before any log or cache moved") == true)
    }

    @Test("a second press while a Clean write runs starts nothing")
    func oneAtATime() async {
        let core = CleanFakeCore()
        core.blocksUntilCancelled = true
        let (writes, _, _, run) = setUp(core)
        let first = Task { await writes.perform(.clean(request(rows: []), run: run, registry: FrameTestData.registry)) }
        for _ in 0..<400 where !core.calls.contains(where: { $0.hasPrefix("clean.move") }) { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(await writes.perform(.clean(request(rows: []), run: run, registry: FrameTestData.registry)) == false)
        run.cancel()
        _ = await first.value
        #expect(core.calls.filter { $0.hasPrefix("clean.move") }.count == 1)
    }

    @Test("a late progress note of an earlier move never shows on a later one")
    func lateNote() {
        let run = CleanMoveRun()
        run.begin()
        run.end()
        run.begin()
        run.report(CoreCleanProgress(phase: "moving", done: 9, total: 9, bytes: 1), generation: 0)
        #expect(run.progress == nil)
    }

    @Test("the age control is a store fact: the sidebar figure follows it")
    func ageIsAFact() {
        let model = FrameModel(core: CleanFakeCore(), toasts: ToastCenter(announce: false))
        let state = CleanPageState.of(model)
        #expect(CleanPageState.of(model) === state, "one page state per model")
        let actions = CleanActions(model: model, state: state, page: CleanPage(CleanSynthetic.inputs(.normal, clis: 2)), world: CleanSynthetic.world(.normal, clis: 2))
        actions.setAge(30, cli: "codex")
        #expect(model.store.facts.cleanLogAges == ["codex": 30])
    }

    @Test("the usage scan's problems are kept for Clean's band, and start reads clean.scan once (RD45)")
    func usageProblems() async {
        let core = CleanFakeCore()
        let (_, _, store, _) = setUp(core)
        await store.start()
        #expect(store.snapshot.usageProblems == ["The usage archive could not be read, so the logs Clean moved are not counted."])
        #expect(core.calls.filter { $0 == "clean.scan" }.count == 1, "one scan at launch, so the sidebar shows Clean's figure")
        store.stop()
    }

    @Test("P-001: confirming closes the dialog at once with the write pending, so the band's Cancel is in reach; a route changed from outside closes a waiting one")
    func confirmationEscAndRoute() async {
        let core = CleanFakeCore()
        core.blocksUntilCancelled = true
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false))
        let state = CleanPageState()
        let inputs = CleanSynthetic.inputs(.normal, clis: 2)
        let actions = CleanActions(model: model, state: state, page: CleanPage(inputs), world: inputs.world)
        state.confirming = CleanConfirmation(items: [], request: request(), routeRevision: model.router.revision)
        #expect(FramePageContent.clean(model: model, fixed: inputs, state: state).dialog != nil)
        let task = actions.confirm()
        #expect(task != nil && model.writes.isPending(FrameWrite.cleanControl), "pending before the press returns")
        #expect(state.confirming == nil && FramePageContent.clean(model: model, fixed: inputs, state: state).dialog == nil,
                "the dialog no longer covers the moving band")
        #expect(actions.confirm() == nil, "nothing left to confirm a second time")
        for _ in 0..<400 where !core.calls.contains(where: { $0.hasPrefix("clean.move") }) { try? await Task.sleep(for: .milliseconds(5)) }
        let moving = CleanPage(inputs, move: state.run.snapshot, isWriting: true)
        #expect(moving.phase == .moving && moving.moveBand?.canCancel == true, "the band offers Cancel while files move")
        actions.cancelMove()
        #expect(await task?.value == true)
        // A confirmation waiting for its answer closes when the glance widget routes elsewhere.
        state.confirming = CleanConfirmation(items: [], request: request(), routeRevision: model.router.revision)
        model.router.go(to: .session("claude:s1"))
        model.router.go(to: FrameRoute(page: .clean))
        #expect(FramePageContent.clean(model: model, fixed: inputs, state: state).dialog == nil)
    }

    // MARK: RB-F3 (round 2)

    private func actions(_ core: CleanFakeCore, ticked: Set<String>) -> (FrameModel, CleanPageState, CleanActions, CleanInputs) {
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false))
        let state = CleanPageState()
        state.ticked = ticked
        let inputs = CleanSynthetic.inputs(.normal, clis: 2)
        let page = CleanPage(inputs, ticked: state.ticked)
        return (model, state, CleanActions(model: model, state: state, page: page, world: inputs.world), inputs)
    }

    @Test("the ticks go as soon as the core answered, before the re-read; while it runs nothing can be ticked and Remove waits")
    func untickOnAnswer() async {
        let core = CleanFakeCore()
        let gate = PendingGate()
        core.scanGate = gate
        let (model, state, actions, inputs) = actions(core, ticked: ["logs:codex"])
        let task = actions.remove()
        #expect(task != nil && model.writes.isPending(FrameWrite.cleanControl), "pending before the press returns")
        #expect(actions.remove() == nil, "a second press in the same turn starts nothing")
        for _ in 0..<400 where !core.calls.contains("clean.scan") { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(state.ticked.isEmpty, "unticked once the move answered, while the re-read still runs")
        #expect(model.writes.isPending(FrameWrite.cleanControl))
        let during = CleanPage(inputs, ticked: ["caches:none", "logs:codex"], move: state.run.snapshot, isWriting: true)
        #expect(during.phase == .ready && !during.primary.isEnabled && during.rows.allSatisfy { !$0.isOpen })
        #expect(during.sections.allSatisfy { $0.pick == .none })
        await gate.open()
        #expect(await task?.value == true)
        #expect(!model.writes.isPending(FrameWrite.cleanControl))
    }

    @Test("a refused move keeps the ticks: nothing changed")
    func refusedKeepsTicks() async {
        let core = CleanFakeCore()
        core.moveResult = .failure(CoreError("Codex has 1 running session, so its logs stay until it ends. Nothing was moved.", status: 409))
        let (_, state, actions, _) = actions(core, ticked: ["logs:codex"])
        #expect(await actions.remove()?.value == false)
        #expect(state.ticked == ["logs:codex"])
    }

    @Test("Cancel only while files move: a removal of equipment alone offers none")
    func cancelOnlyWhenFilesMove() async {
        let core = CleanFakeCore()
        let (writes, _, _, run) = setUp(core)
        #expect(await writes.perform(.clean(request(logs: []), run: run, registry: FrameTestData.registry)))
        #expect(!core.calls.contains { $0.hasPrefix("clean.move") } && !run.snapshot.movesFiles, "the run began without files to move")
        run.begin(movesFiles: false)
        let equipment = CleanPage(CleanSynthetic.inputs(.normal, clis: 2), move: run.snapshot)
        #expect(equipment.moveBand?.canCancel == false && equipment.moveBand?.text == CleanMoveBand.removingOnly)
        run.end()
        run.begin(movesFiles: true)
        #expect(CleanPage(CleanSynthetic.inputs(.normal, clis: 2), move: run.snapshot).moveBand?.canCancel == true)
        run.end()
    }

    @Test("a locked row's tick is dropped, never kept for when the lock ends")
    func lockedTickDropped() {
        let state = CleanPageState()
        state.ticked = ["logs:codex", "logs:claude"]
        let page = CleanPage(CleanSynthetic.inputs(.normal, clis: 2), ticked: state.ticked)
        #expect(!page.tickable.contains("logs:claude") && page.tickable.contains("logs:codex"), "Claude Code's logs are locked")
        state.keepTicks(page.tickable)
        #expect(state.ticked == ["logs:codex"])
    }

    @Test("one scan in flight from the page's own calls: opening, Scan Again and Try Again join it")
    func oneScanInFlight() async {
        let core = CleanFakeCore()
        let gate = PendingGate()
        core.scanGate = gate
        let (_, _, actions, _) = actions(core, ticked: [])
        let opened = Task { await actions.measure() }
        for _ in 0..<400 where !core.calls.contains("clean.scan") { try? await Task.sleep(for: .milliseconds(5)) }
        actions.scanAgain()
        actions.tryAgain()
        let again = Task { await actions.measure() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(core.calls.filter { $0 == "clean.scan" }.count == 1)
        await gate.open()
        await opened.value
        await again.value
        #expect(core.calls.filter { $0 == "clean.scan" }.count == 1)
    }
}
