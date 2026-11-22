import Foundation
import Testing
@testable import SpaceVibe

/// Serves every read the store makes from fixed answers and records each call by method (and rules file), so a test can
/// say exactly what was read. The activity stream is fed by hand. Writes answer what the test sets.
final class FrameFakeCore: UnservedCore, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [String] = []
    private var continuation: AsyncThrowingStream<CoreActivityReport, Error>.Continuation?
    var projects: [String] = ["/p"]
    var usage: CoreLoadoutRows.UsageState = .ready
    var loadout = FrameTestData.loadout()
    var failing: Set<String> = []
    var writeResult: Result<CoreJournalEntry, CoreError> = .success(FrameTestData.entry("e1"))
    var undoResult: Result<CoreUndoResult, CoreError> = .success(CoreUndoResult(label: "Removed a"))

    /// The Keep list `findings.kept` answers; `findings.keep` and `unkeep` change it.
    var kept: [String] = []
    /// The core's answer to the per-CLI and batch writes (`lost`, `stillHave`, `alsoReaders`); `writeResult` gives the entry
    /// or the refusal.
    var alsoReaders: [String] = []
    var lost: [String] = ["claude"]
    var stillHave: [String] = []
    /// Called inside every recorded call, before it answers: a test looks at the write path's state at that moment.
    var onCall: (@Sendable (String) async -> Void)?
    private var _sent: [String: String] = [:]

    var calls: [String] { lock.withLock { _calls } }
    /// `activityRefresh` calls: the subscription asked for a report now (GW23).
    private var _refreshes = 0
    var refreshes: Int { lock.withLock { _refreshes } }
    /// The params each write was last sent, as text.
    var sent: [String: String] { lock.withLock { _sent } }
    func count(_ method: String) -> Int { calls.filter { $0 == method }.count }
    func reset() { lock.withLock { _calls = [] } }
    func push(_ report: CoreActivityReport) { lock.withLock { continuation }?.yield(report) }
    func failStream() { lock.withLock { continuation }?.finish(throwing: CoreError("The core restarted.", status: 500)) }

    private func record(_ name: String, sent params: String? = nil) async throws {
        lock.withLock {
            _calls.append(name)
            if let params { _sent[name] = params }
        }
        if let onCall { await onCall(name) }
        if failing.contains(name) { throw CoreError("could not read \(name)", status: 500) }
    }

    override func findingsKept() async throws -> CoreKeptFindings { try await record("findings.kept"); return CoreKeptFindings(kept: lock.withLock { kept }) }
    override func findingsKeep(id: String) async throws -> CoreEntryResult {
        try await record("findings.keep", sent: id)
        let entry = try writeResult.get()
        lock.withLock { kept.append(id) }
        return CoreEntryResult(entry: entry)
    }
    override func findingsUnkeep(id: String) async throws -> CoreEntryResult {
        try await record("findings.unkeep", sent: id)
        let entry = try writeResult.get()
        lock.withLock { kept.removeAll { $0 == id } }
        return CoreEntryResult(entry: entry)
    }
    override func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult {
        try await record("loadout.copyTo", sent: "\(id) \(targets)")
        return CoreCopyToResult(entry: try writeResult.get(), alsoReaders: alsoReaders)
    }
    override func loadoutRemoveFrom(id: String, clis: [String]) async throws -> CoreRemoveFromResult {
        try await record("loadout.removeFrom", sent: "\(id) \(clis)")
        return CoreRemoveFromResult(entry: try writeResult.get(), lost: lost, stillHave: stillHave)
    }
    override func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult {
        try await record("loadout.removeMany", sent: "\(ids)")
        return CoreRemoveManyResult(entry: try writeResult.get(), lost: lost)
    }
    override func rulesRemoveMany(scope: CoreRuleScope, dir: String?, ids: [String]) async throws -> CoreEntryResult {
        try await record("rules.removeMany", sent: "\(scope.rawValue) \(dir ?? "") \(ids)")
        return CoreEntryResult(entry: try writeResult.get())
    }

    override func clisRegistry() async throws -> CoreRegistryResult { try await record("clis.registry"); return CoreRegistryResult(clis: FrameTestData.registry) }
    override func inventoryRead() async throws -> CoreInventorySnapshot {
        try await record("inventory.read")
        return CoreInventorySnapshot(items: [], hooks: [], problems: [], events: [:], roots: [:])
    }
    override func loadoutRows() async throws -> CoreLoadoutRows {
        try await record("loadout.rows")
        var rows = loadout
        rows.usage = lock.withLock { usage }
        return rows
    }
    override func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        try await record("usage.scan")
        lock.withLock { usage = .ready }
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0), windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }
    override func rulesSnapshot(scope: CoreRuleScope, dir: String?, refreshProjects: Bool) async throws -> CoreRulesSnapshot {
        try await record("rules.snapshot:\(scope.rawValue):\(dir ?? "")")
        let file = FrameScope(scope: scope, dir: dir)
        return FrameTestData.rules([FrameTestData.rule("Bash", file: file)], file: file, projects: lock.withLock { projects })
    }
    override func limitsRead() async throws -> CoreLimitsResult { try await record("limits.read"); return CoreLimitsResult(limits: []) }
    override func journalHistory() async throws -> CoreJournalHistory { try await record("journal.history"); return CoreJournalHistory(entries: []) }
    override func activityRead() async throws -> CoreActivityReport { try await record("activity.read"); return FrameTestData.activity([]) }
    override func activityRefresh() async { lock.withLock { _refreshes += 1 } }
    override func activityStop(cli: CoreCLI, id: String) async throws -> CoreStopResult {
        try await record("activity.stop", sent: "\(cli.rawValue) \(id)")
        return CoreStopResult(exited: true)
    }
    override func activitySubscribe() -> AsyncThrowingStream<CoreActivityReport, Error> {
        lock.withLock { _calls.append("activity.subscribe") }
        return AsyncThrowingStream { continuation in lock.withLock { self.continuation = continuation } }
    }
    override func loadoutRemoveItem(id: String) async throws -> CoreEntryResult {
        try await record("loadout.removeItem")
        return CoreEntryResult(entry: try writeResult.get())
    }
    override func rulesSetCapability(scope: CoreRuleScope, dir: String?, capability: CoreCapability, verdict: CoreVerdict) async throws -> CoreSetCapabilityResult {
        try await record("rules.setCapability")
        return CoreSetCapabilityResult(entry: nil)
    }
    override func journalUndo(id: String) async throws -> CoreUndoResult {
        try await record("journal.undo:\(id)")
        return try undoResult.get()
    }
}

