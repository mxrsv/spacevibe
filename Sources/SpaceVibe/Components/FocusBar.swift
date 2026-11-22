import AppKit
import SwiftUI

/// When and where the RD29 focus bar is drawn. Pure, so the tests read the rule.
///
/// A control draws the bar for its own keyboard focus only. `@Environment(\.isFocused)` is not that: it reports the nearest
/// focusable ancestor, and the frame's content area, every list (`listKeyboardSelection`), the overlay inspector and every
/// dialog are focusable, so a block that read it lit with the whole region. A block that wraps its own `Button` binds an own
/// `@FocusState` to that button (`.focused($own)`) and passes the value in. A `ButtonStyle` that every caller applies
/// (`PushButtonStyle`) cannot reach its button, so it keeps `\.isFocused` and trusts it only while macOS keyboard navigation
/// is on: then the button itself is focusable, so it is its own nearest focusable ancestor; with keyboard navigation off no
/// button takes focus, and the value is the region's.
enum FocusBarRule {
    /// The bar shows for the control's own focus, or a gallery specimen's focus state, and never on a disabled control.
    static func isShown(ownFocus: Bool, specimen: Bool = false, isEnabled: Bool = true) -> Bool {
        (ownFocus || specimen) && isEnabled
    }

    /// A button style's own focus from `\.isFocused` (see the type's note).
    static func buttonOwnsFocus(environmentFocus: Bool, keyboardNavigation: Bool) -> Bool {
        environmentFocus && keyboardNavigation
    }

    /// The bar in a control of `size`: 3 pt wide at the leading edge, the full height (the mock's `box-shadow: inset 3px 0 0`).
    /// A rounded control clips it to its own shape, so the bar never sits inside the corner, across the label.
    static func barRect(in size: CGSize) -> CGRect {
        CGRect(x: 0, y: 0, width: SizeRole.focusBar, height: size.height)
    }

    /// Whether macOS gives buttons the keyboard focus (System Settings › Keyboard › Keyboard navigation).
    @MainActor
    static var keyboardNavigation: Bool { NSApplication.shared.isFullKeyboardAccessEnabled }
}

extension View {
    /// Keyboard focus in the new frame (RD29, D57): a 3 pt `ink` bar at the leading edge of the focused row, field or
    /// control, never a ring and never a fill, so it differs from hover and selection and reaches 3:1 on every ground the frame
    /// uses (`ink` on `groupSurface`, `selectionFill`, `hoverFill`, a control fill). `edge` is the control's own corner, which
    /// clips the bar as the mock's inset shadow is clipped; a row passes nil and takes it along its whole height.
    /// `isShown` must come from the control's own focus (`FocusBarRule`), never from `\.isFocused` alone.
    func focusBar(_ isShown: Bool, edge: CornerRole? = nil) -> some View {
        modifier(FocusBarMark(isShown: isShown, edge: edge))
    }

    /// Own focus plus the bar, put on a `Button` from outside (the button stays the one focusable, so Space presses it). The
    /// system focus ring is turned off; a gallery specimen draws the bar through `specimen(.focus)`.
    func focusBarFocusable(edge: CornerRole? = nil) -> some View {
        modifier(FocusBarFocusable(edge: edge))
    }
}

private struct FocusBarMark: ViewModifier {
    let isShown: Bool
    let edge: CornerRole?
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.overlay {
            if FocusBarRule.isShown(ownFocus: isShown, isEnabled: isEnabled) {
                Rectangle()
                    .fill(ColorRole.ink)
                    .frame(width: SizeRole.focusBar)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .clipShape(CornerRoleShape(edge ?? .radius(0)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct FocusBarFocusable: ViewModifier {
    let edge: CornerRole?
    @Environment(\.specimenInteraction) private var specimen
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .focusEffectDisabled()
            .focusBar(FocusBarRule.isShown(ownFocus: focused, specimen: specimen.contains(.focus)), edge: edge)
    }
}
