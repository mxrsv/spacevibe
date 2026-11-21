import Foundation
import Observation

/// One engine reading the store holds. A write names the ones it touched, and only those are read again (AR2).
enum FrameSource: Hashable, Sendable {
    case registry, inventory, loadout, limits, activity, journal
    case rules(FrameScope)
    /// `findings.kept`: the Keep list, kept in `facts.findings.kept`.
    case kept
    /// `clean.scan`: what Clean can move, kept in `facts.clean`. Never part of the refresh (`FrameStore.readClean`).
    case clean
}

/// Where one source stands. A failure keeps the last reading: `failed` with data is a refresh that failed, without data a
/// page that cannot show anything yet.
enum FrameSourceState: Equatable, Sendable {
    case loading, ready
    case failed(String)
}

/// The redesign's one app-wide data store (plan AR2). It holds the latest `clis.registry`, `inventory.read`, `loadout.rows`,
/// `rules.snapshot` (global and both files of every known project), `limits.read`, the `activity.subscribe` reports,
/// `journal.history` and `findings.kept`, and it is the only object of the new frame that talks to `CoreService`. Pages
/// read `world(now:)`.
///
/// - Reads everything at `start()`, again on app activation (`refresh()`, skipped inside `refreshInterval`) and on ⌘R
///   (`refresh(force: true)`); a write re-reads only the sources it touched (`reread`).
/// - Owns the usage scan the core keeps (`usage.scan`): one at start and on each refresh, then `loadout.rows` again. A
///   core that restarted answers `scanning` with no scan running, which starts one.
/// - Activity comes from one live subscription; without one (it failed or ended), `activity.read` stands in and the next
///   refresh subscribes again.
/// - A later answer of the same source wins; an older one that arrives late is dropped.
///
/// It exists only while the redesign switch is on: the app's `FrameModel` holds it (`SpaceVibeFrameApp`), and the main,
/// Settings and Journal windows read the same one. The v5 pages keep their own reads.
@MainActor
@Observable
final class FrameStore {
    /// The same interval as the v5 `AgentsPage.refreshInterval`: activation and a return burst read once.
    static let refreshInterval: TimeInterval = 10

    private(set) var snapshot = FrameSnapshot()
    private(set) var states: [FrameSource: FrameSourceState] = [:]
    private(set) var isScanning = false
    /// The core's sentence when the last usage scan failed.
    private(set) var scanFailure: String?
    /// The derivations' other inputs (`FrameFacts`). The store fills `findings.kept` from each `findings.kept` and
    /// `findings.hookErrorsLastWeek` from each `loadout.rows`; the rest are set by their owners or still empty. With
    /// `cliPreferences`, `world` takes `hidden` and `findings.pinned` from Settings › CLIs instead of from here.
    var facts = FrameFacts()

    /// Reads `clean.scan` (RB-R5 sets it). The scan walks every log of every CLI (the RB-E7 build-review), so it is never
    /// polled: the 10 s activation refresh skips it, and only `readClean()` runs it, which RB-R5 calls when Clean opens and
    /// ⌘R (`refresh(force: true)`) calls too. Nil: Clean is not wired yet and nothing reads it.
    @ObservationIgnored var cleanScanner: (@MainActor () async throws -> CleanScan)?

    /// Settings › CLIs (Show, Balance pins). Nil: `facts.hidden` and `facts.findings.pinned` stand as set (tests).
    @ObservationIgnored let cliPreferences: CLIPreferences?
    @ObservationIgnored private let core: any CoreService
    @ObservationIgnored private var generations: [FrameSource: Int] = [:]
    @ObservationIgnored private var lastRefresh: Date?
    @ObservationIgnored private var subscription: Task<Void, Never>?
    @ObservationIgnored private(set) var isStarted = false
    @ObservationIgnored private var hasKept = false

    init(core: any CoreService, cliPreferences: CLIPreferences? = nil) {
        self.core = core
        self.cliPreferences = cliPreferences
    }

    func world(now: Date = Date()) -> FrameWorld { FrameWorld(snapshot: snapshot, facts: appliedFacts, now: now) }