/// The store's reads (AR2): everything at start, the interval on activation, ⌘R, only the touched sources after a write,
/// the scan, project files and the live Activity subscription.
@Suite("Frame store")
@MainActor
struct FrameStoreTests {
    private let everything: Set<String> = [
        "clis.registry", "inventory.read", "loadout.rows", "limits.read", "journal.history", "findings.kept", "usage.scan",
        "rules.snapshot:global:", "rules.snapshot:project:/p", "rules.snapshot:local:/p",
    ]

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    @Test("start reads every source once, follows the known projects' two files, scans, and subscribes to Activity")
    func start() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        #expect(Set(core.calls).isSuperset(of: everything))
        #expect(core.count("activity.subscribe") == 1 && core.count("activity.read") == 0, "the subscription is Activity's source")
        #expect(Set(store.snapshot.rules.keys) == [.global, .shared("/p"), .local("/p")])
        #expect(store.snapshot.registry.map(\.id) == ["claude", "codex"])
        #expect(store.loading == [.activity], "Activity waits for the subscription's first report")
        #expect(store.failedEmpty.isEmpty)
        await store.start()
        #expect(core.count("clis.registry") == 1, "start is safe to call again")
        store.stop()
    }

    @Test("a scanning answer is read again after the scan finishes; the scan's follow-up read never loops")
    func scanThenRows() async {
        let core = FrameFakeCore()
        core.usage = .scanning
        let store = FrameStore(core: core)
        await store.start()
        #expect(core.count("usage.scan") == 1)
        #expect(store.snapshot.loadout?.usage == .ready)
        store.stop()
    }

    @Test("activation inside the interval reads nothing; after it, or with ⌘R, everything again")
    func refreshInterval() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        let t0 = Date(timeIntervalSince1970: 1_000)
        await store.start(now: t0)
        core.reset()
        await store.refresh(now: t0.addingTimeInterval(FrameStore.refreshInterval - 1))
        #expect(core.calls.isEmpty)
        await store.refresh(force: true, now: t0.addingTimeInterval(1))
        #expect(Set(core.calls).isSuperset(of: everything))
        core.reset()
        await store.refresh(now: t0.addingTimeInterval(1 + FrameStore.refreshInterval))
        #expect(core.count("loadout.rows") >= 1)
        store.stop()
    }

    @Test("a re-read asks only for the sources named")
    func reread() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        core.reset()
        await store.reread([.rules(.shared("/p")), .journal])
        #expect(core.calls.sorted() == ["journal.history", "rules.snapshot:project:/p"])
        store.stop()
    }

    @Test("a project no longer listed is dropped with its two files")
    func projectDropped() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        core.projects = []
        await store.reread([.rules(.global)])
        #expect(Array(store.snapshot.rules.keys) == [.global])
        store.stop()
    }

    @Test("a failed first read is failed with nothing shown; a failed later read keeps the last reading")
    func failures() async {
        let core = FrameFakeCore()
        core.failing = ["limits.read"]
        let store = FrameStore(core: core)
        await store.start()
        #expect(store.failedEmpty.contains(.limits))
        #expect(store.world(now: FrameTestData.now).figure(for: .limits, loading: store.loading, failed: store.failedEmpty) == .failed)
        core.failing = []
        await store.reread([.limits])
        core.failing = ["limits.read"]
        await store.reread([.limits])
        #expect(store.snapshot.limits != nil && !store.failedEmpty.contains(.limits))
        if case .failed = store.states[.limits] {} else { Issue.record("the later failure is not recorded") }
        store.stop()
    }

    @Test("Activity follows the subscription; when it fails, a read stands in and the next refresh subscribes again")
    func activity() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        let t0 = Date(timeIntervalSince1970: 1_000)
        await store.start(now: t0)
        core.push(FrameTestData.activity([FrameTestData.session("w", state: .waiting)]))
        #expect(await eventually { store.snapshot.activity?.sessions.count == 1 })
        core.failStream()
        #expect(await eventually { !store.isSubscribed })
        await store.reread([.activity])
        #expect(core.count("activity.read") == 1)
        await store.refresh(force: true, now: t0.addingTimeInterval(1))
        #expect(core.count("activity.subscribe") == 2 && store.isSubscribed)
        store.stop()
    }
}

