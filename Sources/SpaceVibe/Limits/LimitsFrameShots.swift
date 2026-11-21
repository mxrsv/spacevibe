import Foundation
import SwiftUI

/// `SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=limits`: after the live frame on Limits, the redesign's Limits page in every
/// state of RD-R13 from synthetic readings (the reference mock's `LIM` and its states), at a fixed clock, in the frame, in
/// both looks and appearances: `frame-limits-<state>-<look>-<appearance>.png`. Nothing is read: no core, no home, no
/// defaults. Limits writes nothing, so its write, refused-write and dialog cells are the normal page (the mock's `MOCK.na`).
///
/// - `normal`: Claude Code's 5-hour Window counting down at 42 min, Codex's 5-hour Window faster than time (the hero).
/// - `selected`: the same, with Codex's 5-hour row selected by the keyboard (the widget's pill lands like this, LC-R7).
/// - `empty`: Claude Code has no reading yet (Copy Install Command, RD24).
/// - `scanning`: the first `limits.read` has not answered.
/// - `error`: Codex's record cannot be read (Try Again); `failed`: the whole read failed with nothing read before.
/// - `worst`: Claude Code's reading 7 hours old (shown, not judged), its 5-hour Window past its reset, a model Window with no
///   length; Codex at 4% left and over its weekly limit; a long plan name.
/// - `many`: ten CLIs, eight of them without limit data on one Unmeasurable line (RD-R10).
/// - `weekly`: a weekly Window counting at the 24 h lead (H:MM:SS), beside rows that do not count.
@MainActor
enum LimitsFrameShots {
    static func run(into directory: URL) throws {
        for choice in [AppearanceChoice.dark, .light] {
            for look in ShotRenderer.frameLooks {
                for scenario in LimitsFrameShotData.Scenario.allCases {
                    try ShotRenderer.write(view(scenario, look: look, choice: choice), name: "frame-limits-\(scenario.rawValue)-\(look)",
                                           choice: choice, to: directory)
                }
            }
        }
    }

    private static func view(_ scenario: LimitsFrameShotData.Scenario, look: MaterialLook, choice: AppearanceChoice) -> some View {
        let cards = scenario.cards
        let sidebar = FrameSidebarValues(values: [.limits: scenario.sidebarValue])
        let selected = scenario == .selected ? cards.rowIDs.first { $0.hasPrefix("codex:") } : nil
        return AppFrame(page: .limits, env: AppEnvironment.shared, look: look, sidebarValues: sidebar) { _, _ in
            FramePageContent(help: FramePage.limits.help,
                             body: AnyView(LimitsCardList(cards: cards, selection: selected, keyboardRow: selected,
                                                          pinnedNow: LimitsFrameShotData.now)))
        }
        .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)),
                       toasts: ToastCenter(announce: false), env: AppEnvironment.shared)
        .frame(width: ShotRenderer.size.width, height: ShotRenderer.size.height)
    }
}

/// Synthetic limit readings for the Limits shots and tests (S-R2): the mock's `LIM` windows at a fixed clock.
enum LimitsFrameShotData {
    enum Scenario: String, CaseIterable {
        case normal, selected, empty, scanning, error, failed, worst, many, weekly

        var snapshot: FrameSnapshot {
            var snapshot = FrameSnapshot()
            snapshot.registry = self == .many ? LimitsFrameShotData.manyRegistry : LimitsFrameShotData.registry
            switch self {
            case .normal, .selected, .many: snapshot.limits = LimitsFrameShotData.normal
            case .empty: snapshot.limits = LimitsFrameShotData.empty
            case .scanning, .failed: snapshot.limits = nil
            case .error: snapshot.limits = LimitsFrameShotData.error
            case .worst: snapshot.limits = LimitsFrameShotData.worst
            case .weekly: snapshot.limits = LimitsFrameShotData.weekly
            }
            return snapshot
        }

        var state: FrameSourceState {
            switch self {
            case .scanning: .loading
            case .failed: .failed("The core could not be started.")
            default: .ready
            }
        }

        var weeklyLead: WeeklyCountdownLead { self == .weekly ? .hours24 : .standard }

        var world: FrameWorld { FrameWorld(snapshot: snapshot, now: LimitsFrameShotData.now) }

        var cards: LimitsCards { LimitsCards(world: world, state: state, now: LimitsFrameShotData.now, weeklyLead: weeklyLead) }

