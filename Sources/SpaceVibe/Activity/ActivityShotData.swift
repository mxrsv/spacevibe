import Foundation

/// The Activity page's states for the headless shots (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=activity
/// SPACEVIBE_SHOT_STATE=<state>`), beside the reference mock's same state: synthetic sessions and failures with the mock's
/// names (S-R2), never a real config. Each state is a fixed `ActivityPreview` and, where the mock draws one, the toast.
enum ActivityShotState: String, CaseIterable, Sendable {
    case normal, empty, scanning, error, worst, write, writefail, dialog, failures, many
    /// The Failures tab with the break-ui failures, the one without a reason selected (RB-F3: no stray separator, no
    /// empty Reason).
    case failuresWorst = "failures-worst"

    /// The toast the state shows, in the words and tone the real Stop gives (`ActivityPageState.stopWrite` through
    /// `FrameWrites`): one stopped session's toast (no Undo), or the partial toast when one of two was refused.
    var toast: (message: String, tone: ToastTone)? {
        switch self {
        case .write: (ActivityPageData.stoppedLabel(ActivityShotData.stopped), .info)
        case .writefail:
            (ActivityPageData.partialStop(stopped: [48211], refused: [(pid: 47990, reason: ActivityShotData.refusal)]) ?? "", .partial)
        default: nil
        }
    }

    func preview(now: Date = Date()) -> ActivityPreview {
        let data = ActivityShotData(now: now)
        let registry = self == .many ? ActivityShotData.tenCLIs : Array(ActivityShotData.tenCLIs.prefix(2))
        var sessions = data.sessions, failures = data.failures
        var sessionCLIs: [String: String] = [:]
        var source: FrameSourceState? = .ready
        var hasReport = true
        switch self {
        case .normal, .dialog, .failures, .writefail: break
        case .many:
            // The mock's `SESS_X`: Cursor CLI and Copilot CLI sessions, so the other CLIs' groups show (RD-R10).
            sessions += data.otherCLISessions.map(\.session)
            sessionCLIs = Dictionary(uniqueKeysWithValues: data.otherCLISessions.map { ($0.session.id, $0.cli) })
        case .empty: sessions = []; failures = []
        case .scanning: sessions = []; failures = []; hasReport = false; source = .loading
        case .error: sessions = []; failures = []; hasReport = false; source = .failed("The session logs could not be read.")
        case .worst, .failuresWorst: sessions += data.worstSessions; failures += data.worstFailures
        case .write:
            sessions = sessions.map { session in
                guard session.id == "a1" else { return session }
                var ended = session
                ended.state = .ended
                ended.currentTool = nil
                ended.lastWriteAgoMs = 0
                return ended
            }
        }
        let waiting = sessions.filter { $0.state == .waiting }.count, running = sessions.filter { $0.state == .running }.count
        let figure: PageFigure = switch source {
        case .loading: .pending
        case .failed: .failed
        default: .count(waiting > 0 ? waiting : running, tone: waiting > 0 ? .attention : nil)
        }
        return ActivityPreview(
            clis: registry, sessions: sessions, sessionCLIs: sessionCLIs, failures: failures, hasReport: hasReport, source: source, figure: figure, now: now,
            tab: self == .failures || self == .failuresWorst ? .failures : .sessions,
            selection: self == .failures ? "claude:hook:f1" : self == .failuresWorst ? "claude:command:f5"
                : hasReport && !sessions.isEmpty ? "claude:a2" : nil,
            ticked: self == .dialog || self == .worst ? ["claude:a1", "claude:a2"] : [],
            stopAlertIDs: self == .dialog ? ["claude:a1"] : [],
            hostApp: ActivityShotData.hostApp)
    }

    /// The sidebar's Activity value for the state, the same figure the hero shows.
    func sidebarValues(now: Date = Date()) -> FrameSidebarValues {
        FrameSidebarValues(values: [.activity: FrameSidebarValue(figure: preview(now: now).figure, page: .activity)])
    }
}