/// The write path (AR4): pending at the control, the call, the toast with Undo on the Journal id or the refused-write
/// toast, then the touched sources read again; Undo through the one stack.
@Suite("Frame writes")
@MainActor
struct FrameWritesTests {
    private func setUp() async -> (FrameFakeCore, FrameStore, FrameWrites, ToastCenter) {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        core.reset()
        let toasts = ToastCenter(announce: false)
        return (core, store, FrameWrites(core: core, store: store, toasts: toasts), toasts)
    }

    @Test("accepted: the toast offers Undo, and only the touched sources and the journal are read again, after the call")
    func accepted() async {
        let (core, store, writes, toasts) = await setUp()
        let ok = await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        #expect(ok)
        #expect(core.calls.first == "loadout.removeItem")
        #expect(Set(core.calls.dropFirst()) == ["inventory.read", "loadout.rows", "journal.history"])
        #expect(toasts.current?.message == "Removed a" && toasts.current?.action?.title == "Undo")
        #expect(toasts.undoStack.count == 1 && writes.pending.isEmpty)
        store.stop()
    }

    @Test("refused: the core's sentence in a danger toast, no Undo, and the page is read again")
    func refused() async {
        let (core, store, writes, toasts) = await setUp()
        core.writeResult = .failure(CoreError("The file changed on disk.", status: 409))
        let ok = await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        #expect(!ok)
        #expect(toasts.current?.message == "The file changed on disk." && toasts.current?.tone == .danger && toasts.undoStack.isEmpty)
        #expect(core.count("loadout.rows") == 1)
        store.stop()
    }