    /// `facts` with Settings › CLIs applied: the hidden CLIs and the Balance pins, both over the registry read.
    var appliedFacts: FrameFacts {
        guard let cliPreferences else { return facts }
        var applied = facts
        applied.hidden = cliPreferences.hidden(in: snapshot.registry)
        applied.findings.pinned = cliPreferences.pins(in: snapshot.registry)
        return applied
    }

    /// A write service over this store's core and `toasts`: what a window beside the frame (the Journal window) writes
    /// through, so it takes the same path (AR4) without reaching the core itself.
    func makeWrites(toasts: ToastCenter) -> FrameWrites { FrameWrites(core: core, store: self, toasts: toasts) }

    /// Sources not answered yet, and sources that failed with nothing read before: the input of `FrameWorld.figure`.
    var loading: Set<FrameSource> { Set(states.filter { $0.value == .loading }.keys) }
    var failedEmpty: Set<FrameSource> {
        Set(states.filter { if case .failed = $0.value { return !hasData($0.key) } else { return false } }.keys)
    }

    var isSubscribed: Bool { subscription != nil }

    // MARK: Reading

    /// The first read of everything, the scan and the subscription. Safe to call again.
    func start(now: Date = Date()) async {
        guard !isStarted else { return }
        isStarted = true
        lastRefresh = now
        subscribe()
        await readEverything(refreshProjects: true)
    }

