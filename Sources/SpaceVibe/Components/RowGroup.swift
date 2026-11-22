import SwiftUI

/// A group of rows on the group surface (DS-R10 "Row" sits inside it; the mock's `.grp`): the one block every list, table and
/// skeleton stacks its rows in, top to bottom with no gap, full width, on `groupSurface()`. A padded card is `GroupCard`.
///
/// A table gives its head row as `head` (a `RowTableHead` or the page's own): the head is pinned while its rows scroll under
/// it, on the group's ground, until the group itself leaves the screen (the mock's `.grp>.th{position:sticky}`). Pinning
/// needs the group inside the page's `SpaceVibeScrollView`; the head sticks at the scroll view's top edge, below the toolbar's
/// clearance. A headless shot has no scroll view, so it draws the same rows in a plain stack.
struct RowGroup<Head: View, Content: View>: View {
    @ViewBuilder var head: Head
    @ViewBuilder var content: Content
    @Environment(\.isShotRendering) private var isShotRendering

    /// A table: `head` pinned over the rows.
    init(@ViewBuilder head: () -> Head, @ViewBuilder content: () -> Content) {
        self.head = head()
        self.content = content()
    }

    var body: some View {
        Group {
            if Self.pinsHead(hasHead: Head.self != EmptyView.self, isShotRendering: isShotRendering) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        content
                    } header: {
                        head.background(ColorRole.groupSurface)
                    }
                }
            } else if Self.isLazy(isShotRendering: isShotRendering) {
                // Rows are built as they scroll in, so a list of 1,000 Clean or Inbox rows never builds them all at once.
                LazyVStack(alignment: .leading, spacing: 0) {
                    head
                    content
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    head
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupSurface()
    }

    /// Only a group with a head pins it, and never in a headless shot (no scroll view there). Pure, so it is tested.
    static func pinsHead(hasHead: Bool, isShotRendering: Bool) -> Bool { hasHead && !isShotRendering }

    /// Every group builds its rows lazily inside the page's scroll view; a headless shot (no scroll view) draws them all.
    static func isLazy(isShotRendering: Bool) -> Bool { !isShotRendering }
}

extension RowGroup where Head == EmptyView {
    /// A list without a head row.
    init(@ViewBuilder content: () -> Content) {
        self.init(head: { EmptyView() }, content: content)
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
