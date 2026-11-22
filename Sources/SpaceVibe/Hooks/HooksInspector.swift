import SwiftUI

/// The Hooks inspector (the mock's `hookInspector`): the Hook's name (the script it runs) in mono with the Hooks icon in its
/// tone, its event, matcher and CLI, the full command, the facts (runs, a missing script, average time, errors in 7 days and
/// in all, last run, when it was added, the file, a project's scope) and `Copy Command` across the column. Nothing selected
/// (no row shown): the empty state.
struct HooksInspector: View {
    let model: FrameModel
    let state: HooksPageState
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        let list = HooksListModel.from(model.store, view: state.view, query: model.search.query)
        if let row = list.row(model.router.route.selection), list.visible.contains(where: { $0.id == row.id }) {
            let holder = list.holder(of: row)
            VStack(alignment: .leading, spacing: SpaceRole.step16) {
                InspectorTitle(row.label, sub: HooksInspectorFacts.headline(row, cli: holder), isMono: true) {
                    FrameGlyph(.hooks, side: SizeRole.icon20, ink: ColorRole.toneHooks)
                }
                InspectorSection("Command") { CommandBlock(row.command) }
                KeyValueList(facts: HooksInspectorFacts.facts(row, cli: holder, now: Date()))
                InspectorActions(actions: [
                    InspectorAction(id: HooksFrame.copyID, title: HooksFrame.copyTitle, icon: .copy) { state.copyCommand(row, toasts: toasts) },
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            PageEmptyState(icon: .sidebarSimple, text: "Select a row to see its details.")
        }
    }
}

/// The inspector's words, pure for the tests.
enum HooksInspectorFacts {
    /// "PreToolUse · Matcher Bash · Claude Code".
    static func headline(_ row: HooksListRow, cli: CoreRegistryCLI?) -> String {
        var parts = [row.event]
        if let matcher = row.matcher, !matcher.isEmpty { parts.append("Matcher \(matcher)") }
        if let cli { parts.append(cli.name) }
        return parts.joined(separator: " · ")
    }

    /// The mock's order: Runs, Script, Average, Errors, Last run, Added, File, Scope.
    static func facts(_ row: HooksListRow, cli: CoreRegistryCLI?, now: Date) -> [InspectorFact] {
        var facts: [InspectorFact] = []
        let counted = row.row.cells.values.compactMap(\.count)
        let runs = counted.reduce(0, +)
        if counted.isEmpty {
            let logsNone = cli.map { if case .unmeasurable = row.row.cell($0.id) { true } else { false } } ?? false
            facts.append(InspectorFact(key: "Runs", value: logsNone ? "Unmeasurable: \(cli?.name ?? "") logs no Hook runs" : "Unmeasurable"))
        } else {
            facts.append(InspectorFact(key: "Runs", value: NumberWording.count(runs)))
        }
        if row.status == .dead { facts.append(InspectorFact(key: "Script", value: "File is missing")) }
        if let avg = row.row.hooks.compactMap({ $0.usage?.avgMs }).first {
            facts.append(InspectorFact(key: "Average", value: NumberWording.milliseconds(avg)))
        }
        let lifetime = row.row.cells.values.compactMap { cell -> Int? in if case .runs(_, let errors, _, _, _) = cell { errors } else { nil } }.reduce(0, +)
        if lifetime > 0 || (row.errorsLastWeek ?? 0) > 0 {
            let all = "\(NumberWording.count(lifetime)) of \(NumberWording.plural(runs, "run")) in all"
            let week = row.errorsLastWeek.map { "\(NumberWording.count($0)) in 7 days · " } ?? ""
            facts.append(InspectorFact(key: "Errors", value: week + all))
        }
        let last = row.row.cells.values.compactMap { cell -> String? in if case .runs(_, _, let last?, _, _) = cell { last } else { nil } }.max()
        if let last { facts.append(InspectorFact(key: "Last run", value: DayWording.lastRan(daysAgo: HooksListModel.daysAgo(last, now: now)))) }
        if let seen = row.row.firstSeen {
            let added = DayWording.added(secondsAgo: now.timeIntervalSince(seen))
            facts.append(InspectorFact(key: "Added", value: added.hasPrefix("added ") ? String(added.dropFirst("added ".count)) : added))
        }
        // Keys stay unique (the list keys its lines by them): two files of one CLI share one fact.
        let files = Set(row.row.hooks.map(\.file)).sorted().map { ($0 as NSString).abbreviatingWithTildeInPath }
        if !files.isEmpty {
            facts.append(InspectorFact(key: files.count == 1 ? "File" : "Files", value: files.joined(separator: "\n"), isMono: true))
        }
        if case .project(let name) = row.readOnly {
            facts.append(InspectorFact(key: "Scope", value: "Project \(name), read-only here"))
        }
        return facts
    }
}
