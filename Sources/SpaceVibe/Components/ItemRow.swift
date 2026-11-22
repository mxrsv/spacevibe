import SwiftUI

/// A row's height (DS-R5): 48 in a table, 60 when its logo toggles wrap to a second line (from 6 CLIs at 5 per line), 44 in
/// a list.
enum ItemRowHeight: Hashable, Sendable {
    case table, tableWrapped, list

    var points: CGFloat {
        switch self {
        case .table: SizeRole.tableRow
        case .tableWrapped: SizeRole.tableRowWrapped
        case .list: SizeRole.listRow
        }
    }
}

/// One row of a list or table in the new frame (DS-R10 "Row"; the mock's `.tr`), beside v5's `ListRow`. Plain, hover
/// (`hoverFill`), selected (`selectionFill`, neutral, never the primary), keyboard focus (the 3 pt bar, RD29) and disabled
/// (.42). Height: 48 in a table, 60 when its logo toggles wrap to a second line, 44 in a list (DS-R5); the content decides
/// nothing about it, so a long name or a warning never moves the rows below (FE-L1).
///
/// - Checkbox: only where the list has a bulk action (RD40), as a `CheckboxCell` in the 28 pt cell at the leading end; the
///   whole cell ticks it, and a click elsewhere selects the row instead. Nothing is ticked at first (RD41).
/// - Actions: a row without `actions` inserts nothing and reserves nothing, selected or not. With `actions`, every row keeps
///   a fixed-width trailing cell (`actionsWidth`), and only the selected row fills it (RD41), so selecting a row never moves
///   a column (FE-L1); a button label that does not fit is cut, the cell never grows. The same actions are menu commands,
///   context-menu items and accessibility actions, because Tab does not enter table cells (RB-T0c, R3): the page hands one
///   `[FrameRowAction]` to `FrameRowActionButtons`, `frameRowActions` and `frameSelectedRowActions`
///   (`Shell/FrameRowActions.swift`).
/// - Selecting is a click on the row or the arrow keys of the list (`listKeyboardSelection`; in the frame `frameListKeys`);
///   it never opens the overlay inspector or starts work (FE-I2).
struct ItemRow<Content: View, Actions: View>: View {
    typealias Height = ItemRowHeight

    /// The row's checkbox, when the list has a bulk action.
    struct Check {
        let value: CheckboxValue
        let label: String
        let toggle: () -> Void
    }

    var height: Height = .table
    var isSelected = false
    /// The arrow keys moved the selection here (draws the focus bar).
    var isKeyboardFocused = false
    var check: Check?
    /// The name VoiceOver reads for the row.
    let label: String
    let select: () -> Void
    /// The trailing actions cell's width on every row; nil: the row has no actions and no cell.
    var actionsWidth: CGFloat?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.specimenInteraction) private var specimen
    @State private var hovering = false

    init(label: String, height: Height = .table, isSelected: Bool = false, isKeyboardFocused: Bool = false,
         check: Check? = nil, actionsWidth: CGFloat = TableColumnWidth.action, select: @escaping () -> Void,
         @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions) {
        self.init(label: label, height: height, isSelected: isSelected, isKeyboardFocused: isKeyboardFocused, check: check,
                  cellWidth: actionsWidth, select: select, content: content(), actions: actions())
    }

    private init(label: String, height: Height, isSelected: Bool, isKeyboardFocused: Bool, check: Check?, cellWidth: CGFloat?,
                 select: @escaping () -> Void, content: Content, actions: Actions) {
        self.label = label
        self.height = height
        self.isSelected = isSelected
        self.isKeyboardFocused = isKeyboardFocused
        self.check = check
        self.actionsWidth = cellWidth
        self.select = select
        self.content = content
        self.actions = actions
    }

    var body: some View {
        let hovered = isEnabled && (hovering || specimen.contains(.hover))
        HStack(spacing: SpaceRole.step12) {
            if let check {
                CheckboxCell(check.value, label: check.label, toggle: check.toggle)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            if let width = ItemRowLayout.actionsCellWidth(actionsWidth) {
                HStack(spacing: SpaceRole.step8) {
                    if ItemRowLayout.fillsActions(isSelected: isSelected) { actions }
                }
                .lineLimit(1)
                .frame(width: width, alignment: .trailing)
            }
        }
        .padding(.horizontal, SpaceRole.step12)
        .frame(maxWidth: .infinity, minHeight: height.points, alignment: .leading)
        .background(Self.fill(selected: isSelected, hovered: hovered))
        .focusBar(FocusBarRule.isShown(ownFocus: isKeyboardFocused, specimen: specimen.contains(.focus)))
        .opacity(isEnabled ? 1 : OpacityRole.disabled)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { select() } }
        .pointerCursor()
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { select() }
    }

    /// Selected wins over hover; a plain row draws no ground.
    static func fill(selected: Bool, hovered: Bool) -> Color {
        selected ? ColorRole.selectionFill : hovered ? ColorRole.hoverFill : .clear
    }
}

extension ItemRow where Actions == EmptyView {
    /// A row with no actions: no trailing cell, so selecting it inserts and spaces nothing.
    init(label: String, height: Height = .table, isSelected: Bool = false, isKeyboardFocused: Bool = false,
         check: Check? = nil, select: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(label: label, height: height, isSelected: isSelected, isKeyboardFocused: isKeyboardFocused, check: check,
                  cellWidth: nil, select: select, content: content(), actions: EmptyView())
    }
}

/// The trailing cell rule of `ItemRow` (FE-L1), pure so the tests read it: the cell's width depends only on whether the row
/// has actions, never on selection; only what fills it does.
enum ItemRowLayout {
    static func actionsCellWidth(_ actionsWidth: CGFloat?) -> CGFloat? { actionsWidth }
    static func fillsActions(isSelected: Bool) -> Bool { isSelected }
}

/// A row's name and its sub-line (the mock's `.nm`): the name in `bodyMedium` `ink` (the mock's `.nm b` at 500), cut in
/// the middle with the full text as its tooltip (RD-R17), and 2 pt under it a quiet sub-line in `ink3` that ends in an
/// ellipsis. An optional category icon leads the name line, inline, in its tone (the mock's `cat-` span, 8 apart); the
/// sub-line starts under the icon, at the cell's leading edge.
struct ItemRowTitle: View {
    let name: String
    var sub: String?
    var icon: FrameIcon?
    var iconInk: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step2) {
            HStack(spacing: SpaceRole.step8) {
                if let icon { FrameGlyph(icon, side: SizeRole.icon16, ink: iconInk ?? ColorRole.ink3) }
                MiddleTruncatedText(name)
                    .typeRole(.bodyMedium)
                    .foregroundStyle(ColorRole.ink)
            }
            if let sub {
                Text(sub)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
