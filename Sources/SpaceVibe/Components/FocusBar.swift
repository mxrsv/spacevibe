import SwiftUI

extension View {
    /// Keyboard focus in the new frame (RD29, D57): a 3 pt `ink` bar inside the leading edge of the focused row, field or
    /// control, never a ring and never a fill, so it differs from hover and selection and reaches 3:1 on every ground the frame
    /// uses (`ink` on `groupSurface`, `selectionFill`, `hoverFill`, a control fill). `inset` keeps the bar clear of a rounded
    /// corner; rows pass 0, capsule controls their corner radius.
    func focusBar(_ isFocused: Bool, inset: CGFloat = 0) -> some View {
        modifier(FocusBarMark(isFocused: isFocused, inset: inset))
    }

    /// Focus state plus the bar, for a control that needs nothing else from its focus. The system focus ring is turned off;
    /// a gallery specimen draws the bar through `specimen(.focus)`.
    func focusBarFocusable(inset: CGFloat = 0) -> some View {
        modifier(FocusBarFocusable(inset: inset))
    }
}

private struct FocusBarMark: ViewModifier {
    let isFocused: Bool
    let inset: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            if isFocused && isEnabled {
                // A row takes the bar along its whole height (the mock's `inset 3px 0 0`); a rounded control keeps it inside.
                RoundedRectangle(cornerRadius: inset == 0 ? 0 : SizeRole.focusBar / 2)
                    .fill(ColorRole.ink)
                    .frame(width: SizeRole.focusBar)
                    .padding(.vertical, inset == 0 ? 0 : SpaceRole.step6)
                    .padding(.leading, inset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct FocusBarFocusable: ViewModifier {
    let inset: CGFloat
    @Environment(\.specimenInteraction) private var specimen
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .focusEffectDisabled()
            .focusBar(focused || specimen.contains(.focus), inset: inset)
    }
}