/// The mock's sessions and failures (`src/a-core.js` `SESS`, `FAILS`) as engine values.
struct ActivityShotData {
    let now: Date

    /// The registry as the mock draws 10 CLIs (`CLI_10`): only Claude Code and Codex keep logs SpaceVibe reads.
    static let tenCLIs: [CoreRegistryCLI] = [
        ("claude", "Claude Code"), ("codex", "Codex"), ("cursor", "Cursor CLI"), ("copilot", "Copilot CLI"), ("opencode", "opencode"),
        ("amp", "Amp"), ("antigravity", "Antigravity CLI"), ("kiro", "Kiro"), ("qwen", "Qwen Code"), ("aider", "Aider"),
    ].map { id, name in
        let logs = id == "claude" || id == "codex"
        return CoreRegistryCLI(id: id, name: name, supports: CoreRegistrySupports(skill: true, agent: true, hook: logs, rule: id == "claude", logs: logs, limits: logs))
    }

    private static let minute = 60_000.0

    /// The session the write shot stopped (the mock's `a1`), as the row the toast names.
    static var stopped: [ActivitySessionRow] {
        ActivityShotData(now: Date()).sessions.prefix(1).map { ActivitySessionRow($0, cliName: "Claude Code", elapsedMs: 0) }
    }

    /// The mock's hosts: every session runs in Terminal but the Cursor CLI one (`host: false`, Terminal app not found).
    static let hostApp: @Sendable (Int) -> HostApp? = { pid in
        pid == 50211 ? nil : HostApp(pid: 1, bundleIdentifier: "com.apple.Terminal", name: "Terminal")
    }

    /// The core's sentence when a pid could not be checked again (`activity.Stop`, S-R6).
    static let refusal = "The process could not be checked again, so nothing was sent to it."

    private func session(_ id: String, cli: CoreCLI, title: String, project: String?, pid: Int, state: CoreSessionState,
                         reason: String = "", tool: (String, String)? = nil, ageMinutes: Double, lastWriteMinutes: Double? = 0.1,
                         cost: Double?, costNote: String? = nil) -> CoreActivitySession {
        CoreActivitySession(
            cli: cli, id: id, title: title, project: project, pid: pid, state: state, stateReason: reason, reasonCode: nil,
            currentTool: tool.map { CoreActivityTool(name: $0.0, target: $0.1) }, ageMs: ageMinutes * Self.minute,
            lastWriteAgoMs: lastWriteMinutes.map { $0 * Self.minute }, cost: cost.map { CoreActivityCost(usd: $0, estimated: true) },
            costNote: costNote)
    }

    var sessions: [CoreActivitySession] {
        [
            session("a1", cli: .claude, title: "Fix flaky checkout test", project: "payments-web", pid: 48211, state: .running,
                    reason: "Running a shell command.", tool: ("Bash", "pnpm test --filter checkout"), ageMinutes: 14, cost: 1.82),
            session("a2", cli: .claude, title: "Draft onboarding emails", project: "lifecycle-mail", pid: 47990, state: .waiting,
                    reason: "Waiting for approval", tool: ("Write", "emails/welcome.md"), ageMinutes: 52, cost: 0.64),
            session("a4", cli: .claude, title: "Update README badges", project: "ui-kit", pid: 49340, state: .ended, ageMinutes: 31,
                    lastWriteMinutes: 8, cost: 0.31),
            session("a3", cli: .codex, title: "Refactor billing module", project: "ledger-api", pid: 49102, state: .unmeasurable,
                    reason: "No rollout file yet", ageMinutes: 38, lastWriteMinutes: nil, cost: 4.80),
        ]
    }

