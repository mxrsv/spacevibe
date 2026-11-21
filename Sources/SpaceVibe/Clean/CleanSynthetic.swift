import Foundation

/// In-memory readings for the Clean shots and tests, one per RD-R13 state, at 2 and 10 CLIs: the Inbox's synthetic world
/// (`InboxSynthetic`: Never ran and Dead items, a waiting Claude Code session, a shared `~/.agents/skills` file at many CLIs)
/// plus a `clean.scan` answer built like the reference mock's `LOGS` and `CACHES` (`src/a-core.js`), with cache ids from the
/// real allowlist. Names are made up (S-R2).
enum CleanSynthetic {
    enum State: String, CaseIterable, Sendable {
        case normal, empty, scanning, error, worst
    }

    static let now = InboxSynthetic.now
    static let home = "/Users/someone"

    /// A Codex session the process check cannot measure: it holds Codex's caches while Codex logs stay open (RD35, the mock's
    /// "In use by 1 session").
    static let codexUnmeasurable = CoreActivitySession(
        cli: .codex, id: "s-codex", title: "Codex app-server session", project: "payments-web", pid: 51_204, state: .unmeasurable,
        stateReason: "Codex keeps no state SpaceVibe can read", reasonCode: nil, currentTool: nil, ageMs: 9 * 60_000, lastWriteAgoMs: nil,
        cost: nil, costNote: nil)

    static func bucket(_ days: Int, _ files: Int, _ bytes: Double) -> CoreCleanBucket {
        CoreCleanBucket(olderThanDays: days, files: files, bytes: Int64(bytes))
    }

    /// The `clean.scan` of one state; nil while the first scan runs.
    static func scan(_ state: State) -> CoreCleanScan? {
        let worst = state == .worst
        let files = { (n: Int) in worst ? n * 301 : n }
        let size = { (b: Double) in worst ? b * 87 : b }
        switch state {
        case .scanning:
            return nil
        case .empty:
            return CoreCleanScan(clis: ["claude", "codex"].map {
                CoreCleanCLI(cli: $0, logs: CoreCleanLogs(state: "measured", buckets: []), caches: [], locks: CoreCleanLocks(logs: nil, caches: nil))
            }, items: [])
        case .normal, .error, .worst:
            let claudeLogs = CoreCleanLogs(state: "measured", buckets: [bucket(30, files(3_412), size(8.4e9)), bucket(90, files(2_104), size(6.2e9)),
                                                                         bucket(180, files(812), size(2.9e9))])
            let codexLogs = state == .error ? CoreCleanLogs(state: "unreadable", buckets: [])
                : CoreCleanLogs(state: "measured", buckets: [bucket(30, files(2_240), size(1.1e9)), bucket(90, files(1_310), size(7.8e8)),
                                                             bucket(180, files(402), size(3.1e8))])
            let snapshots = worst
                ? "\(home)/.claude/shell-snapshots/snapshot-zsh-7f3c9a2e-5b4a-4c3d-8e2f-1a0b9c8d7e6f-and-a-folder-name-that-goes-on"
                : "\(home)/.claude/shell-snapshots"
            let claude = CoreCleanCLI(
                cli: "claude", logs: claudeLogs,
                caches: [CoreCleanCache(id: "claude:shell-snapshots", path: snapshots, entries: 41, files: 41, bytes: Int64(size(3.8e7))),
                         CoreCleanCache(id: "claude:debug", path: "\(home)/.claude/debug", entries: 12, files: 12, bytes: Int64(size(1.2e7)))],
                locks: CoreCleanLocks(
                    logs: CoreCleanLock(reason: "sessions", sessions: ["s-waiting"], message: "Claude Code has 1 running session, so its logs stay until it ends."),
                    caches: CoreCleanLock(reason: "sessions", sessions: ["s-waiting"], message: "Claude Code has 1 open session, so its caches are in use.")))
            let codex = CoreCleanCLI(
                cli: "codex", logs: codexLogs,
                caches: [CoreCleanCache(id: "codex:cache", path: "\(home)/.codex/cache", entries: 7, files: 230, bytes: Int64(size(2.4e8)))],
                locks: CoreCleanLocks(
                    logs: nil,
                    caches: CoreCleanLock(reason: "sessions", sessions: [codexUnmeasurable.id], message: "Codex has 1 open session, so its caches are in use.")))
            let items: [(String, Double)] = [("skill::pdf-extract", 48_000), ("skill::changelog-writer", 12_000), ("skill::figma-export", 9_000),
                                             ("agent::release-captain", 3_400)]
            var sizes = items.map { CoreCleanItemSize(key: $0.0, bytes: Int64(size($0.1))) }
            if worst {
                let stems = [InboxSynthetic.longName, "データ変換-スキル", "مراجعة-طلبات-الدمج"]
                sizes += (0 ..< 9).map { index in
                    CoreCleanItemSize(key: "\(index % 2 == 0 ? "skill" : "agent")::\(stems[index % 3])-\(index)", bytes: 1_204_000_000 + Int64(index))
                }
            }
            let stranded = worst ? ["\(home)/.spacevibe/clean/1800000000000-0a1b holds files of an interrupted Clean move whose list cannot be trusted, so SpaceVibe left them there. Put them back by hand."] : nil
            return CoreCleanScan(clis: [claude, codex], items: sizes, problems: stranded)
        }
    }

    /// The readings of one state at `count` CLIs (2 or 10), with the facts the store would fill.
    static func snapshot(_ state: State, clis count: Int) -> (snapshot: FrameSnapshot, facts: FrameFacts) {
        let inbox: InboxSynthetic.State = switch state {
        case .normal: .normal
        case .empty: .empty
        case .scanning: .scanning
        case .error: .error
        case .worst: .worst
        }
        var (snapshot, facts) = InboxSynthetic.snapshot(inbox, clis: count)
        snapshot.clean = scan(state)
        if state == .empty, var loadout = snapshot.loadout {
            // Tidy: every item ran, nothing is kept or dead.
            loadout.items = loadout.items.filter { $0.key == "skill::code-review" || $0.key == "agent::test-runner" }
            loadout.hooks = []
            snapshot.loadout = loadout
            facts.findings.kept = []
        }
        if state != .empty, let activity = snapshot.activity {
            snapshot.activity = CoreActivityReport(sessions: activity.sessions + [codexUnmeasurable], failures: activity.failures, files: activity.files,
                                                   unmeasurable: activity.unmeasurable, stats: activity.stats)
        }
        if state == .worst { snapshot.usageProblems = ["The usage archive could not be read, so the logs Clean moved are not counted."] }
        return (snapshot, facts)
    }

    static func world(_ state: State, clis count: Int) -> FrameWorld {
        let built = snapshot(state, clis: count)
        return FrameWorld(snapshot: built.snapshot, facts: built.facts, now: now)
    }

    /// The page's inputs as the store would give them: the first scan in flight is `pending`.
    static func inputs(_ state: State, clis count: Int, move: CleanMoveRun.Snapshot? = nil) -> CleanInputs {
        let world = world(state, clis: count)
        let figure: PageFigure = state == .scanning ? .pending : world.figure(for: .clean, loading: [], failed: [])
        return CleanInputs(world: world, figure: figure, isMeasuring: state == .scanning, now: now, move: move)
    }
}
