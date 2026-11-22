import SwiftUI

/// A checkbox's value: ticked, not ticked, or partly (a header checkbox over rows of which only some are ticked).
enum CheckboxValue: Hashable, Sendable {
    case on, off, mixed

    /// What VoiceOver reads as the value.
    var spoken: String {
        switch self {
        case .on: "checked"
        case .off: "not checked"
        case .mixed: "partly checked"
        }
    }

    /// Pressing a mixed box ticks everything; an on box clears.
    var next: CheckboxValue { self == .on ? .off : .on }

    /// The header checkbox for `ticked` of `total` rows shown.
    static func header(ticked: Int, total: Int) -> CheckboxValue {
        guard total > 0, ticked > 0 else { return .off }
        return ticked >= total ? .on : .mixed
    }
}

/// The new frame's checkbox (DS-R10; the mock's `.cbw` and `.cb`): a 16 pt box inside a 28 pt cell, and the whole cell takes the
/// click (RD-R16). Off: a 1.4 pt `ink3` edge that turns `ink` on hover. On and mixed: the primary fill with a white check or
/// dash (RD-R9: the checkbox on-state is one of the primary's uses). Disabled at the disabled opacity (RD49). Lists draw it only where a
/// bulk action exists (RD40), and nothing is ticked at first (RD41).
struct CheckboxCell: View {
    let value: CheckboxValue
    let label: String
    let toggle: () -> Void
    /// The button's own keyboard focus (RD29): never the list's or the dialog's around it (`FocusBarRule`).
    @FocusState private var focused: Bool

    init(_ value: CheckboxValue, label: String, toggle: @escaping () -> Void) {
        self.value = value
        self.label = label
        self.toggle = toggle
    }

    var body: some View {
        Button(action: toggle) { EmptyView() }
            .buttonStyle(CheckboxCellStyle(value: value, isFocused: focused))
            .focused($focused)
            .focusEffectDisabled()
            .accessibilityLabel(label)
            .accessibilityValue(value.spoken)
            .accessibilityAddTraits(.isToggle)
    }
}

private struct CheckboxCellStyle: ButtonStyle {
    let value: CheckboxValue
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        BoxBody(configuration: configuration, value: value, isFocused: isFocused)
    }

    private struct BoxBody: View {
        let configuration: ButtonStyle.Configuration
        let value: CheckboxValue
        let isFocused: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let hovered = isEnabled && (hovering || specimen.contains(.hover))
            let box = RoundedRectangle(cornerRadius: RadiusRole.step4, style: .continuous)
            ZStack {
                if value == .off {
                    box.strokeBorder(hovered ? ColorRole.ink : ColorRole.ink3, lineWidth: StrokeRole.checkboxEdge)
                } else {
                    box.fill(configuration.isPressed ? ColorRole.primaryActionPressed : ColorRole.primaryAction)
                    SpaceVibeIcon(frame: value == .on ? .check : .minus, size: .small, ink: ColorRole.onPrimaryAction)
                }
            }
            .frame(width: SizeRole.icon16, height: SizeRole.icon16)
            .opacity(isEnabled ? 1 : OpacityRole.disabled)
            .frame(width: SizeRole.hitCell, height: SizeRole.hitCell)
            .contentShape(Rectangle())
            .focusBar(FocusBarRule.isShown(ownFocus: isFocused, specimen: specimen.contains(.focus)))
            .pointerCursor()
            .onHover { hovering = $0 }
        }
    }
}