    @Test("a refused write's toast offers Reload beside Dismiss, and Reload reads the touched sources again")
    func refusedReload() async {
        let (core, store, writes, toasts) = await setUp()
        core.writeResult = .failure(CoreError("The file changed on disk.", status: 409))
        await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        #expect(toasts.current?.action?.title == FrameWrites.reloadTitle)
        core.reset()
        toasts.runCurrentAction()
        #expect(await eventually { Set(core.calls) == ["inventory.read", "loadout.rows", "journal.history"] })
        #expect(toasts.current == nil, "Reload closes the toast")
        store.stop()
    }

    @Test("Undo runs journal.undo on the returned id, names what was undone, and reads the touched sources again")
    func undo() async {
        let (core, store, writes, toasts) = await setUp()
        await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        core.reset()
        toasts.undoLast()
        #expect(await eventually { core.count("loadout.rows") == 1 && !toasts.isUndoing })
        #expect(core.calls.first == "journal.undo:e1")
        #expect(toasts.current?.message == "Undid Removed a")
        #expect(toasts.undoStack.isEmpty)
        store.stop()
    }

    @Test("a refused Undo shows the core's sentence")
    func refusedUndo() async {
        let (core, store, writes, toasts) = await setUp()
        await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        core.undoResult = .failure(CoreError("Already undone.", status: 409))
        toasts.undoLast()
        #expect(await eventually { toasts.current?.message == "Already undone." })
        #expect(toasts.current?.tone == .danger)
        #expect(toasts.current?.action?.title == FrameWrites.reloadTitle, "a refused Undo offers Reload too")
        store.stop()
    }

    @Test("a control that is pending starts nothing more: the second press is not sent")
    func pending() async {
        let (core, store, writes, _) = await setUp()
        async let first = writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        async let second = writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        let results = await [first, second]
        #expect(results.filter { $0 }.count == 1)
        #expect(core.count("loadout.removeItem") == 1)
        store.stop()
    }

    @Test("a capability write the file already holds says so and offers no Undo")
    func nothingToChange() async {
        let (_, store, writes, toasts) = await setUp()
        await writes.perform(.setCapability(.run, to: .ask, in: .global, label: "Set Run commands to Ask"))
        #expect(toasts.current?.message == FrameWrites.nothingToChange && toasts.undoStack.isEmpty)
        store.stop()
    }

    @Test("an Undo run from the Journal window leaves the main window's session stack, so a later Z never reaches the core")
    func journalUndoLeavesMainStack() async {
        let (core, store, writes, toasts) = await setUp()
        await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        #expect(toasts.undoStack.count == 1 && toasts.current?.action != nil)
        let journal = store.makeWrites(toasts: ToastCenter(announce: false))
        #expect(await journal.undoFromJournal(FrameTestData.entry("e1"), label: "Removed a", store: store, main: writes))
        #expect(toasts.undoStack.isEmpty && toasts.current == nil, "the toast that offered the same Undo is gone too")
        core.reset()
        toasts.undoKey()
        #expect(core.calls.isEmpty)
        store.stop()
    }

    @Test("the Journal window's Undo re-reads Clean's scan once Clean has read one, and never starts a first one")
    func journalUndoRereadsClean() async {
        let (_, store, _, _) = await setUp()
        #expect(!FrameWrite.journalSources(store).contains(.clean))
        store.cleanScanner = { FrameTestData.cleanScan() }
        await store.readClean()
        #expect(FrameWrite.journalSources(store).contains(.clean))
        store.stop()
    }

