import Foundation
import SwiftUI

/// `SPACEVIBE_SHOT_SCREEN=glance`: the session glance widget's two views (spec `docs/specs/2026-11-19-session-glance-widget.md`)
/// drawn headless from in-memory reports with synthetic titles (the mock's data sets), in dark and light. Nothing is read: no
/// core, no home, no defaults. Each view sits on the shot stage (`ShotRenderer.writeFloating`); the panel's drop shadow and the
/// hover fill of a row are not drawn here, since the window draws the one and only a pointer makes the other.
///
/// - `glance-strip-states`: one entry in each state (waiting, working, done, unmeasurable, idle), in a row.
/// - `glance-strip-many`: twelve sessions, six shown and `+6`.
/// - `glance-strip-vertical`: the right edge middle's column, every state.
/// - `glance-strip-empty`: no session, the faint mark.
/// - `glance-list`, `glance-list-long` (long Greek and CJK titles, very long tool text), `glance-list-many` (twelve rows at the
///   list's height cap, scrolled to the top), `glance-list-empty` ("No session running").
@MainActor
enum GlanceShots {
    static func run(into directory: URL) throws {
        let all = entries(GlanceShotData.all)
        let many = entries(GlanceShotData.many)
        try ShotHarness.check(Set(all.all.map(\.state)) == Set(GlanceState.allCases), "the state set holds every glance state")
        try ShotHarness.check(GlanceStrip(entries: many, slot: .bottomRight).items.last == .overflow(6), "twelve sessions show six and +6")
        try ShotHarness.check(GlanceStrip(entries: all, slot: .rightMiddle).axis == .vertical, "the right edge middle stacks the strip")

        for choice in [AppearanceChoice.dark, .light] {
            func write(_ view: some View, _ name: String) throws {
                try ShotRenderer.writeFloating(view, name: name, choice: choice, to: directory)
            }
            try write(strip(all, slot: .bottomRight), "glance-strip-states")
            try write(strip(many, slot: .topRight), "glance-strip-many")
            try write(strip(all, slot: .rightMiddle), "glance-strip-vertical")
            try write(strip(.empty, slot: .bottomRight), "glance-strip-empty")
            try write(list(all), "glance-list")
            try write(list(entries(GlanceShotData.long)), "glance-list-long")
            try write(scrolledList(many), "glance-list-many")
            try write(list(.empty), "glance-list-empty")
        }
    }

    private static func entries(_ sessions: [CoreActivitySession]) -> GlanceEntries {
        GlanceEntries(report: CoreActivityReport(sessions: sessions, failures: [], files: [], unmeasurable: [],
                                                 stats: CoreActivityStats(logs: sessions.count, truncated: 0)))
    }

    private static func strip(_ entries: GlanceEntries, slot: GlanceSlot) -> GlanceStripView {
        GlanceStripView(strip: GlanceStrip(entries: entries, slot: slot), isOnScreen: true, open: { _ in })
    }

    /// The list as the controller sizes it when it fits: rows at the list's width, a sentence at its own.
    private static func list(_ entries: GlanceEntries) -> GlanceListView {
        GlanceListView(entries: entries.all, note: GlanceWording.noSession, width: entries.isEmpty ? nil : Metrics.Glance.listWidth,
                       isOnScreen: true, hint: { _ in GlanceWording.activity }, open: { _ in })
    }

    /// A list taller than the cap, scrolled to the top, sized as `GlanceController` sizes it.
    private static func scrolledList(_ entries: GlanceEntries) -> some View {
        GlanceListView(entries: entries.all, note: GlanceWording.noSession, width: Metrics.Glance.listWidth,
                       rowsHeight: Metrics.Glance.listMaxHeight - 2 * Metrics.Glance.listPadding,
                       isOnScreen: true, hint: { _ in GlanceWording.activity }, open: { _ in })
    }
}

/// The mock's data sets (`session-glance-widget.html`: normal, all, long, many) as core sessions. Synthetic titles only (S-R2).
private enum GlanceShotData {
    /// A session in `state`; `minutesAgo` is its last write, which also splits an idle session into done (within 10 minutes)
    /// and idle.
    private static func session(_ index: Int, _ cli: CoreCLI, _ state: GlanceState, _ title: String, tool: CoreActivityTool? = nil,
                                reason: String = "Log written 2 s ago", minutesAgo: Double = 0) -> CoreActivitySession {
        let core: CoreSessionState = switch state {
        case .waiting: .waiting
        case .working: .running
        case .unmeasurable: .unmeasurable
        case .done, .idle: .idle
        }
        let ago = state == .idle ? max(minutesAgo, 40) * 60_000 : minutesAgo * 60_000
        return CoreActivitySession(cli: cli, id: "shot-\(index)", title: title, project: nil, pid: 41_000 + index, state: core,
                                   stateReason: reason, reasonCode: nil, currentTool: tool, ageMs: 3_600_000,
                                   lastWriteAgoMs: ago, cost: nil, costNote: nil)
    }

    private static func tool(_ name: String, _ target: String) -> CoreActivityTool {
        CoreActivityTool(name: name, target: target)
    }

    /// The mock's "Đủ trạng thái": its normal five and an unmeasurable Codex process.
    static let all: [CoreActivitySession] = [
        session(1, .claude, .idle, "Tidy the docs index", minutesAgo: 40),
        session(2, .claude, .working, "Fix the Activity poll after sleep", tool: tool("Bash", "scripts/test.sh"), minutesAgo: 1),
        session(3, .codex, .done, "Port usage scan to Go", reason: "Finished 3 min ago", minutesAgo: 3),
        session(4, .claude, .waiting, "Rename the Limits card", reason: "Asks: keep the old key?"),
        session(5, .codex, .working, "Landing copy pass", tool: tool("Edit", "site/app/copy.ts")),
        session(6, .codex, .unmeasurable, "pid 48213", reason: "Rollout could not be read", minutesAgo: 2),
    ]

    /// The mock's "Tên dài": the longest titles and tool text, Greek and CJK, and a one-letter title.
    static let long: [CoreActivitySession] = [
        session(1, .claude, .waiting,
                "Investigate why the subscription limit window resets twice when the status line capture restarts during a long session",
                reason: "Asks: replace ~/.claude/settings.json statusLine with the captured wrapper command and keep a backup?"),
        session(2, .codex, .working, "Ταξινόμηση των αρχείων καταγραφής ανά έργο και ημερομηνία — 日本語のタイトルも長い",
                tool: tool("Bash", "cd core && go vet ./... && SPACEVIBE_TEST=1 go test -count=1 ./internal/activity/...")),
        session(3, .claude, .unmeasurable, "x", reason: "Tool call open, no log write for 30 s", minutesAgo: 1),
    ]

    /// The mock's "12 session".
    static let many: [CoreActivitySession] = {
        let states: [GlanceState] = [.working, .working, .idle, .done, .waiting, .working, .idle, .unmeasurable, .working, .done, .idle, .working]
        let names = ["refactor rows", "go tests", "docs pass", "icons", "limits", "site build", "hooks", "codex lock", "stop flow", "tokens",
                     "settings", "release"]
        return states.indices.map { index in
            let tool = index % 2 == 1 ? tool("Bash", "npm run build") : tool("Edit", "Sources/SpaceVibe/App/AppDelegate.swift")
            return session(index + 1, index % 3 == 0 ? .codex : .claude, states[index],
                           "Session \(String(format: "%02d", index + 1)) · \(names[index])", tool: tool,
                           reason: states[index] == .unmeasurable ? "Rollout could not be read" : "Log written 2 s ago",
                           minutesAgo: Double(index))
        }
    }()
}
