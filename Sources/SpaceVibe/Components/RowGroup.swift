import SwiftUI

/// A group of rows on the group surface (DS-R10 "Row" sits inside it; the mock's `.grp`): the one block every list, table and
/// skeleton stacks its rows in, top to bottom with no gap, full width, on `groupSurface()`. A padded card is `GroupCard`.
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupSurface()
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
        .frame(maxWidth: .infinity, minHeight: TableColumnWidth.headerHeight, maxHeight: TableColumnWidth.headerHeight, alignment: .leading)
    }
}

extension View {
    /// Every other row of a table takes the zebra step (the mock's `.tr:nth-child(odd)`); hover and selection draw above it.
    func rowStripe(_ isStriped: Bool) -> some View {
        background(isStriped ? ColorRole.zebraFill : .clear)
    }
}