        /// What the sidebar shows beside Limits: the same figure the hero reads (AR3).
        var sidebarValue: FrameSidebarValue {
            let loading: Set<FrameSource> = state == .loading ? [.limits] : []
            let failed: Set<FrameSource> = if case .failed = state { [.limits] } else { [] }
            return FrameSidebarValue(figure: world.figure(for: .limits, loading: loading, failed: failed), page: .limits)
        }
    }

    /// 2026-11-19 17:30 local time, so the reset clock times read like the mock's.
    static let now: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 17, minute: 30)) ?? Date()

    static let all = CoreRegistrySupports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)
    static let registry = [CoreRegistryCLI(id: "claude", name: "Claude Code", supports: all),
                           CoreRegistryCLI(id: "codex", name: "Codex", supports: all)]
    /// Ten CLIs: the two the engine reads, and eight that keep no limit record SpaceVibe can read.
    static let manyRegistry = registry + ["Cursor CLI", "Copilot CLI", "opencode", "Amp", "Antigravity CLI", "Kiro", "Qwen Code", "Aider"]
        .enumerated().map { index, name in
            CoreRegistryCLI(id: "cli\(index + 2)", name: name,
                            supports: CoreRegistrySupports(skill: true, agent: index % 2 == 0, hook: index % 3 == 0, rule: false, logs: true, limits: false))
        }

    static func window(_ id: String, _ minutes: Int?, used: Double, resetsIn minutesLeft: Double, scope: String? = nil,
                       current: Bool = true) -> CoreLimitWindow {
        CoreLimitWindow(id: id, minutes: minutes, scope: scope, usedPercent: used, resetsAt: now.timeIntervalSince1970 + minutesLeft * 60,
                        active: true, current: current)
    }

    static func entry(_ cli: CoreLimitsCLI, _ windows: [CoreLimitWindow], plan: String? = nil, source: CoreLimitsSource? = nil,
                      readAgo minutes: Double, state: CoreLimitsState = .measured) -> CoreLimitsEntry {
        CoreLimitsEntry(cli: cli, state: state, plan: plan, source: source,
                        at: state == .measured ? now.timeIntervalSince1970 - minutes * 60 : nil, windows: state == .measured ? windows : [])
    }

    static let claudeFiveHour = window("five_hour", 300, used: 62, resetsIn: 42)
    static let claudeWeekly = window("seven_day", 10080, used: 31, resetsIn: 6480)
    static let codexFiveHour = window("primary", 300, used: 23, resetsIn: 246)
    static let codexWeekly = window("secondary", 10080, used: 48, resetsIn: 4800)

    static let normal = CoreLimitsResult(limits: [
        entry(.claude, [claudeFiveHour, claudeWeekly], source: .claudeStatusline, readAgo: 12),
        entry(.codex, [codexFiveHour, codexWeekly], plan: "pro", readAgo: 3),
        // `limits.read` still answers for Gemini CLI; the registry does not list it, so it never shows (RD21).
        entry(.gemini, [], readAgo: 0, state: .notMeasurable),
    ])

    static let empty = CoreLimitsResult(limits: [
        entry(.claude, [], readAgo: 0, state: .notRecorded),
        entry(.codex, [window("primary", 300, used: 12, resetsIn: 246), codexWeekly], plan: "pro", readAgo: 3),
    ])

    static let error = CoreLimitsResult(limits: [
        entry(.claude, [claudeFiveHour, claudeWeekly], source: .claudeStatusline, readAgo: 12),
        entry(.codex, [], readAgo: 0, state: .unreadable),
    ])

    static let worst = CoreLimitsResult(limits: [
        entry(.claude, [window("five_hour", 300, used: 62, resetsIn: -20, current: false), claudeWeekly,
                        window("weekly", nil, used: 30.5, resetsIn: 6480, scope: "Fable")],
              source: .claudeStatusline, readAgo: 7 * 60),
        entry(.codex, [window("primary", 300, used: 96, resetsIn: 246), window("secondary", 10080, used: 104.5, resetsIn: 4800)],
              plan: "Business (annual, 150 seats, invoiced through the reseller)", readAgo: 3),
    ])

    static let weekly = CoreLimitsResult(limits: [
        entry(.claude, [window("five_hour", 300, used: 20, resetsIn: 180), window("seven_day", 10080, used: 88, resetsIn: 23 * 60 + 12.1)],
              source: .claudeStatusline, readAgo: 12),
        entry(.codex, [codexFiveHour, codexWeekly], plan: "pro", readAgo: 3),
    ])
}
