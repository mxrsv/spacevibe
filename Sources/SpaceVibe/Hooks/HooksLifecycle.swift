import Foundation

/// The lifecycle the Hooks page groups by (RD-R10 "Hook events"): every event the core reports (`loadout.rows` `events`, 17
/// Claude Code and 10 Codex events today, `core/internal/inventory/types.go`), in firing order. Pure.
enum HooksLifecycle {
    /// The six events every CLI with Hooks shares; the strip always draws them, with or without a Hook.
    static let commonEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Stop"]

    /// The firing order of every event the CLIs report, `registry` order first. Each CLI lists its own events in its firing
    /// order; an event only a later CLI has goes just before the next of its events already placed (Codex's `Interrupt`
    /// lands before `Stop`), or at the end. With no event lists at all (an older core) the common six stand in.
    static func firingOrder(_ events: [String: [String]], registry: [String]) -> [String] {
        let clis = registry.filter { events[$0] != nil } + events.keys.filter { !registry.contains($0) }.sorted()
        var order: [String] = []
        for cli in clis {
            let own = events[cli] ?? []
            for (index, event) in own.enumerated() where !order.contains(event) {
                let next = own[(index + 1)...].first(where: order.contains)
                if let next, let at = order.firstIndex(of: next) { order.insert(event, at: at) } else { order.append(event) }
            }
        }
        for event in commonEvents where !order.contains(event) { order.append(event) }
        return order
    }

    /// The lifecycle stage of a CLI's own event name. Claude Code and Codex, the two CLIs the core reads, use the same names,
    /// so the stage is the event itself; a CLI with its own words (Cursor's `beforeShellExecution` is PreToolUse in the mock)
    /// adds its mapping here when the registry gets it.
    static func stage(of event: String, cli: String) -> String { event }

    /// The events the strip draws: the common six and every other event that has a Hook, in firing order. An event the
    /// lists do not name (a newer CLI) goes at the end.
    static func strip(order: [String], stagesWithHooks: Set<String>) -> [String] {
        let shown = order.filter { commonEvents.contains($0) || stagesWithHooks.contains($0) }
        return shown + stagesWithHooks.subtracting(shown).sorted()
    }

    /// A stage's place in the firing order; an unknown one sorts last.
    static func rank(_ stage: String, in order: [String]) -> Int { order.firstIndex(of: stage) ?? order.count }
}
