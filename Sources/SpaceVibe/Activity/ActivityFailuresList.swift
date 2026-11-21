import SwiftUI

/// The Failures tab (the mock's `failT`): commands and Hooks that failed in a session, most failures first, on one group
/// surface. No checkboxes (RD40: Dismiss acts on one row at a time). A row: the kind icon, the CLI logo and the command (a
/// Hook by the script it runs, RD-R17) cut in the middle, the quiet line (exit, sessions, last day, a later pass, the reason),
/// the count, and the selected row's `Copy Command` in its fixed cell.
struct ActivityFailuresList: View {
    let context: ActivityPageContext
    let data: ActivityPageData
    @Environment(FrameChrome.self) private var chrome
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        if data.failures.isEmpty {
            PageEmptyState(icon: .checkCircleFill, title: "No failed commands",
                           text: "Commands and Hooks that fail in a session land here. A dismissed one comes back if it fails again.")
        } else {
            RowGroup {
                ForEach(Array(data.failures.enumerated()), id: \.element.id) { index, row in
                    failureRow(row).rowStripe(index % 2 == 0)
                }
            }
        }
    }

    private func failureRow(_ row: ActivityFailureRow) -> some View {
        let isSelected = data.input.selection == row.id
        let actions = context.actions(for: row, toasts: toasts)
        return ItemRow(label: row.spoken, isSelected: isSelected, isKeyboardFocused: chrome.keyboardRow == row.id, select: {
            context.model.router.select(row.id)
            chrome.pointerSelected()
            chrome.openInspector()
        }) {
            HStack(spacing: SpaceRole.step12) {
                FrameGlyph(row.icon, side: SizeRole.icon16, ink: ColorRole.ink3)
                    .frame(width: TableColumn.glyph)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: SpaceRole.step8) {
                        CLILogo(CLIIdentity(id: row.failure.cli.rawValue, name: row.cliName), size: SizeRole.logo16)
                        MiddleTruncatedText(row.title)
                            .typeRole(.mono)
                            .foregroundStyle(ColorRole.ink)
                    }
                    Text(row.subLine)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(row.failure.reason)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: row.countText)
                    .typeRole(.pageTitle.figures)
                    .foregroundStyle(ColorRole.ink)
                    .lineLimit(1)
                    .frame(width: TableColumn.failureCount, alignment: .trailing)
                HStack(spacing: SpaceRole.step8) {
                    if isSelected { FrameRowActionButtons(actions: actions) }
                }
                .frame(width: TableColumn.failureAction, alignment: .trailing)
            }
        }
        .frameRowActions(actions)
        .frameSelectedRowActions(isSelected ? actions : nil)
    }
}