    /// Sessions of CLIs the engine does not read yet, for the ten-CLI shot (the mock's `SESS_X`, synthetic): a Cursor CLI
    /// session done 2 minutes ago and an ended Copilot CLI one. The core's `CoreCLI` names only Claude Code and Codex, so the
    /// registry id rides beside each (`ActivityPageInput.sessionCLIs`).
    var otherCLISessions: [(cli: String, session: CoreActivitySession)] {
        [
            ("cursor", session("a5", cli: .claude, title: "Add pagination to search", project: "catalog-ui", pid: 50211, state: .idle,
                               ageMinutes: 7, lastWriteMinutes: 2, cost: nil, costNote: "No token usage logged yet")),
            ("copilot", session("a6", cli: .claude, title: "Triage open issues", project: "ops-tools", pid: 50377, state: .ended,
                                ageMinutes: 40, lastWriteMinutes: 6, cost: nil, costNote: "No price for this model")),
        ]
    }

    /// The break-ui extremes: long titles in both scripts, no project, huge costs, a long open command.
    var worstSessions: [CoreActivitySession] {
        let long = "Investigate the intermittent failure in the nightly integration suite that only reproduces on the second retry"
        return [
            session("w1", cli: .claude, title: long, project: nil, pid: 48311, state: .waiting, reason: "Waiting for your answer to a question.",
                    tool: ("AskUserQuestion", ""), ageMinutes: 2_880, cost: 748.52),
            session("w2", cli: .codex, title: "Sửa lỗi đồng bộ hoá dữ liệu giữa các phân vùng khách hàng khi chạy lại tác vụ", project: "ledger-api-with-a-very-long-folder-name",
                    pid: 49202, state: .running, tool: ("shell", "cargo test --workspace --all-features -- --nocapture --test-threads=1"),
                    ageMinutes: 9, cost: 1_974.24),
            session("w3", cli: .claude, title: "2026-11-02 · 00000000", project: nil, pid: 4048, state: .idle, ageMinutes: 600,
                    lastWriteMinutes: 3, cost: nil, costNote: "No price for this model"),
        ]
    }

    private func iso(_ minutesAgo: Double) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: now.addingTimeInterval(-minutesAgo * 60))
    }

    private func failure(_ key: String, kind: CoreFailureKind, cli: CoreCLI, title: String, count: Int, exit: Int?, reason: String,
                         sessions: Int, lastMinutes: Double, laterPassMinutes: Double? = nil, event: String? = nil) -> CoreActivityFailure {
        CoreActivityFailure(kind: kind, cli: cli, key: key, title: title, count: count, exit: exit, reason: reason, projects: ["payments-web"],
                            sessions: sessions, first: nil, last: iso(lastMinutes), laterPass: laterPassMinutes.map(iso),
                            hook: event.map { CoreActivityHookRef(hash: key, event: $0) })
    }

    var failures: [CoreActivityFailure] {
        [
            failure("f1", kind: .hook, cli: .claude, title: "sh '$HOME/.claude/scripts/post-edit-format.sh'", count: 14, exit: 127,
                    reason: "command not found: prettier", sessions: 5, lastMinutes: 20, event: "PostToolUse"),
            failure("f2", kind: .command, cli: .claude, title: "pnpm lint", count: 6, exit: 1, reason: "Lint errors in 3 files", sessions: 2,
                    lastMinutes: 40, laterPassMinutes: 10),
            failure("f3", kind: .command, cli: .codex, title: "cargo test --workspace", count: 3, exit: 101, reason: "test failed", sessions: 1,
                    lastMinutes: 26 * 60),
        ]
    }

    var worstFailures: [CoreActivityFailure] {
        [
            failure("f4", kind: .command, cli: .codex,
                    title: "cargo test --workspace --all-features -- --nocapture --test-threads=1 integration::payments::reconciliation",
                    count: 12_480, exit: nil,
                    reason: "command not found: prettier (run `npm i -g prettier` or add it to devDependencies in package.json)",
                    sessions: 1_204, lastMinutes: 3),
            // The core gave no reason: the quiet line and the inspector leave it out (RB-F3).
            failure("f5", kind: .command, cli: .claude, title: "make deploy-preview", count: 2, exit: 2, reason: "", sessions: 1,
                    lastMinutes: 90),
        ]
    }
}