    @Test("rule writes pend per file: a project's Shared and Local files never share a pending key")
    func ruleControlsCarryScope() {
        let shared = FrameScope.shared("/p"), local = FrameScope.local("/p")
        let pairs: [(FrameWrite, FrameWrite)] = [
            (.changeVerdict("Bash", from: .allow, to: .ask, in: shared, label: ""), .changeVerdict("Bash", from: .allow, to: .ask, in: local, label: "")),
            (.removeRule("Bash", verdict: .allow, in: shared, label: ""), .removeRule("Bash", verdict: .allow, in: local, label: "")),
            (.addRule("Bash", verdict: .allow, in: shared, label: ""), .addRule("Bash", verdict: .allow, in: local, label: "")),
            (.setCapability(.run, to: .ask, in: shared, label: ""), .setCapability(.run, to: .ask, in: local, label: "")),
        ]
        for (a, b) in pairs { #expect(a.control != b.control) }
        #expect(FrameWrite.changeVerdict("Bash", from: .allow, to: .ask, in: local, label: "").control == FrameWrite.verdictControl("Bash", in: local))
    }

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }
}

/// The project files the global reading follows (RB-V1 build-review finding 7).
@Suite("Frame store: project files")
@MainActor
struct FrameStoreProjectTests {
    @Test("a project file the global reading dropped stays dropped when its own read answers late")
    func droppedProjectStaysDropped() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        store.stop()
        #expect(store.snapshot.rules[.shared("/p")] != nil)
        // The project is no longer known; the refresh asks for its files beside the global one, and those answer late.
        core.projects = []
        let gate = PendingGate()
        core.onCall = { name in if name.hasSuffix(":/p") { await gate.wait() } }
        let refresh = Task { await store.refresh(force: true) }
        for _ in 0..<400 where store.snapshot.rules[.shared("/p")] != nil { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(store.snapshot.rules[.shared("/p")] == nil, "the global reading answered first and dropped the project")
        await gate.open()
        await refresh.value
        #expect(Set(store.snapshot.rules.keys) == [.global])
        #expect(store.states[.rules(.shared("/p"))] == nil && !store.reading.contains(.rules(.local("/p"))))
    }
}

