import SwiftUI

/// The columns of an Inbox row (the reference mock's `fcols`, `28px 20px minmax(0,1fr) 168px 172px`, and its RB-M2 evidence
/// column): the checkbox cell, the kind glyph, the name over its quiet line, the short evidence, and the actions. The
/// evidence and action columns keep fixed widths, so a long name, a short one or the selected row's buttons never move the
/// columns of the rows below (FE-L1). Pure, so the tests read the rule.
enum FindingRowLayout {
    /// The evidence column (`168px`): the tables' status width.
    static let evidenceWidth = TableColumnWidth.status
    /// The action column (`172px`), fixed: wider buttons reach left over the evidence cell instead of growing it.
    static let actionsWidth = TableColumnWidth.action
    /// Below this list width the evidence column is left out (the mock's `mw >= 700`), so the name keeps its room.
    static let evidenceFromListWidth: CGFloat = 700

    static func showsEvidence(listWidth: CGFloat) -> Bool { listWidth >= evidenceFromListWidth }
}

/// One Inbox row's content inside an `ItemRow` (DS-R10 "Row"; the mock's `.tr` on the Inbox): the kind glyph (grey, or the
/// waiting session's ink, RD10), the name cut in the middle with its full text as the tooltip (RD-R17; in mono for a Hook's
/// script or a Rule), the quiet line, the evidence in `ink2`, and the action column, which shows the selected row's buttons
/// (RD41). A row without a checkbox keeps the empty 28 pt cell, so glyphs line up with the rows that have one.
struct FindingRowContent<Actions: View>: View {
    let icon: FrameIcon
    var iconInk: Color = ColorRole.ink3
    let title: String
    var isMono = false
    let sub: String
    /// Nil leaves the evidence column out (a narrow list).
    var evidence: String?
    /// The row has no checkbox: keep its cell empty.
    var reservesCheckCell = false
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: SpaceRole.step12) {
            if reservesCheckCell {
                Spacer(minLength: 0).frame(width: SizeRole.hitCell)
            }
            FrameGlyph(icon, side: SizeRole.icon16, ink: iconInk)
                .frame(width: SizeRole.icon20)
            // The mock's `.nm` gap: 2 between the name and its quiet line.
            VStack(alignment: .leading, spacing: SpaceRole.step2) {
                MiddleTruncatedText(title)
                    .typeRole(isMono ? .mono : .bodyMedium)
                    .foregroundStyle(ColorRole.ink)
                Text(sub)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let evidence {
                Text(evidence)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(evidence)
                    .frame(width: FindingRowLayout.evidenceWidth, alignment: .leading)
            }
            // One width on every row, buttons or not, so no column moves (FE-L1). Wider buttons keep their whole labels and
            // reach left over the evidence cell, as the mock's `.act` (flex-end in a 172 px cell) does.
            HStack(spacing: SpaceRole.step8) { actions }
                .lineLimit(1)
                .fixedSize()
                .frame(width: FindingRowLayout.actionsWidth, alignment: .trailing)
        }
    }
}
