import Foundation

/// The four jobs Inbox groups its findings by, in page order (RD-R4).
enum InboxJob: Int, CaseIterable, Comparable, Sendable {
    case cleanUp, balance, control, watch

    var title: String {
        switch self {
        case .cleanUp: "Clean up"
        case .balance: "Balance"
        case .control: "Control"
        case .watch: "Watch"
        }
    }

    static func < (a: InboxJob, b: InboxJob) -> Bool { a.rawValue < b.rawValue }
}

/// How much a finding needs you, shown once per group head by glyph and colour (RD-R16 "Severity"). Balance is
/// information, never a warning.
enum FindingSeverity: Int, Comparable, Sendable {
    case info, attention, critical

    init(_ pace: WindowPace.Severity) { self = pace == .critical ? .critical : .attention }

    static func < (a: FindingSeverity, b: FindingSeverity) -> Bool { a.rawValue < b.rawValue }
}

/// One Claude Code permission file the app reads: global, or a known project's Shared (`project`) or Local (`local`) file.
/// It is also the scope part of the route (`FrameRoute`) and the key of the store's `rules.snapshot` readings.
struct FrameScope: Hashable, Sendable {
    let scope: CoreRuleScope
    /// Nil for the global scope; an absolute project folder otherwise.
    let dir: String?

    static let global = FrameScope(scope: .global, dir: nil)
    static func shared(_ dir: String) -> FrameScope { FrameScope(scope: .project, dir: dir) }
    static func local(_ dir: String) -> FrameScope { FrameScope(scope: .local, dir: dir) }
}

/// A rule that allows a whole tool (RD26, RD-R17). Whether a rule covers a whole tool is the core's `wide` flag (rules.md):
/// the shell never re-derives it, it only keeps the allow ones.
enum WholeToolRule {
    /// A rule without the flag (a core before RB-E6) is never wide: nothing is re-derived in the shell.
    static func isWide(_ rule: CoreRule) -> Bool { rule.wide == true }

    /// The allow rules of one reading that allow a whole tool, from the file that was read only. A reading of another file
    /// than the one asked (the core reads an unknown project as global) holds none.
    static func allows(in snapshot: CoreRulesSnapshot, file: FrameScope) -> [CoreRule] {
        guard snapshot.scope == file.scope, snapshot.dir == file.dir, !snapshot.notReadable else { return [] }
        return snapshot.rules.filter { $0.verdict == .allow && $0.scope == file.scope && $0.dir == file.dir && isWide($0) }
    }
}

/// One Inbox row. The id is what Keep stores, so each kind of finding keeps a stable id:
///
/// - Clean up: the row key; Balance: `bal:<row key>`; failing Hook: `<row key>:fail`;
/// - Control rule: `R:<dir or empty>:<rule id>` (a rule id alone repeats across projects);
/// - Watch Window: `W:<cli>:<window id>:<resetsAt>`, so a kept Window comes back with the next Window ("Inferred, not
///   decided": Keep on watch findings); waiting session: `S:<cli>:<session id>`. The activity report carries no start of a
///   wait, so a kept waiting session stays kept through its later waits until it ends.
///
/// The core stores these ids as given (`findings.keep`) and never reads them, so changing a shape here un-keeps what was
/// kept under the old one.
struct InboxFinding: Identifiable, Equatable, Sendable {
    enum Subject: Equatable, Sendable {
        case row(FrameRow)
        /// Balance: the most-used item missing in a pinned CLI.
        case balance(FrameRow, missingIn: String, sessions: Int)
        /// A Hook with errors in the last 7 days.
        case failingHook(FrameRow, errors: Int)
        case rule(CoreRule, file: FrameScope)
        case window(WindowPace)
        case session(CoreActivitySession)
    }

    let id: String
    let job: InboxJob
    let severity: FindingSeverity
    let subject: Subject
}

/// A job's rows under one head, severity shown once at the head (RD-R4).
struct InboxGroup: Identifiable, Equatable, Sendable {
    let job: InboxJob
    let findings: [InboxFinding]

    var id: InboxJob { job }
    var severity: FindingSeverity { findings.map(\.severity).max() ?? .info }
}

/// The inputs a finding needs beside the rows. Each one left nil or empty means "no such finding", never a made-up count
/// (FE-D3).
struct FindingFacts: Equatable, Sendable {
    /// Hook errors in the last 7 days, by row key: `errorsLast7Days` of the row's `cliCells`, summed over CLIs
    /// (`hookErrorsLastWeek(in:)`, filled by the store from each `loadout.rows`). A row with no 7-day count on any cell is
    /// absent: unknown, never 0. Lifetime errors never stand in (RD26).
    var hookErrorsLastWeek: [String: Int]?
    /// The Keep list, finding ids: the store fills it from `findings.kept` (`<data>/kept-findings.json`).
    var kept: Set<String> = []
    /// Balance pins from Settings › CLIs (RB-R8), registry ids. Fewer than two pins: no Balance finding.
    var pinned: [String] = []

