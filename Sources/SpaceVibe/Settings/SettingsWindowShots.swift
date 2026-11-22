import Foundation
import SwiftUI

/// `SPACEVIBE_SHOT_SCREEN=settings` with `SPACEVIBE_REDESIGN=1`: the redesign's Settings window (RB-R8) from synthetic data,
/// every pane in the normal state and every state of `SettingsWindowState` on the pane it opens, plus the Journal window's
/// four states. `SPACEVIBE_SHOT_STATE=<state>` draws one state (`normal` draws every pane), `journal` only the Journal window,
/// `all` (or unset) everything. Preferences and the login item are in memory and the updater never starts, so nothing is
/// read from or saved to the machine.
///
/// Names: `settings-window-<pane>-…` (normal), `settings-window-<state>-…`, `journal-window-<state>-…`, each
/// `-<look>-<appearance>.png`.
@MainActor
enum SettingsWindowShots {
    static let now = Date(timeIntervalSince1970: 1_763_900_000)
    static let journalKey = "journal"

    static func run(into directory: URL, state key: String?) throws {
        let key = key ?? "all"
        guard key == "all" || key == journalKey || SettingsWindowState(rawValue: key) != nil else {
            throw ShotHarness.Failure("unknown SPACEVIBE_SHOT_STATE \(key) (all, \(journalKey), "
                + SettingsWindowState.allCases.map(\.rawValue).joined(separator: ", ") + ")")
        }
        let suite = "dev.spacevibe.shots.settings-window.\(UUID().uuidString)"
        guard let glanceDefaults = UserDefaults(suiteName: suite) else {
            throw ShotHarness.Failure("could not open the throwaway defaults suite \(suite)")
        }
        defer { glanceDefaults.removePersistentDomain(forName: suite) }
        let glance = GlancePreferences(defaults: glanceDefaults)
        let updates = AppEnvironment.shared.updates
        updates.version = "0.2.0"
        updates.build = "3"
        updates.isRunning = true
        updates.automaticChecks = true
        updates.status = .upToDate
        updates.lastCheck = now.addingTimeInterval(-3_600)

        for choice in [AppearanceChoice.dark, .light] {
            for look in ShotRenderer.frameLooks {
                func draw(_ preview: SettingsWindowPreview, pane: SettingsPane = .general, name: String) throws {
                    let view = SettingsWindowFrame(pane: pane, preview: preview)
                        .frameLookRoot(forced: look)
                        .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)),
                                       toasts: ToastCenter(announce: false), env: .shared)
                    try ShotRenderer.write(view, name: "settings-window-\(name)-\(look)", choice: choice, to: directory, fullHeight: true)
                }
                if key == "all" || key == SettingsWindowState.normal.rawValue {
                    for pane in SettingsPane.allCases { try draw(preview(.normal, glance: glance), pane: pane, name: pane.rawValue) }
                }
                for state in SettingsWindowState.allCases where state != .normal && (key == "all" || key == state.rawValue) {
                    try draw(preview(state, glance: glance), name: state.rawValue)
                }
                if key == "all" || key == journalKey {
                    for (name, facts) in journalStates() {
                        let view = JournalWindow(preview: facts)
                            .frameLookRoot(forced: look)
                            .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)),
                                           toasts: ToastCenter(announce: false), env: .shared)
                        try ShotRenderer.write(view, name: "journal-window-\(name)-\(look)", choice: choice, to: directory, fullHeight: true)
                    }
                }
            }
        }
    }

    /// The window in `state` from synthetic data: 2 CLIs (10 for worst, three pinned for dialog), a snapshot 12 minutes old
    /// (none for empty, a failed read for error), Open at login waiting for approval, refused for refused.
    static func preview(_ state: SettingsWindowState, glance: GlancePreferences) -> SettingsWindowPreview {
        let registry = registry(count: state == .worst || state == .dialog ? 10 : 2)
        let limits: FrameSourceState = state == .error ? .failed("The limits could not be read.") : .ready
        let facts = SettingsFacts(registry: registry, statuslineAt: state == .empty || state == .error ? nil : now.addingTimeInterval(-720),
                                  limits: limits)
        let pins: [String]? = state == .dialog ? ["claude", "codex", "cursor"] : nil
        let hidden: Set<String> = state == .worst ? ["opencode", "aider"] : []
        let login = StandInLoginItem(status: state == .refused ? .off : .needsApproval)
        return SettingsWindowPreview(
            state: state, facts: facts, now: now,
            cli: CLIPreferences(defaults: nil, hidden: hidden, pins: pins),
            glance: glance,
            countdown: LimitsCountdownPreferences(defaults: nil),
            loginItem: LoginItem(service: login), dataFolder: SettingsDataWording.dataFolder(environment: [:]),
            refusal: state == .refused ? LoginItemWording.refused(turningOn: true, reason: "Operation not permitted") : nil)
    }

    /// Rows (one undone, one with a very long label in two lines, one from last year with its year), empty, unreadable, and
    /// still reading. The rows are dated from the moment of the shot, as the window reads them (`JournalList` against now):
    /// just now, earlier today, three days ago, a year ago.
    static func journalStates(now: Date = Date()) -> [(String, SettingsFacts)] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let ago = { (minutes: Double) in formatter.string(from: now.addingTimeInterval(-minutes * 60)) }
        let entries = [
            CoreJournalEntry(id: "j3", at: ago(2), label: "Removed ponytail from Codex", undone: false, count: 1),
            CoreJournalEntry(id: "j2", at: ago(48), label: "Changed Bash(git push:*) from Allow to Ask", undone: true, count: 1),
            CoreJournalEntry(id: "j1", at: ago(3 * 24 * 60),
                             label: "Removed 12 Skills, Subagent review-every-pull-request-before-it-merges-into-the-main-branch and 3 Hooks",
                             undone: false, count: 16),
            CoreJournalEntry(id: "j0", at: ago(366 * 24 * 60), label: "Added Bash(git log:*) as Allow in ~/.claude/settings.json",
                             undone: false, count: 1),
        ]
        return [
            ("rows", SettingsFacts(journal: CoreJournalHistory(entries: entries), journalState: .ready)),
            ("empty", SettingsFacts(journal: CoreJournalHistory(entries: []), journalState: .ready)),
            ("error", SettingsFacts(journalState: .failed("The Journal could not be read: ~/.spacevibe/journal.json is not valid JSON."))),
            ("pending", SettingsFacts(journalState: .loading)),
        ]
    }

    /// The reference mock's CLIs (`CLIS_BY_N`, `SUPPORT` in `src/a-core.js`), synthetic beyond the two read today.
    static func registry(count: Int) -> [CoreRegistryCLI] {
        let all: [(String, String, [Bool])] = [
            ("claude", "Claude Code", [true, true, true, true, true, true]), ("codex", "Codex", [true, true, true, true, true, true]),
            ("cursor", "Cursor CLI", [true, true, true, true, false, false]), ("copilot", "Copilot CLI", [true, true, true, false, true, true]),
            ("opencode", "opencode", [true, true, false, true, false, false]), ("amp", "Amp", [true, false, false, true, false, false]),
            ("antigravity", "Antigravity CLI", [true, true, true, false, false, false]), ("kiro", "Kiro", [true, true, true, true, false, false]),
            ("qwen", "Qwen Code", [false, true, false, false, false, false]), ("aider", "Aider", [false, false, false, false, false, false]),
        ]
        return all.prefix(count).map { id, name, s in
            CoreRegistryCLI(id: id, name: name, supports: CoreRegistrySupports(skill: s[0], agent: s[1], hook: s[2], rule: s[3], logs: s[4], limits: s[5]))
        }
    }
}
