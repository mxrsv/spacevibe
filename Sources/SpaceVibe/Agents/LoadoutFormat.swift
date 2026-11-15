import Foundation

/// Wording and mapping of the Loadout screen. Pure.
enum LoadoutFormat {
    /// The date of the oldest session log the scan read, over both CLIs; nil when no log has a date.
    static func usageSince(_ result: CoreUsageResult?) -> String? {
        guard let result else { return nil }
        return [result.windows.claude.oldest, result.windows.codex.oldest].compactMap { $0 }.min()
    }

    /// What the counts rest on. They come from every session log found, not a fixed window, so it says how many and since when.
    static func usageNote(result: CoreUsageResult?, progress: CoreUsageProgress?, failure: String?) -> String {
        if let result {
            let since = usageSince(result)
            let claude = result.sessions.claude.formatted(.number.locale(Locale(identifier: "en_US")))
            let codex = result.sessions.codex.formatted(.number.locale(Locale(identifier: "en_US")))
            return "Counted from \(claude) Claude Code and \(codex) Codex sessions" + (since.map { " since \($0)" } ?? "")
        }
        if failure != nil { return "Usage could not be counted" }
        if let progress, progress.total > 0 { return "Counting usage, \(progress.done) of \(progress.total) logs" }
        return "Counting usage"
    }

    static func removeLabel(row: LoadoutRow, member: LoadoutMember) -> String {
        let cli = member.cli.label
        if case .hook(let hook) = member { return "Removed \(hook.event) hook from \(cli)" }
        return "Removed \(row.kind.noun) \(row.name) from \(cli)"
    }

    static func addLabel(row: LoadoutRow, to cli: CoreCLI) -> String {
        "Added \(row.kind.noun) \(row.name) to \(cli.label)"
    }
}