    /// Each Hook row's errors in the last 7 days over every CLI that reports them; rows whose cells carry no week are left
    /// out. Every member of a row key holds the same `cliCells`, so the first one stands for the row.
    static func hookErrorsLastWeek(in loadout: CoreLoadoutRows) -> [String: Int] {
        var out: [String: Int] = [:]
        for hook in loadout.hooks where out[hook.key] == nil {
            let week = (hook.cliCells ?? [:]).values.compactMap(\.errorsLast7Days)
            if !week.isEmpty { out[hook.key] = week.reduce(0, +) }
        }
        return out
    }
}

enum Findings {
    /// Every finding, kept ones split off (RD-R4: kept findings leave the count and sit under `N kept · Show`). Port of the
    /// "Inbox findings" block of the reference mock's `world`.
    static func all(
        rows: [FrameRow], wideAllows: [(rule: CoreRule, file: FrameScope)], windows: [WindowPace], sessions: [CoreActivitySession],
        shownCLIs: [String], facts: FindingFacts, folders: [CoreReadersFolder] = []
    ) -> (open: [InboxFinding], kept: [InboxFinding]) {
        var found: [InboxFinding] = []
        let quiet = rows.filter { !$0.isRecentlyAdded && !$0.isPlugin && !$0.isProject && !$0.isHookSpaceVibeDoesNotWrite }
        for row in quiet where row.status == .dead {
            found.append(InboxFinding(id: row.id, job: .cleanUp, severity: .critical, subject: .row(row)))
        }
        for row in quiet where row.status == .neverRan {
            found.append(InboxFinding(id: row.id, job: .cleanUp, severity: .attention, subject: .row(row)))
        }
        if let balance = balance(rows: rows, pinned: facts.pinned.filter(shownCLIs.contains), folders: folders) { found.append(balance) }
        for row in rows where row.kind == .hook {
            guard let errors = facts.hookErrorsLastWeek?[row.id], errors > 0 else { continue }
            found.append(InboxFinding(id: "\(row.id):fail", job: .control, severity: .attention, subject: .failingHook(row, errors: errors)))
        }
        for (rule, file) in wideAllows {
            found.append(InboxFinding(id: "R:\(file.dir ?? ""):\(rule.id)", job: .control, severity: .attention, subject: .rule(rule, file: file)))
        }
        for window in windows where window.isBehind {
            let id = "W:\(window.cli):\(window.window.id):\(window.window.resetsAt)"
            found.append(InboxFinding(id: id, job: .watch, severity: FindingSeverity(window.severity), subject: .window(window)))
        }
        for session in sessions where session.state == .waiting {
            found.append(InboxFinding(id: "S:\(session.cli.rawValue):\(session.id)", job: .watch, severity: .attention, subject: .session(session)))
        }
        return (found.filter { !facts.kept.contains($0.id) }, found.filter { facts.kept.contains($0.id) })
    }

    /// One Balance finding at most: the most-used item, by sessions in the pinned CLIs that have it, missing in a pinned CLI;
    /// none with fewer than two pins ("Inferred, not decided": Balance finding). A row with an unknown cell is never judged.
    /// Only what `Add to <CLI>` can do is offered: never a plugin or project item (the engine copies neither, "Inferred, not
    /// decided": Project items), and never into a CLI that has no folder of the kind SpaceVibe copies into (`folders`, the
    /// readers map: not installed, or no such folder). Without a readers map the engine is left to refuse.
    static func balance(rows: [FrameRow], pinned: [String], folders: [CoreReadersFolder] = []) -> InboxFinding? {
        guard pinned.count >= 2 else { return nil }
        func canCopy(_ row: FrameRow, into cli: String) -> Bool {
            folders.isEmpty || folders.contains { $0.ownedBy == cli && $0.kind == row.kind && $0.copyTarget }
        }
        let offered = rows.filter { $0.kind != .hook && !$0.isPlugin && !$0.isProject && !$0.cells.values.contains(.unknown) }
        let scored = offered.compactMap { row -> (FrameRow, String, Int)? in
            guard let missing = pinned.first(where: { row.cell($0) == .missing && canCopy(row, into: $0) }) else { return nil }
            let sessions = pinned.compactMap { row.cell($0).count }.reduce(0, +)
            return sessions > 0 ? (row, missing, sessions) : nil
        }
        guard let top = scored.max(by: { $0.2 < $1.2 }) else { return nil }
        return InboxFinding(id: "bal:\(top.0.id)", job: .balance, severity: .info, subject: .balance(top.0, missingIn: top.1, sessions: top.2))
    }

    /// The groups in page order, empty jobs left out.
    static func groups(_ findings: [InboxFinding]) -> [InboxGroup] {
        InboxJob.allCases.compactMap { job in
            let rows = findings.filter { $0.job == job }
            return rows.isEmpty ? nil : InboxGroup(job: job, findings: rows)
        }
    }
}

extension FrameRow {
    /// SpaceVibe writes Hooks only into Claude Code (D25, RB-R3): a Hook no Claude Code member holds (Codex or another CLI
    /// only) is a fact in the Hooks hero but, like a plugin item, never suggested, never an Inbox Clean up finding and never
    /// offered Remove.
    var isHookSpaceVibeDoesNotWrite: Bool { kind == .hook && !hooks.contains { $0.cli == .claude } }
}
