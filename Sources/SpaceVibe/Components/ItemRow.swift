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
/// - Actions: the selected row shows its action buttons (`actions`) at the trailing end; other rows do not (RD41). The same
///   actions are menu commands, context-menu items and accessibility actions, because Tab does not enter table cells (RB-T0c,
///   R3): a frame page draws its rows with `FrameItemRow` (`Shell/FrameRowActions.swift`), which fills `actions` and those
///   three places from one list.
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
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.specimenInteraction) private var specimen
    @State private var hovering = false

    init(label: String, height: Height = .table, isSelected: Bool = false, isKeyboardFocused: Bool = false,
         check: Check? = nil, select: @escaping () -> Void, @ViewBuilder content: () -> Content,
         @ViewBuilder actions: () -> Actions) {
        self.label = label
        self.height = height
        self.isSelected = isSelected
        self.isKeyboardFocused = isKeyboardFocused
        self.check = check
        self.select = select
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        let hovered = isEnabled && (hovering || specimen.contains(.hover))
        HStack(spacing: SpaceRole.step12) {
            if let check {
                CheckboxCell(check.value, label: check.label, toggle: check.toggle)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            if isSelected {
                HStack(spacing: SpaceRole.step8) { actions }
                    .fixedSize()
            }
        }
        .padding(.horizontal, SpaceRole.step12)
        .frame(maxWidth: .infinity, minHeight: height.points, alignment: .leading)
        .background(Self.fill(selected: isSelected, hovered: hovered))
        .focusBar(isKeyboardFocused || specimen.contains(.focus))
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
    init(label: String, height: Height = .table, isSelected: Bool = false, isKeyboardFocused: Bool = false,
         check: Check? = nil, select: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(label: label, height: height, isSelected: isSelected, isKeyboardFocused: isKeyboardFocused, check: check,
                  select: select, content: content) { EmptyView() }
    }
}

/// A row's name and its sub-line (the mock's `.nm`): the name in `bodyText` `ink`, cut in the middle with the full text as
/// its tooltip (RD-R17), and a quiet sub-line in `ink3` that ends in an ellipsis. An optional category icon leads in its tone.
struct ItemRowTitle: View {
    let name: String
    var sub: String?
    var icon: FrameIcon?
    var iconInk: Color?

    var body: some View {
        HStack(spacing: SpaceRole.step10) {
            if let icon { FrameGlyph(icon, side: SizeRole.icon16, ink: iconInk ?? ColorRole.ink3) }
            VStack(alignment: .leading, spacing: 0) {
                MiddleTruncatedText(name)
                    .typeRole(.bodyText)
                    .foregroundStyle(ColorRole.ink)
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
}
