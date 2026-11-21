import AppKit
import SwiftUI

/// The Hooks inspector (the mock's `hookInspector`): the Hook's name (the script it runs) with the Hooks icon in its tone, its
/// event, matcher and CLIs, the full command, the facts (runs, a missing script, average time, errors in 7 days and in all,
/// last run, the file, a project's scope) and `Copy Command`. Nothing selected: the empty state (RD41: nothing is
/// pre-selected).
struct HooksInspector: View {
    let model: FrameModel
    let state: HooksPageState

    var body: some View {
        let list = HooksListModel.from(model.store, view: state.view, query: model.search.query)
        if let row = list.row(model.router.route.selection) {
            HooksInspectorBody(row: row, holders: list.holders(of: row), now: Date())
        } else {
            PageEmptyState(icon: .sidebarSimple, text: "Select a row to see its details.")
        }
    }
}

private struct HooksInspectorBody: View {
    let row: HooksListRow
    let holders: [CoreRegistryCLI]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step16) {
            VStack(alignment: .leading, spacing: SpaceRole.step4) {
                HStack(spacing: SpaceRole.step8) {
                    FrameGlyph(.hooks, side: SizeRole.icon20, ink: ColorRole.toneHooks)
                    MiddleTruncatedText(row.label)
                        .typeRole(.pageTitle)
                        .foregroundStyle(ColorRole.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(HooksInspectorFacts.headline(row, holders: holders))
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            InspectorSection("Command") { CommandBlock(row.command) }
            KeyValueList(facts: HooksInspectorFacts.facts(row, holders: holders, now: now))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(row.command, forType: .string)
            } label: {
                PushButtonLabel("Copy Command", icon: .copy, size: .small)
            }
            .buttonStyle(PushButtonStyle(.control, size: .small))
            .focusEffectDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The inspector's words, pure for the tests.
enum HooksInspectorFacts {
    /// "PreToolUse · Matcher Bash · Claude Code".
    static func headline(_ row: HooksListRow, holders: [CoreRegistryCLI]) -> String {
        var parts = [row.event]
        if let matcher = row.matcher, !matcher.isEmpty { parts.append("Matcher \(matcher)") }
        if !holders.isEmpty { parts.append(CLINames.sentence(holders.map(\.name))) }
        return parts.joined(separator: " · ")
    }

    static func facts(_ row: HooksListRow, holders: [CoreRegistryCLI], now: Date) -> [InspectorFact] {
        var facts: [InspectorFact] = []
        let counted = row.row.cells.values.compactMap(\.count)
        let runs = counted.reduce(0, +)
        if counted.isEmpty {
            let names = holders.filter { if case .unmeasurable = row.row.cell($0.id) { true } else { false } }.map(\.name)
            facts.append(InspectorFact(key: "Runs", value: names.isEmpty ? "Unmeasurable" : "Unmeasurable: \(CLINames.sentence(names)) \(names.count == 1 ? "logs" : "log") no Hook runs"))
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
        for file in Set(row.row.hooks.map(\.file)).sorted() {
            facts.append(InspectorFact(key: "File", value: (file as NSString).abbreviatingWithTildeInPath, isMono: true))
        }
        if case .project(let name) = row.readOnly {
            facts.append(InspectorFact(key: "Scope", value: "Project \(name), read-only here"))
        }
        return facts
    }
}
