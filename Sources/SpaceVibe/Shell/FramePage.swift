/// The pages of the redesign's frame in sidebar order (spec `docs/specs/2026-11-20-spacevibe-redesign.md`, RD-R1: Triage,
/// Agents, Watch). The order is also the ⌘1 to ⌘8 order (RD39). Settings is not a page: it opens its own window (RD4).
///
/// This is the page part of the one route value (plan AR5); RB-S5 adds the selected id and the scope beside it. The raw
/// value is the page's `SPACEVIBE_SHOT_SCREEN` key while the redesign switch is on.
enum FramePage: String, CaseIterable, Identifiable, Sendable {
    case inbox, clean, skills, subagents, hooks, rules, limits, activity

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
}