/// Round-2 fixes of the store and the write path (RB-F3, reviewers R, P and Q): Activity read on Stop and on activation,
/// one Clean scan at a time, the shared pending set and the kept Hook ids.
@Suite("Frame store: round 2")
@MainActor
struct FrameStoreRoundTwoTests {
    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<400 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }

    @Test("Stop's re-read asks the live subscription for a report now, so the stopped row goes without the 20 s poll")
    func stopRefreshesActivity() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        #expect(store.isSubscribed)
        let before = core.refreshes
        let writes = FrameWrites(core: core, store: store, toasts: ToastCenter(announce: false))
        #expect(await writes.perform(.stop(cli: .claude, sessionID: "s1", label: "Stopped 1 session")))
        #expect(core.refreshes == before + 1, "the touched Activity source is refreshed, not skipped")
        #expect(core.count("activity.read") == 0, "a read would race the subscription's pushes")
        store.stop()
    }

    @Test("activation inside the 10 s interval still asks Activity for a report (GW23); nothing else is read")
    func activationRefreshesActivityFirst() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        let t0 = Date(timeIntervalSince1970: 1_000)
        await store.start(now: t0)
        core.reset()
        let before = core.refreshes
        await store.refresh(now: t0.addingTimeInterval(1))
        #expect(core.refreshes == before + 1 && core.calls.isEmpty)
        store.stop()
    }

    @Test("a second readClean while a scan runs joins it: one clean.scan, both get its answer")
    func readCleanJoins() async {
        let store = FrameStore(core: FrameFakeCore())
        let gate = PendingGate()
        let scans = CallCounter()
        store.cleanScanner = {
            scans.add()
            await gate.wait()
            return FrameTestData.cleanScan()
        }
        async let first = store.readClean()
        async let second = store.readClean()
        #expect(await eventually { scans.value == 1 })
        await gate.open()
        let answers = await [first, second]
        #expect(answers == [true, true] && scans.value == 1)
        // After a write, a scan that starts after the one in flight: a joined one could not see the move.
        await store.readCleanAfterWrite()
        #expect(scans.value == 2)
    }

    @Test("Scan Again takes its own scan's answer: a failed one shows no \u{201C}Measured again\u{201D}")
    func scanAgainOwnResult() async {
        let store = FrameStore(core: FrameFakeCore())
        store.cleanScanner = { FrameTestData.cleanScan() }
        #expect(await store.readClean())
        store.cleanScanner = { throw CoreError("The logs could not be read.", status: 500) }
        #expect(await store.readClean() == false, "the last scan stays, but this press's answer is a failure")
    }

    @Test("Clean's Try Again runs one clean.scan, with every other source")
    func tryAgainScansOnce() async {
        let core = FrameFakeCore()
        let model = FrameModel(core: core, toasts: ToastCenter(announce: false), cliPreferences: CLIPreferences(defaults: nil))
        let scans = CallCounter()
        model.store.cleanScanner = {
            scans.add()
            return FrameTestData.cleanScan()
        }
        await model.store.start()
        #expect(scans.value == 1)
        let inputs = CleanSynthetic.inputs(.normal, clis: 2)
        let actions = CleanActions(model: model, state: CleanPageState(), page: CleanPage(inputs), world: inputs.world)
        core.reset()
        actions.tryAgain()
        #expect(await eventually { core.count("loadout.rows") >= 1 && scans.value >= 2 })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(scans.value == 2, "refresh(force:) scans; Try Again adds no second scan")
        model.store.stop()
    }

    @Test("the Journal window's Undo is pending for the main window: its row locks wait for it")
    func journalUndoSharesPending() async {
        let core = FrameFakeCore()
        let gate = PendingGate()
        core.onCall = { name in if name.hasPrefix("journal.undo") { await gate.wait() } }
        let store = FrameStore(core: core)
        await store.start()
        let main = FrameWrites(core: core, store: store, toasts: ToastCenter(announce: false))
        let journal = store.makeWrites(toasts: ToastCenter(announce: false))
        let undo = Task { await journal.undoFromJournal(FrameTestData.entry("e1"), label: "Added a to Codex", store: store, main: main) }
        #expect(await eventually { main.isPending(FrameWrite.journalUndoControl("e1")) })
        #expect(main.isUndoing, "a row lock (D53) sees the Undo the other window runs")
        await gate.open()
        _ = await undo.value
        #expect(!main.isUndoing && main.pending.isEmpty)
        store.stop()
    }

    @Test("a toast's Undo is pending while it runs, so a logo press waits for the world it leaves")
    func toastUndoIsPending() async {
        let core = FrameFakeCore()
        let store = FrameStore(core: core)
        await store.start()
        let toasts = ToastCenter(announce: false)
        let writes = FrameWrites(core: core, store: store, toasts: toasts)
        await writes.perform(.removeItem(id: "claude:skill:a", label: "Removed a"))
        let gate = PendingGate()
        core.onCall = { name in if name.hasPrefix("journal.undo") { await gate.wait() } }
        toasts.undoLast()
        #expect(await eventually { writes.isUndoing })
        await gate.open()
        #expect(await eventually { !writes.isUndoing && !toasts.isUndoing })
        store.stop()
    }

    @Test("kept Hook findings move once to the per-CLI row ids at start, so they stay kept")
    func keptHookIDsMigrate() async {
        let core = FrameFakeCore()
        core.loadout = FrameTestData.loadout(hooks: [FrameTestData.hook("h1", cells: ["claude": FrameTestData.runs(0), "codex": .missing])])
        core.kept = ["hook::h1", "hook::h1:fail", "skill::other"]
        let store = FrameStore(core: core)
        await store.start()
        #expect(store.facts.findings.kept == ["hook::h1@claude", "hook::h1@claude:fail", "skill::other"])
        #expect(core.count("findings.keep") == 2 && core.count("findings.unkeep") == 2)
        #expect(store.world(now: FrameTestData.now).findings.allSatisfy { $0.id != "hook::h1@claude" }, "the Never ran Hook stays kept")
        core.reset()
        await store.migrateKeptHookIDs()
        #expect(core.count("findings.keep") == 0, "once per launch")
        store.stop()
    }
}

/// A count shared with a `@Sendable` closure.
final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func add() { lock.withLock { count += 1 } }
}
