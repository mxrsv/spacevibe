import Foundation

/// What Clean reads: the store's world and the state of its on-demand `clean.scan`, or a fixed set for a shot.
struct CleanInputs {
    let world: FrameWorld
    let figure: PageFigure
    /// The sentence of a source the page needs that failed with nothing read before.
    var failure: String?
    /// `clean.scan` failed after an earlier one was read: the rows are that earlier one's.
    var rescanFailure: String?
    /// A `clean.scan` is in flight (the first one, or Scan Again).
    var isMeasuring = false
    let now: Date
    /// A shot's move in progress; nil reads the page state's own run.
    var move: CleanMoveRun.Snapshot?

    @MainActor
    static func live(_ store: FrameStore, now: Date = Date()) -> CleanInputs {
        let world = store.world(now: now)
        let failed = store.failedEmpty
        let failure = failed.compactMap { source -> String? in
            if case .failed(let sentence) = store.states[source] { return sentence }
            return nil
        }.first
        var rescan: String?
        if case .failed(let sentence) = store.states[.clean], store.snapshot.clean != nil { rescan = sentence }
        return CleanInputs(world: world, figure: world.figure(for: .clean, loading: store.loading, failed: failed), failure: failure,
                           rescanFailure: rescan, isMeasuring: store.reading.contains(.clean), now: now)
    }
}

