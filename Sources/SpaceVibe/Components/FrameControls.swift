import SwiftUI

// The controls of the redesign's window frame (RB-S3), from the reference mock's `src/style.css`: the sidebar's page items,
// group heads and Settings foot, the toolbar's icon button (the "icon 32" variant RB-S4's `PushButtonStyle` will replace),
// the page help button, the fixed-width primary slot, the Settings window's pane tabs and the "Not built yet" state. Every
// one that takes a click sets the pointer and shows hover, press, disabled and the 3 pt keyboard focus bar (RD29).

// MARK: - Sidebar

/// A sidebar page item (RD23): the page icon at 20 pt, the label at weight 600 in every state, the page's value at the end.
/// The current page is told apart by fill and ink only; the value is neutral (RD10), with a coloured severity glyph beside it
/// where one is given (RD-R16: glyph and colour, never a dot alone).
struct FrameSidebarItem: View {
    enum Mark: Hashable, Sendable {
        case attention, critical
    }

    let title: String
    let icon: FrameIcon
    /// The category tone of an Agents page's icon (Skills, Subagents, Hooks, Rules); nil keeps the item's ink.
    var iconTone: Color?
    var value: String?
    var mark: Mark?
    let isCurrent: Bool
    /// What VoiceOver reads for the whole item, value included ("Inbox, 11 need you, 2 critical").
    let spokenLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpaceRole.step8) {
                SpaceVibeIcon(frame: icon, size: .row, ink: iconTone)
                Text(title)
                    .typeRole(.sidebarLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if value != nil || mark != nil {
                    HStack(spacing: SpaceRole.step6) {
                        if let value { Text(value).typeRole(.quiet).lineLimit(1) }
                        if let mark { FrameSeverityMark(mark: mark) }
                    }
                    .foregroundStyle(isCurrent ? ColorRole.ink2 : ColorRole.ink3)
                    .fixedSize()
                }
            }
        }
        .buttonStyle(FrameSidebarItemStyle(isCurrent: isCurrent))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

/// A severity glyph at 12 pt in its state colour (FE-C3).
private struct FrameSeverityMark: View {
    let mark: FrameSidebarItem.Mark

    var body: some View {
        switch mark {
        case .attention: SpaceVibeIcon(frame: .warningFill, size: .small, ink: ColorRole.stateAttention)
        case .critical: SpaceVibeIcon(frame: .xCircleFill, size: .small, ink: ColorRole.stateCritical)
        }
    }
}

private struct FrameSidebarItemStyle: ButtonStyle {
    let isCurrent: Bool
    @Environment(\.materialLook) private var look
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        let corner = FrameRole.sidebarItemCorner(look)
        configuration.label
            .foregroundStyle(isCurrent ? ColorRole.ink : ColorRole.ink2)
            .padding(.horizontal, SpaceRole.step10)
            .frame(maxWidth: .infinity, minHeight: FrameRole.sidebarItemHeight(look), alignment: .leading)
            .background(fill(pressed: configuration.isPressed), in: CornerRoleShape(corner))
            .contentShape(CornerRoleShape(corner))
            .frameFocusBar(isFocused)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovered = $0 }
            .pointerCursor()
    }

    private func fill(pressed: Bool) -> Color {
        if isCurrent || pressed { return ColorRole.selectionFill }
        return isHovered ? ColorRole.hoverFill : .clear
    }
}

/// A sidebar group head (Triage, Agents, Watch): quiet medium, ink3 (DS2).
struct FrameSidebarGroupHead: View {
    let title: String

    var body: some View {
        Text(title)
            .typeRole(.quietMedium)
            .foregroundStyle(ColorRole.ink3)
            .padding(.horizontal, SpaceRole.step10)
            .padding(.vertical, SpaceRole.step4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The Settings item at the sidebar's foot: the gear, the label, its shortcut in ink3 (`style.css` `.sbf`).
struct FrameSidebarFootItem: View {
    let title: String
    let shortcutHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpaceRole.step8) {
                SpaceVibeIcon(frame: .gear, size: .row)
                Text(title).typeRole(.sidebarLabel).lineLimit(1)
                Spacer(minLength: 0)
                Text(shortcutHint).typeRole(.quiet).foregroundStyle(ColorRole.ink3).accessibilityHidden(true)
            }
        }
        .buttonStyle(FrameSidebarFootStyle())
        .accessibilityLabel(title)
    }
}

private struct FrameSidebarFootStyle: ButtonStyle {
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ColorRole.ink2)
            .padding(.horizontal, SpaceRole.step10)
            .frame(maxWidth: .infinity, minHeight: SizeRole.controlRegular, alignment: .leading)
            .background(configuration.isPressed ? ColorRole.selectionFill : isHovered ? ColorRole.hoverFill : .clear,
                        in: CornerRoleShape(FrameRole.sidebarFootCorner))
            .contentShape(CornerRoleShape(FrameRole.sidebarFootCorner))
            .frameFocusBar(isFocused)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovered = $0 }
            .pointerCursor()
    }
}

// MARK: - Toolbar

/// A toolbar icon button, the "icon 32" variant (`style.css` `.ctl.ico`): glass in Glass, the control fill with a hairline in
/// Solid; `isOn` shows a pressed toggle (`.ctl.ico.act`, the inspector button). The label is its tooltip and spoken name.
/// RB-S4's `PushButtonStyle` icon variant replaces it once both land.
struct FrameIconButton: View {
    enum Size: Sendable {
        /// 32, the toolbar's.
        case regular
        /// 26, the overlay inspector's close button (`.in.ov .ovx`).
        case small

