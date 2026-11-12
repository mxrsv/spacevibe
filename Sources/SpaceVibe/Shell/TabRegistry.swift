import SwiftUI

/// The single place that lists the app's tabs. Order is sidebar order and decides `⌘1`, `⌘2`, `⌘3`.
/// A screen agent replaces its stub here with the real tab; nothing else in `Shell/` changes.
///
/// Agents, Activity and Limits are the same in development and distribution builds.
@MainActor
enum TabRegistry {
    static let agentsID = "agents"
    static let activityID = "activity"
    static let limitsID = "limits"

    static func makeTabs() -> [any SpaceVibeTab] {
        [AgentsPage(), ActivityTab(), LimitsTab()]
    }
}