/// Everything Clean shows for one world and one page state (RD-R2 Clean, RD-R13, CL-R1 to CL-R7; the reference mock's
/// `pageClean`). The hero is what can be cleaned, the same `FrameWorld.figure(for: .clean)` the sidebar shows (AR3); the
/// selected amount sits on the bar and the button. Pure: the view draws it, the tests read it.
struct CleanPage: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// The first `clean.scan` or the usage scan is running: no total yet (hero `…`, the sidebar `Measuring`).
        case measuring
        case failed
        case ready
        /// A move runs: nothing can be ticked, Scan Again waits, the band shows the progress and Cancel.
        case moving
    }

    /// Only `usage.scan` reads the archive of moved logs' totals (the counts on Skills, Subagents and Hooks); Limits and
    /// Activity read live files and the status line, so the note never names them.
    static let note = "Skills, Subagents and Hooks go to SpaceVibe's trash; logs and caches to the macOS Trash. Undo brings both back. "
        + "A moved log keeps only its usage totals, which the usage counts on Skills, Subagents and Hooks still include."
    static let tidyLine = "Every item ran, no session log is older than 30 days, and the caches are empty."

    let phase: Phase
    let hero: PageHero.Figure
    let heroLabel: String
    /// Selected against what can be cleaned (RD-R17: the bar's scale is what can be cleaned); nil draws the Unmeasurable dash.
    let barShare: Double?
    /// "1.02 GB selected · 380 MB more in use": bytes in use are text only.
    let barText: String
    let showsBand: Bool
    let moveBand: CleanMoveBand?
    let banners: [CleanBanner]
    let sections: [CleanSectionModel]
    /// "Cursor CLI and Amp: log paths are not verified yet, so they are not offered."
    let notOfferedLine: String?
    let isTidy: Bool
    let primary: CleanPrimary
    /// The ticked open rows, in page order: what `Remove …` takes.
    let ticked: [String]
    let selectedBytes: Int64

    var rows: [CleanRowModel] { sections.flatMap(\.rows) }
    /// The rows the arrow keys walk.
    var order: [String] { rows.map(\.id) }
    var canScanAgain: Bool { phase == .ready || phase == .failed }

    func row(_ id: String?) -> CleanRowModel? { id.flatMap { id in rows.first { $0.id == id } } }

    init(_ inputs: CleanInputs, ticked: Set<String> = [], move: CleanMoveRun.Snapshot = .idle) {
        let world = inputs.world
        let plan = world.clean
        let wording = InboxWording(world: world, now: inputs.now)
        let phase: Phase
        switch inputs.figure {
        case _ where move.isRunning: phase = .moving
        case .pending: phase = .measuring
        case .notMeasured where world.snapshot.clean == nil: phase = .measuring
        case .failed: phase = .failed
        default: phase = .ready
        }
        self.phase = phase
        // Ticks stay drawn while a move runs (the mock's `simPick`); only a ready page lets a row be ticked.
        let openAll = plan.openIDs
        let open = phase == .ready ? openAll : []
        let order = plan.agentRows.map(\.id) + plan.logs.map(\.id) + plan.caches.map(\.id)
        self.ticked = order.filter { openAll.contains($0) && ticked.contains($0) }
        let selected = plan.selectedBytes(Set(self.ticked)) ?? 0
        selectedBytes = selected
        let cleanable = plan.cleanableBytes ?? 0
        isTidy = (phase == .ready || phase == .moving) && plan.isEmpty

        switch phase {
        case .measuring:
            hero = .scanning
            heroLabel = "measuring"
        case .failed:
            hero = .unmeasurable
            heroLabel = "Unmeasurable"
        case .ready, .moving:
            if plan.isEmpty {
                hero = .clear("Tidy")
                heroLabel = "Nothing to clean"
            } else {
                hero = Self.figure(cleanable)
                let hooks = plan.agentRows.filter { $0.row.kind == .hook && $0.isSuggested }.count
                heroLabel = "can be cleaned" + (hooks > 0 ? " · \(NumberWording.plural(hooks, "Hook")) to remove" : "")
            }
        }
        barShare = phase == .failed ? nil : cleanable > 0 && phase != .measuring ? Double(selectedBytes) / Double(cleanable) : 0
        barText = phase == .measuring ? "Measuring…"
            : "\(NumberWording.bytes(selectedBytes)) selected" + (plan.lockedBytes > 0 ? " · \(NumberWording.bytes(plan.lockedBytes)) more in use" : "")
        showsBand = !isTidy && phase != .failed
        moveBand = phase == .moving ? CleanMoveBand(progress: move.progress, selectedBytes: selectedBytes, isCancelling: move.isCancelling) : nil

        var banners: [CleanBanner] = []
        if phase == .failed { banners.append(.failed(inputs.failure ?? "SpaceVibe could not measure your CLI folders.")) }
        if let rescan = inputs.rescanFailure, phase != .failed { banners.append(.rescanFailed(rescan)) }
        if case .unreadable(let names, let paths) = wording.unreadable { banners.append(.unreadable(names: names, paths: paths)) }
        if !world.snapshot.usageProblems.isEmpty { banners.append(.usage(world.snapshot.usageProblems)) }
        if let stranded = world.snapshot.clean?.problems, !stranded.isEmpty { banners.append(.stranded(stranded)) }
        self.banners = banners

        let rowsOf = CleanRows(world: world, wording: wording, now: inputs.now, phase: phase, open: open)
        let tickedSet = Set(self.ticked)
        func section(_ kind: CleanRowModel.Section, _ title: String, _ rows: [CleanRowModel], suggested: [String]) -> CleanSectionModel? {
            if rows.isEmpty {
                return phase == .measuring ? CleanSectionModel(section: kind, title: title, rows: [], suggested: [], pick: .none, skeletons: 2) : nil
            }
            let offered = phase == .ready ? suggested : []
            let pick: CleanSectionModel.Pick = offered.isEmpty ? .none : offered.allSatisfy(tickedSet.contains) ? .clear : .select(offered.count)
            return CleanSectionModel(section: kind, title: title, rows: rows, suggested: offered, pick: pick, skeletons: 0)
        }
        sections = phase == .failed ? [] : [
            section(.agents, "Skills, Subagents and Hooks", plan.agentRows.map(rowsOf.agent), suggested: plan.suggestedAgents),
            section(.logs, "Session logs", plan.logs.map(rowsOf.logs), suggested: plan.suggestedLogs),
            section(.caches, "Caches", plan.caches.map(rowsOf.cache), suggested: plan.suggestedCaches),
        ].compactMap { $0 }
        let unverified = plan.notOffered.map(wording.name)
        notOfferedLine = unverified.isEmpty || phase == .failed ? nil
            : "\(CLINames.sentence(unverified)): log paths are not verified yet, so they are not offered."

        switch phase {
        case .measuring: primary = .measuring
        case .failed: primary = .hidden
        case .moving: primary = .moving(percent: CleanMoveBand.percent(move.progress))
        case .ready: primary = isTidy ? .hidden : .remove(bytes: selected, count: self.ticked.count)
        }
    }

    /// "1.02" "GB" for the hero (the mock's `figParts`).
    static func figure(_ bytes: Int64) -> PageHero.Figure {
        let parts = NumberWording.bytes(bytes).split(separator: " ", maxSplits: 1).map(String.init)
        return .value(parts.first ?? NumberWording.missing, unit: parts.count > 1 ? parts[1] : nil)
    }

    // MARK: The write

    /// What `Remove …` takes: the ticked open rows only, each section's in page order.
    func request(_ world: FrameWorld) -> CleanRequest {
        let plan = world.clean
        let ticked = Set(self.ticked)
        let rows = plan.agentRows.filter { ticked.contains($0.id) }.map(\.row)
        let members = RowRemoval.members(rows, in: world)
        let logs = plan.logs.filter { ticked.contains($0.id) }
        let caches = plan.caches.filter { ticked.contains($0.id) }
        var names: [String: String] = [:]
        for log in logs { names[log.id] = "\(world.cliName(log.cli)) session logs" }
        for cache in caches { names[cache.id] = CleanRows.path(cache.cache.path) }
        return CleanRequest(rows: rows, members: members, logs: logs.map { CoreCleanLogPick(cli: $0.cli, olderThanDays: $0.ageDays) },
                            caches: caches.map(\.id), groupNames: names)
    }

    /// The ticked equipment rows whose file another CLI reads (or whose readers are not known): removing them names every
    /// reader first (RD-R11). At 2 CLIs no file is shared, so Clean never asks there (the mock's `MOCK.na`).
    func sharedRows(_ world: FrameWorld) -> [FrameRow] {
        let wording = InboxWording(world: world, now: Date())
        return request(world).rows.filter(wording.asksBeforeRemoving)
    }
}

