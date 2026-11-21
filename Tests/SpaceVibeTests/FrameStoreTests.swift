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

    private func eventually(_ done: () -> Bool) async -> Bool {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(5)) }
        return done()
    }
}
