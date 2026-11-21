import SwiftUI

/// The new frame's buttons (DS-R10, DS-R11; the mock's `.pri`, `.ctl`, `.rb`, `.rb.q`, `.dst`, `.rb.d`), beside v5's
/// `ActionButtonStyle`. One primary per surface; destructive is a red tint, never a solid red fill; Cancel and secondary
/// actions stay quiet (FE-E2). Every state: hover, pressed, disabled (.42), loading (a still ring, no loop, DS-R9), keyboard
/// focus as the 3 pt bar (RD29), the pointing hand, and the whole button as the hit area. The caller adds
/// `.focusEffectDisabled()` so the system ring never shows (D57).
///
///     Button(action: undo) { PushButtonLabel("Undo", icon: .arrowCounterClockwise) }
///         .buttonStyle(PushButtonStyle(.control, size: .small))
struct PushButtonStyle: ButtonStyle {
    enum Kind: Hashable, Sendable {
        /// The one blue action of a surface.
        case primary
        /// A neutral control fill with a hairline edge.
        case control
        /// A square icon-only control (give the label an accessible name).
        case icon
        /// No fill until hovered, `ink3` text at 400: Cancel beside a destructive action, Dismiss, Details.
        case quiet
        /// Link-coloured, no fill: the group head's `Select N Suggested`.
        case link
        /// The red tint for an undoable removal.
        case destructive
    }

    enum Size: Hashable, Sendable {
        /// 32 high, `bodyMedium`: toolbars, dialogs, toasts.
        case regular
        /// 26 high, `quietMedium`: rows, group heads, the inspector.
        case small

        var height: CGFloat { self == .regular ? SizeRole.controlRegular : SizeRole.controlSmall }
    }

    let kind: Kind
    var size: Size = .regular
    var isLoading = false
    /// Drawn as hovered while what it opens is open (a menu's button, the inspector toggle: the mock's `.act`).
    var isActive = false

    /// The look (Glass rounds controls to a capsule and puts the 32 controls on glass) comes from the frame's
    /// `\.materialLook` (AR8), never from the caller.
    init(_ kind: Kind, size: Size = .regular, isLoading: Bool = false, isActive: Bool = false) {
        self.kind = kind
        self.size = size
        self.isLoading = isLoading
        self.isActive = isActive
    }

    /// Whether the button sits on the system glass in `look`: the mock's `.ctl` (a 32 control) and `.ctl.ico` at 32 and 26
    /// (the toolbar's icons, the overlay inspector's close). Row buttons (`.rb`), primary and destructive keep their fills.
    func isOnGlass(_ look: MaterialLook) -> Bool {
        look == .glass && (kind == .icon || (kind == .control && size == .regular))
    }

    func makeBody(configuration: Configuration) -> some View {
        PushButtonBody(configuration: configuration, style: self)
    }

    /// The label's type role.
    var typeRole: TypeRole {
        switch kind {
        case .quiet, .link: size == .regular ? .bodyText : .quiet
        default: size == .regular ? .bodyMedium : .quietMedium
        }
    }

    /// Side padding (the mock: 16 for primary and destructive at 32, 10 elsewhere; 0 for an icon button).
    var sidePadding: CGFloat {
        switch kind {
        case .icon: 0
        case .primary, .destructive: size == .regular ? SpaceRole.step16 : SpaceRole.step10
        default: SpaceRole.step10
        }
    }

    /// The ground for a state; nil draws none. On glass a control has no resting fill: the glass is its ground, and hover
    /// and press tint it (the mock's `.ctl:hover`, `.ctl.ico.act`).
    func fill(hovered: Bool, pressed: Bool, enabled: Bool, onGlass: Bool = false) -> Color? {
        if onGlass {
            guard enabled else { return nil }
            return pressed ? ColorRole.controlPressedFill : hovered ? ColorRole.controlHoverFill : nil
        }
        guard enabled else { return kind == .quiet || kind == .link ? nil : kind == .primary ? ColorRole.primaryAction : ColorRole.controlFill }
        switch kind {
        case .primary:
            return pressed ? ColorRole.primaryActionPressed : hovered ? ColorRole.primaryActionHover : ColorRole.primaryAction
        case .control, .icon:
            return pressed ? ColorRole.controlPressedFill : hovered ? ColorRole.controlHoverFill : ColorRole.controlFill
        case .quiet:
            return pressed ? ColorRole.selectionFill : hovered ? ColorRole.hoverFill : nil
        case .link:
            return nil
        case .destructive:
            return pressed ? ColorRole.destructiveTintPressed : hovered ? ColorRole.destructiveTintHover : ColorRole.destructiveTint
        }
    }