/// The words of each row (the mock's `agRows`, `lgRows`, `chRows`). Pure.
struct CleanRows {
    let world: FrameWorld
    let wording: InboxWording
    let now: Date
    let phase: CleanPage.Phase
    let open: Set<String>

    func agent(_ agent: CleanPlan.AgentRow) -> CleanRowModel {
        let row = agent.row
        let why: String? = switch agent.readOnly {
        case .plugin(let owner): "Owned by the \(owner) plugin · read-only"
        case .project(let name): "Project item of \(name) · read-only"
        case .hookNotWritten: "SpaceVibe edits only Claude Code Hooks · read-only"
        case nil: row.isRecentlyAdded ? "just added, not suggested" : world.facts.findings.kept.contains(row.id) ? "kept, not suggested" : nil
        }
        let state = row.status == .dead ? "Dead Hook" : "Never ran \(InboxWording.kindWord(row.kind))"
        let seen = wording.added(row)
        let loaded = wording.loadedBy(row)
        let size: CleanRowModel.Size = switch (row.kind, agent.bytes) {
        case (.hook, _): .quiet("edits settings.json")
        case (_, let bytes?): .bytes(NumberWording.bytes(bytes))
        case (_, nil): phase == .measuring || world.snapshot.clean == nil ? .pending : .quiet("Unmeasurable")
        }
        return CleanRowModel(id: agent.id, section: .agents, cli: nil, title: row.name, isMono: row.kind == .hook,
                             sub: [why, state, seen].compactMap { $0 }.joined(separator: " · "),
                             detail: .clis(Array(loaded.prefix(3)), more: max(0, loaded.count - 3)), size: size, isOpen: open.contains(agent.id))
    }

    func logs(_ log: CleanPlan.LogRow) -> CleanRowModel {
        let name = world.cliName(log.cli)
        if log.isUnreadable {
            return CleanRowModel(id: log.id, section: .logs, cli: log.cli, title: "\(name) session logs", isMono: false,
                                 sub: "Unmeasurable: \(logsFolder(log.cli)) could not be read", detail: .none, size: .quiet("Unmeasurable"),
                                 isOpen: false)
        }
        let detail: CleanRowModel.Detail = log.lock.map { .lock(CleanLockNote(id: "logs:\(log.cli)", lock: $0, isCache: false,
                                                                                  activity: world.snapshot.activity)) }
            ?? .ages(log.ages, selected: log.ageDays)
        return CleanRowModel(id: log.id, section: .logs, cli: log.cli, title: "\(name) session logs", isMono: false,
                             sub: "\(NumberWording.plural(log.files, "file")) older than \(log.ageDays) days", detail: detail,
                             size: .bytes(NumberWording.bytes(log.bytes)), isOpen: open.contains(log.id))
    }

    func cache(_ cache: CleanPlan.CacheRow) -> CleanRowModel {
        let detail: CleanRowModel.Detail = cache.lock.map { .lock(CleanLockNote(id: "caches:\(cache.cli)", lock: $0, isCache: true,
                                                                                    activity: world.snapshot.activity)) } ?? .none
        return CleanRowModel(id: cache.id, section: .caches, cli: cache.cli, title: Self.path(cache.cache.path), isMono: true, sub: nil,
                             detail: detail, size: .bytes(NumberWording.bytes(cache.cache.bytes)), isOpen: open.contains(cache.id))
    }

    /// `~/.codex/sessions`: the folder `logs.Walk` reads for that CLI (clean.md "What moves where").
    func logsFolder(_ cli: String) -> String {
        let root = world.snapshot.loadout?.roots[cli].map(Self.path) ?? "~/.\(cli)"
        return "\(root)/\(cli == "claude" ? "projects" : "sessions")"
    }

    /// A path as the page writes it: under the home folder with `~`.
    static func path(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }
}