        var side: CGFloat { self == .regular ? SizeRole.controlRegular : SizeRole.controlSmall }
    }

    let icon: FrameIcon
    let label: String
    var size: Size = .regular
    var isOn: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SpaceVibeIcon(frame: icon, size: .control)
        }
        .buttonStyle(FrameIconButtonStyle(isOn: isOn ?? false, side: size.side))
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn == true ? .isSelected : [])
        .accessibilityValue(isOn.map { $0 ? "On" : "Off" } ?? "")
    }
}

private struct FrameIconButtonStyle: ButtonStyle {
    let isOn: Bool
    let side: CGFloat
    @Environment(\.materialLook) private var look
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        let corner = RadiusRole.controlCorner(look)
        configuration.label
            .foregroundStyle(ColorRole.ink)
            .frame(width: side, height: side)
            .background(fill(pressed: configuration.isPressed), in: CornerRoleShape(corner))
            .frameGlass(in: corner, interactive: true, solid: .clear)
            .overlay {
                if look == .solid { CornerRoleShape(corner).strokeBorder(ColorRole.hairline) }
            }
            .contentShape(CornerRoleShape(corner))
            .frameFocusBar(isFocused)
            .opacity(isEnabled ? 1 : OpacityRole.disabled)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovered = $0 }
            .pointerCursor()
    }

    private func fill(pressed: Bool) -> Color {
        if pressed { return ColorRole.controlPressedFill }
        if isOn || isHovered { return ColorRole.controlHoverFill }
        return look == .solid ? ColorRole.controlFill : .clear
    }
}

/// The page help button beside the title (RD32): a 24 pt `?` with no fill of its own, click only.
struct FrameHelpButton: View {
    let label: String
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SpaceVibeIcon(frame: .question, size: .inline)
        }
        .buttonStyle(FrameHelpButtonStyle(isOpen: isOpen))
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(isOpen ? "Shown" : "Hidden")
    }
}

private struct FrameHelpButtonStyle: ButtonStyle {
    let isOpen: Bool
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ColorRole.ink2)
            .frame(width: SizeRole.minimumHitTarget, height: SizeRole.minimumHitTarget)
            .background(isOpen || isHovered || configuration.isPressed ? ColorRole.hoverFill : .clear,
                        in: CornerRoleShape(.capsule))
            .contentShape(CornerRoleShape(.capsule))
            .frameFocusBar(isFocused)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovered = $0 }
            .pointerCursor()
    }
}

/// The toolbar's primary or destructive button keeps one width whatever its label (RD-R17 Layout, `style.css` `.slot`).
struct FrameToolbarSlot<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: FrameRole.toolbarSlotWidth)
    }
}

// MARK: - Settings window

/// One pane tab of the Settings window (`style.css` `.panes b`): the icon over the name; the open pane by fill, ink and
/// weight 500.
struct FramePaneTab: View {
    let title: String
    let icon: FrameIcon
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpaceRole.step2) {
                SpaceVibeIcon(frame: icon, size: .row)
                Text(title).typeRole(isCurrent ? .quietMedium : .quiet).lineLimit(1)
            }
        }
        .buttonStyle(FramePaneTabStyle(isCurrent: isCurrent))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

private struct FramePaneTabStyle: ButtonStyle {
    let isCurrent: Bool
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        let corner = CornerRole.radius(RadiusRole.step10)
        configuration.label
            .foregroundStyle(isCurrent ? ColorRole.ink : ColorRole.ink2)
            .padding(.vertical, SpaceRole.step6)
            .padding(.horizontal, SpaceRole.step10)
            .frame(minWidth: FrameRole.paneTabMinWidth)
            .background(isCurrent || configuration.isPressed ? ColorRole.selectionFill : isHovered ? ColorRole.hoverFill : .clear,
                        in: CornerRoleShape(corner))
            .contentShape(CornerRoleShape(corner))
            .frameFocusBar(isFocused)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovered = $0 }
            .pointerCursor()
    }
}

// MARK: - States

/// A quiet empty state (`style.css` `.emp`): a 40 pt icon in ink3, the title, one plain sentence. The redesign's regions that
/// are not built yet show it as "Not built yet" (plan, FE-P9 shape); RB-S4's empty state block replaces it.
struct FrameQuietEmptyState: View {
    let icon: FrameIcon
    var title: String?
    let message: String

    var body: some View {
        VStack(spacing: SpaceRole.step12) {
            SpaceVibeIcon(frame: icon, size: .row)
                .scaleEffect(SizeRole.icon40 / SizeRole.icon20)
                .frame(width: SizeRole.icon40, height: SizeRole.icon40)
                .foregroundStyle(ColorRole.ink3)
            if let title { Text(title).typeRole(.pageTitle).foregroundStyle(ColorRole.ink) }
            Text(message)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .multilineTextAlignment(.center)
        }
        .padding(.top, SpaceRole.emptyStateTop)
        .padding(.horizontal, SpaceRole.step24)
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Keyboard focus (RD29)

extension View {
    /// The keyboard focus mark (RD29): a 3 pt ink bar inside the control's leading edge, not a ring (D57), distinct from hover
    /// and selection. RB-S4's rows use the same bar.
    func frameFocusBar(_ isFocused: Bool) -> some View {
        overlay(alignment: .leading) {
            if isFocused {
                Rectangle()
                    .fill(ColorRole.ink)
                    .frame(width: SizeRole.focusBar)
                    .padding(.vertical, SpaceRole.step4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
