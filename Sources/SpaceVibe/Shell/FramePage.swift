import SwiftUI

/// The pages of the redesign's frame in sidebar order (spec `docs/specs/2026-11-20-spacevibe-redesign.md`, RD-R1: Triage,
/// Agents, Watch). The order is also the ⌘1 to ⌘8 order (RD39, `FrameRoute.page(forShortcut:)`). Settings is not a page: it
/// opens its own window (RD4).
///
/// This is the page part of the one route value (plan AR5, `FrameRoute`). The raw value is the page's
/// `SPACEVIBE_SHOT_SCREEN` key while the redesign switch is on.
enum FramePage: String, CaseIterable, Identifiable, Sendable {
    case inbox, clean, skills, subagents, hooks, rules, limits, activity

    /// The sidebar's groups (RD-R1), in order; their pages in order make `allCases`.
    enum SidebarGroup: String, CaseIterable, Identifiable, Sendable {
        case triage, agents, watch

        var id: String { rawValue }

        var title: String {
            switch self {
            case .triage: "Triage"
            case .agents: "Agents"
            case .watch: "Watch"
            }
        }

        var pages: [FramePage] { FramePage.allCases.filter { $0.group == self } }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .clean: "Clean"
        case .skills: "Skills"
        case .subagents: "Subagents"
        case .hooks: "Hooks"
        case .rules: "Rules"
        case .limits: "Limits"
        case .activity: "Activity"
        }
    }

    var group: SidebarGroup {
        switch self {
        case .inbox, .clean: .triage
        case .skills, .subagents, .hooks, .rules: .agents
        case .limits, .activity: .watch
        }
    }

    /// The page icon from SpaceVibe's own set (RD23, RB-S6).
    var icon: FrameIcon {
        switch self {
        case .inbox: .inbox
        case .clean: .clean
        case .skills: .skills
        case .subagents: .subagents
        case .hooks: .hooks
        case .rules: .rules
        case .limits: .limits
        case .activity: .activity
        }
    }

    /// The category tone of an Agents page's icon (FE-C2: one identity tone per category); the other pages keep the ink.
    var categoryTone: Color? {
        switch self {
        case .skills: ColorRole.toneSkills
        case .subagents: ColorRole.toneSubagents
        case .hooks: ColorRole.toneHooks
        case .rules: ColorRole.toneRules
        case .inbox, .clean, .limits, .activity: nil
        }
    }

    /// The page's `?` (RD32): one or two plain sentences, opened by a click only. The reference mock's `HELP` (`b-chrome.js`).
    var help: String {
        switch self {
        case .inbox:
            "What needs you now: unused or dead items, gaps between CLIs, open rules and failing hooks, limits running out, "
                + "sessions waiting. Keep a finding to stop counting it."
        case .skills: "Every Skill and the CLIs that load it. A logo turns a CLI on or off; Never ran means no session used it."
        case .subagents:
            "Every Subagent and the CLIs that load it. A logo turns a CLI on or off; Never ran means no session used it."
        case .hooks: "Commands a CLI runs on an event, in firing order. SpaceVibe shows and removes them but never runs them."
        case .rules:
            "What each CLI may do without asking. Claude Code rules can be changed here; other CLIs are shown in their own terms."
        case .clean: "What CLIs leave behind: unused items, old session logs, caches. Logs of a CLI in use stay until its sessions end."
        case .limits: "How much of each plan Window is left, judged against the time left. A Window counts down near its reset."
        case .activity: "Sessions running now and commands that failed. Stop ends a session and cannot be undone."
        }
    }

    /// Whether the page has a trailing inspector (the mock's `hasIns`): Clean and Limits have none.
    var hasInspector: Bool {
        switch self {
        case .inbox, .skills, .subagents, .hooks, .rules, .activity: true
        case .clean, .limits: false
        }
    }

    /// Whether the toolbar keeps the 196 pt primary slot even when the page shows no button in it (the mock's empty
    /// `span.slot`), so the controls before it never move when the button comes and goes (FE-L1). Limits has no slot.
    var hasToolbarSlot: Bool { self != .limits }

    /// The inspector's width on this page: wide where it holds the CLI tile grid.
    var inspectorWidth: InspectorWidth {
        switch self {
        case .skills, .subagents, .inbox: .wide
        case .clean, .hooks, .rules, .limits, .activity: .standard
        }
    }
}