    func ink(hovered: Bool, enabled: Bool) -> Color {
        switch kind {
        case .primary: ColorRole.onPrimaryAction
        case .control, .icon: ColorRole.ink
        case .quiet: hovered && enabled ? ColorRole.ink : ColorRole.ink3
        case .link: ColorRole.link
        case .destructive: enabled ? ColorRole.criticalInk : ColorRole.ink3
        }
    }

    /// The 1 pt edge: a hairline on control fills, the red edge on the destructive tint, none on glass (the glass draws its
    /// own rim), elsewhere or when disabled.
    func edge(enabled: Bool, onGlass: Bool = false) -> Color? {
        guard !onGlass else { return nil }
        switch kind {
        case .control, .icon: return ColorRole.hairline
        case .destructive: return enabled ? ColorRole.destructiveTintEdge : nil
        default: return nil
        }
    }
}

private struct PushButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let style: PushButtonStyle

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.specimenInteraction) private var specimen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.materialLook) private var look
    @State private var hovering = false

    var body: some View {
        let enabled = isEnabled && !style.isLoading
        let hovered = enabled && (hovering || style.isActive || specimen.contains(.hover))
        let pressed = enabled && (configuration.isPressed || specimen.contains(.press))
        let corner = RadiusRole.controlCorner(look)
        let shape = CornerRoleShape(corner)
        let onGlass = style.isOnGlass(look)
        HStack(spacing: style.kind == .primary || style.kind == .destructive ? SpaceRole.step8 : SpaceRole.step6) {
            if style.isLoading { PendingMark(onPrimary: style.kind == .primary) }
            configuration.label
        }
        .typeRole(style.typeRole)
        .lineLimit(1)
        .foregroundStyle(style.ink(hovered: hovered, enabled: isEnabled))
        .padding(.horizontal, style.sidePadding)
        .frame(minWidth: style.size.height, minHeight: style.size.height, maxHeight: style.size.height)
        .background {
            if let fill = style.fill(hovered: hovered, pressed: pressed, enabled: isEnabled, onGlass: onGlass) { shape.fill(fill) }
        }
        .frameGlass(in: corner, interactive: true, solid: .clear, when: onGlass)
        .overlay {
            if let edge = style.edge(enabled: isEnabled, onGlass: onGlass) { shape.strokeBorder(edge, lineWidth: 1) }
        }
        .opacity(isEnabled ? 1 : OpacityRole.disabled)
        .scaleEffect(MotionRole.scale(pressed: pressed, reduceMotion: reduceMotion))
        .contentShape(shape)
        .focusBar(isFocused || specimen.contains(.focus), inset: corner == .capsule ? style.size.height / 2 : SpaceRole.step2)
        .pointerCursor()
        .onHover { hovering = $0 }
        .accessibilityAddTraits(style.isLoading ? .updatesFrequently : [])
    }
}

/// Loading: the mock's `.spin`, a ring with its top quarter in the label's ink. Still (no loop, DS-R9). The one pending mark:
/// a loading button and a logo toggle or tile whose write runs draw it.
struct PendingMark: View {
    var onPrimary = false

    var body: some View {
        ZStack {
            Circle().stroke(onPrimary ? ColorRole.onPrimaryAction.opacity(OpacityRole.disabled) : ColorRole.ink3, lineWidth: SpaceRole.step2)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(onPrimary ? ColorRole.onPrimaryAction : ColorRole.ink, style: StrokeStyle(lineWidth: SpaceRole.step2, lineCap: .round))
                .rotationEffect(.degrees(-135))
        }
        .frame(width: SizeRole.icon12, height: SizeRole.icon12)
        .accessibilityHidden(true)
    }
}

/// A button's label: an optional icon (16 at regular, 12 at small) and the full-verb title.
struct PushButtonLabel: View {
    let title: String
    var icon: FrameIcon?
    var size: PushButtonStyle.Size = .regular

    init(_ title: String, icon: FrameIcon? = nil, size: PushButtonStyle.Size = .regular) {
        self.title = title
        self.icon = icon
        self.size = size
    }

    var body: some View {
        HStack(spacing: SpaceRole.step6) {
            if let icon { SpaceVibeIcon(frame: icon, size: size == .regular ? .control : .small) }
            Text(title)
        }
    }
}
