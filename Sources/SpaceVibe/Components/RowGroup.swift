import SwiftUI

/// The fixed column widths of the new frame's tables (the mock's `--cols` on `.th` and `.tr`). A table names its columns here,
/// so a screen holds no number (DS-R3) and a long name or a missing value never moves a column (FE-L1).
enum TableColumn {
    /// The table head's height (`.th`).
    static let headHeight: CGFloat = 30
    /// A state glyph or a kind icon before the name.
    static let glyph: CGFloat = 20
    /// Activity: the open tool call (`220px`).
    static let currentTool: CGFloat = 220
    /// Activity: the session's age (`96px`).
    static let age: CGFloat = 96
    /// The trailing action cell where the selected row's buttons sit (`112px`).
    static let action: CGFloat = 112
    /// Activity › Failures: the failure count (`64px`).
    static let failureCount: CGFloat = 64
    /// Activity › Failures: the selected row's Copy Command (`148px`).
    static let failureAction: CGFloat = 148
    /// The list width from which a table shows its wide columns (the mock's `ctx.wide`, `mw >= 940`).
    static let wideListWidth: CGFloat = 940
}

/// A group of rows on the group surface (DS-R10 "Row" sits inside it; the mock's `.grp`): the group corner of the look, the
/// rows clipped to it, separated by a background step and space, never a divider line (FE-SP5).
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.materialLook) private var look

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorRole.groupSurface)
            .clipShape(CornerRoleShape(RadiusRole.groupCorner(look)))
    }
}

/// A table's head row (the mock's `.th`): 30 high, `quiet` `ink3`, with the same side padding and leading 28 cell as
/// `ItemRow`, so the head's columns stand over the rows' columns. `check` is the select-all box where the table has a bulk
/// action (RD40); `reservesCheckCell` keeps the cell empty when the table has a check column but nothing to tick.
struct RowTableHead<Columns: View>: View {
    var check: ItemRow<EmptyView, EmptyView>.Check?
    var reservesCheckCell = false
    @ViewBuilder var columns: Columns

    init(check: ItemRow<EmptyView, EmptyView>.Check? = nil, reservesCheckCell: Bool = false, @ViewBuilder columns: () -> Columns) {
        self.check = check
        self.reservesCheckCell = reservesCheckCell
        self.columns = columns()
    }

    var body: some View {
        HStack(spacing: SpaceRole.step12) {
            if let check {
                CheckboxCell(check.value, label: check.label, toggle: check.toggle)
            } else if reservesCheckCell {
                Color.clear.frame(width: SizeRole.hitCell, height: SizeRole.hitCell)
            }
            columns
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .typeRole(.quiet)
        .foregroundStyle(ColorRole.ink3)
        .lineLimit(1)
        .padding(.horizontal, SpaceRole.step12)
        .frame(maxWidth: .infinity, minHeight: TableColumn.headHeight, maxHeight: TableColumn.headHeight, alignment: .leading)
    }
}

extension View {
    /// Every other row of a table takes the zebra step (the mock's `.tr:nth-child(odd)`); hover and selection draw above it.
    func rowStripe(_ isStriped: Bool) -> some View {
        background(isStriped ? ColorRole.zebraFill : .clear)
    }
}

/// Rows that stand in for a list still being read (the mock's `skel`): `count` table-height rows, each one bar of a stable,
/// varied width on the hover step. Still, no shimmer loop (DS-R9). Hidden from VoiceOver: the scanning banner above says what
/// is read.
struct SkeletonRows: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<max(0, count), id: \.self) { index in
                GeometryReader { box in
                    RoundedRectangle(cornerRadius: RadiusRole.step6, style: .continuous)
                        .fill(ColorRole.hoverFill)
                        .frame(width: box.size.width * Self.share(index), height: Self.barHeight)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .padding(.horizontal, SpaceRole.step12)
                .frame(height: SizeRole.tableRow)
            }
        }
        .accessibilityHidden(true)
    }

    /// The bar's height (`.sk`).
    static let barHeight: CGFloat = 10

    /// The mock's widths: 46% plus a step of 13 points modulo 40, so the rows differ but never change between renders.
    static func share(_ index: Int) -> CGFloat { CGFloat(46 + (index * 13) % 40) / 100 }
}
