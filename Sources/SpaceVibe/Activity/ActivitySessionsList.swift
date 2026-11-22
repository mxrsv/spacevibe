import SwiftUI

/// The Sessions tab (the mock's `sessT`): one table on the group surface, its head with the select-all box, then each CLI's
/// rows under a head with the CLI's logo and count (RD-R10: grouped by CLI at any CLI count), waiting first. A row: the
/// checkbox (RD40: Stop is a bulk action; an ended row's box is disabled), the `SessionStateGlyph` of its state (none for an
/// ended row), the title and its quiet line, the current tool and the age when the list is wide, and the selected row's
/// `Stop…` in the fixed action cell, so selecting never moves a column (FE-L1).
struct ActivitySessionsList: View {
    let context: ActivityPageContext
    let data: ActivityPageData
    let isWide: Bool
    @Environment(FrameChrome.self) private var chrome

    var body: some View {
        if data.isSessionsEmpty {
            PageEmptyState(icon: .activity, title: "No CLI sessions live",
                           text: "Start a CLI in a terminal and it appears here within a few seconds.")
        } else {
            // The head is pinned while the rows scroll under it (the mock's sticky `.th`, RowGroup's `head`).
            RowGroup {
                RowTableHead(check: ItemRow<EmptyView, EmptyView>.Check(
                    value: data.headerCheck, label: "Select all shown sessions", toggle: { context.state.toggleAll(data) })) {
                    HStack(spacing: SpaceRole.step12) {
                        Color.clear.frame(width: TableColumnWidth.glyph)
                        Text("Session").frame(maxWidth: .infinity, alignment: .leading)
                        if isWide {
                            Text("Current tool").frame(width: TableColumnWidth.currentTool, alignment: .leading)
                            Text("Age").frame(width: TableColumnWidth.age, alignment: .leading)
                        }
                        Text("Action").frame(width: TableColumnWidth.sessionAction, alignment: .trailing)
                    }
                }
                .disabled(data.stoppableIDs.isEmpty)
            } content: {
                ForEach(data.groups) { group in
                    GroupHead(group.cli.name, count: group.rows.count, cli: group.cli, size: .quiet)
                    ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                        sessionRow(row).rowStripe(index % 2 == 0)
                    }
                }
            }
        }
    }

    private func sessionRow(_ row: ActivitySessionRow) -> some View {
        let isSelected = data.input.selection == row.id
        let actions = context.actions(for: row)
        return ItemRow(label: row.spoken, isSelected: isSelected, isKeyboardFocused: chrome.keyboardRow == row.id, select: {
            context.model.router.select(row.id)
            chrome.pointerSelected()
            chrome.openInspector()
        }) {
            HStack(spacing: SpaceRole.step12) {
                CheckboxCell(row.canStop && data.input.ticked.contains(row.id) ? .on : .off, label: "Select \(row.session.title)") {
                    context.state.toggleTick(row.id)
                }
                .disabled(!row.canStop)
                ActivitySessionGlyph(row: row)
                ItemRowTitle(name: row.session.title, sub: row.subLine)
                    .help([row.session.title, row.subLine].joined(separator: "\n"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isWide {
                    toolCell(row).frame(width: TableColumnWidth.currentTool, alignment: .leading)
                    FigureText(row.ageCell, role: .quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(1)
                        .help(row.inspectorAge)
                        .frame(width: TableColumnWidth.age, alignment: .leading)
                }
                HStack(spacing: SpaceRole.step8) {
                    if isSelected { FrameRowActionButtons(actions: actions) }
                }
                .frame(width: TableColumnWidth.sessionAction, alignment: .trailing)
            }
        }
        .frameRowActions(actions)
        .frameSelectedRowActions(isSelected ? actions : nil)
    }

    @ViewBuilder
    private func toolCell(_ row: ActivitySessionRow) -> some View {
        if let tool = row.tool {
            MiddleTruncatedText(tool)
                .typeRole(.mono)
                .foregroundStyle(ColorRole.ink2)
        } else {
            Text(row.toolPlaceholder)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .lineLimit(1)
        }
    }
}

/// A session's state mark: exactly `SessionStateGlyph` (RD34, GW20: working, waiting and done in their session inks,
/// unmeasurable grey, idle a dot), in the 20 glyph column; an ended row has none (the widget drops it, GW10). The row's
/// spoken label carries the state, and the mark keeps it as a tooltip.
struct ActivitySessionGlyph: View {
    let row: ActivitySessionRow

    var body: some View {
        Group {
            if let state = row.glyph {
                SessionStateGlyph(state: state, size: .control)
            } else {
                Color.clear
            }
        }
        .frame(width: TableColumnWidth.glyph, height: TableColumnWidth.glyph)
        .help(row.stateWord)
        .accessibilityHidden(true)
    }
}
