import SwiftUI

struct ToastBar: View {
    let toast: Toast
    let run: () -> Void

    var body: some View {
        HStack(spacing: Metrics.Toast.spacing) {
            if toast.tone == .danger {
                StateMarkIcon(mark: StateMark(.danger, label: "Error"))
            }
            Text(toast.message).spaceVibeText(.prose, tone: .primary).lineLimit(1)
            if let action = toast.action {
                Button(action: run) {
                    HStack(spacing: Metrics.Toast.actionSpacing) {
                        Text(action.title)
                        if let key = action.keyCap { KeyCap(key) }
                    }
                }
                .buttonStyle(ToastActionStyle())
                .focusEffectDisabled()
            }
        }
        .padding(.leading, Metrics.Toast.leading)
        .padding(.trailing, Metrics.Toast.trailing)
        .frame(height: Metrics.Toast.height)
        .blockSurface(Palette.bgPop, edge: Palette.hair2)
        .overlayShadow(.pop)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(toast.message)
    }
}

/// The toast's action: 24 high, 8 at the sides, 13/20 500 in `accentText`; hovered `hover`, focused `sel`.
private struct ToastActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyledLabel(configuration: configuration) }

    private struct StyledLabel: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isFocused) private var isFocused
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.Radius.control, style: Metrics.Radius.cornerStyle)
            let fill: Color = isFocused || specimen.contains(.focus) || configuration.isPressed ? Palette.sel
                : (hovering || specimen.contains(.hover) ? Palette.hover : .clear)
            configuration.label
                .spaceVibeText(.control)
                .foregroundStyle(Palette.accentText)
                .padding(.horizontal, Metrics.Toast.actionPadding)
                .frame(height: Metrics.Toast.actionHeight)
                .background(shape.fill(fill))
                .focusFill(isFocused || specimen.contains(.focus), cornerRadius: Metrics.Radius.control)
                .contentShape(shape)
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}