    /// Files may have changed outside the app. Skipped inside `refreshInterval` of the last refresh unless `force` (⌘R).
    func refresh(force: Bool = false, now: Date = Date()) async {
        guard isStarted else { return }
        if !force, let last = lastRefresh, now.timeIntervalSince(last) < Self.refreshInterval { return }
        lastRefresh = now
        if subscription == nil { subscribe() }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.readEverything(refreshProjects: force) }
            if force { group.addTask { await self.readClean() } }
        }
    }

    /// `clean.scan` now, through `cleanScanner`: on opening Clean and on ⌘R only, never on the activation refresh. A failure
    /// keeps the last scan (`failed` with data). Nothing happens without a scanner.
    func readClean() async {
        guard let cleanScanner else { return }
        let generation = begin(.clean)
        do {
            let scan = try await cleanScanner()
            guard isLatest(.clean, generation) else { return }
            facts.clean = scan
            states[.clean] = .ready
        } catch is CancellationError {
            return
        } catch {
            if isLatest(.clean, generation) { states[.clean] = .failed(AppEnvironment.message(error)) }
        }
    }

    /// Reads these sources again, at once. A write and its Undo call it with the sources they touched.
    func reread(_ sources: Set<FrameSource>) async {
        await withTaskGroup(of: Void.self) { group in
            for source in sources { group.addTask { await self.read(source, refreshProjects: false) } }
        }
    }

    /// Ends the subscription (the frame closed).
    func stop() {
        subscription?.cancel()
        subscription = nil
    }

    private func readEverything(refreshProjects: Bool) async {
        var sources: Set<FrameSource> = [.registry, .inventory, .loadout, .limits, .journal, .kept]
        if subscription == nil { sources.insert(.activity) }
        sources.formUnion(snapshot.rules.keys.filter { $0 != .global }.map(FrameSource.rules))
        await withTaskGroup(of: Void.self) { group in
            for source in sources { group.addTask { await self.read(source, refreshProjects: refreshProjects) } }
            group.addTask { await self.read(.rules(.global), refreshProjects: refreshProjects) }
            group.addTask { await self.scan() }
        }
    }

    private func hasData(_ source: FrameSource) -> Bool {
        switch source {
        case .registry: !snapshot.registry.isEmpty
        case .inventory: snapshot.inventory != nil
        case .loadout: snapshot.loadout != nil
        case .limits: snapshot.limits != nil
        case .activity: snapshot.activity != nil
        case .journal: snapshot.journal != nil
        case .rules(let file): snapshot.rules[file] != nil
        case .kept: hasKept
        case .clean: facts.clean != nil
        }
    }

    private func begin(_ source: FrameSource) -> Int {
        let next = (generations[source] ?? 0) + 1
        generations[source] = next
        if !hasData(source) { states[source] = .loading }
        return next
    }

    private func isLatest(_ source: FrameSource, _ generation: Int) -> Bool { generations[source] == generation }

    /// `mayRestartScan` is false for the read that follows a scan, so a core that keeps answering `scanning` is not asked
    /// again and again; the next refresh scans.
    private func read(_ source: FrameSource, refreshProjects: Bool, mayRestartScan: Bool = true) async {
        let generation = begin(source)
        do {
            switch source {
            case .registry:
                let value = try await core.clisRegistry().clis
                if isLatest(source, generation) { snapshot.registry = value }
            case .inventory:
                let value = try await core.inventoryRead()
                if isLatest(source, generation) { snapshot.inventory = value }
            case .loadout:
                let value = try await core.loadoutRows()
                guard isLatest(source, generation) else { return }
                snapshot.loadout = value
                facts.findings.hookErrorsLastWeek = FindingFacts.hookErrorsLastWeek(in: value)
                // A restarted core has no scan result: it answers `scanning` until someone scans.
                if mayRestartScan, value.usage == .scanning, !isScanning, scanFailure == nil {
                    states[source] = .ready
                    await scan()
                    return
                }
            case .limits:
                let value = try await core.limitsRead()
                if isLatest(source, generation) { snapshot.limits = value }
            case .activity:
                // The subscription keeps Activity current; a read would race its pushes.
                guard subscription == nil else { return }
                let value = try await core.activityRead()
                if isLatest(source, generation) { snapshot.activity = value }
            case .journal:
                let value = try await core.journalHistory()
                if isLatest(source, generation) { snapshot.journal = value }
            case .kept:
                // A list the core cannot read is refused, never read as empty: the last one read stays.
                let value = try await core.findingsKept()
                if isLatest(source, generation) {
                    facts.findings.kept = Set(value.kept)
                    hasKept = true
                }
            case .clean:
                // Only `readClean` reads it (never polled); a write that touched Clean asks for it here.
                await readClean()
                return
            case .rules(let file):
                let value = try await core.rulesSnapshot(scope: file.scope, dir: file.dir, refreshProjects: refreshProjects && file == .global)
                guard isLatest(source, generation) else { return }
                snapshot.rules[file] = value
                if file == .global { await followProjects(value.projectDirs) }
            }
            if isLatest(source, generation) { states[source] = .ready }
        } catch is CancellationError {
            return
        } catch {
            if isLatest(source, generation) { states[source] = .failed(AppEnvironment.message(error)) }
        }
    }

    /// The global reading lists the known projects: their two files are read, and a project no longer listed is dropped.
    private func followProjects(_ dirs: [String]) async {
        let wanted = Set(dirs.flatMap { [FrameScope.shared($0), FrameScope.local($0)] })
        for file in snapshot.rules.keys where file != .global && !wanted.contains(file) {
            snapshot.rules[file] = nil
            states[.rules(file)] = nil
        }
        let fresh = wanted.filter { snapshot.rules[$0] == nil && states[.rules($0)] != .loading }
        await withTaskGroup(of: Void.self) { group in
            for file in fresh { group.addTask { await self.read(.rules(file), refreshProjects: false) } }
        }
    }

    /// One `usage.scan` at a time, then `loadout.rows` again: the core attaches the finished scan to the rows it sends next.
    private func scan() async {
        guard !isScanning else { return }
        isScanning = true
        do {
            _ = try await core.usageScan(progress: nil)
            scanFailure = nil
        } catch is CancellationError {
            // The next refresh scans again.
        } catch {
            scanFailure = AppEnvironment.message(error)
        }
        isScanning = false
        await read(.loadout, refreshProjects: false, mayRestartScan: false)
    }

    private func subscribe() {
        if snapshot.activity == nil { states[.activity] = .loading }
        let stream = core.activitySubscribe()
        subscription = Task { [weak self] in
            do {
                for try await report in stream {
                    guard let self else { return }
                    self.snapshot.activity = report
                    self.states[.activity] = .ready
                }
            } catch is CancellationError {
                return
            } catch {
                self?.states[.activity] = .failed(AppEnvironment.message(error))
            }
            self?.subscription = nil
        }
    }
}
