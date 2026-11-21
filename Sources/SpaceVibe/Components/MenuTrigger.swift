import SwiftUI

/// The button that opens a pick menu (the mock's `.ctl` with `aria-haspopup`): a control button with an optional lead (the
/// chosen CLI's logo, the folder icon), the title cut in the middle, and the caret. Pressed while open. The page owns
/// `isOpen` and anchors the `MenuPanel` to this button with `anchoredOverlay(isPresented:id:placement: .menu(.leading),
/// onOutsideTap:)`, so an outside click and Esc close it.
struct MenuTrigger: View {
    let title: String
    var lead: MenuPanelEntry.Lead = .none
    let isOpen: Bool
    /// What the menu chooses, for VoiceOver ("CLIs shown", "CLI", "Project").
    let label: String
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: SpaceRole.step6) {
                switch lead {
                case .none: EmptyView()
                case .cli(let cli): CLILogo(cli, size: SizeRole.logo16)
                case .icon(let icon): FrameGlyph(icon, side: SizeRole.icon14)
                }
                MiddleTruncatedText(title)
                FrameGlyph(.caretDown, side: SizeRole.icon12, ink: ColorRole.ink3)
            }
        }
        .buttonStyle(PushButtonStyle(.control, isActive: isOpen))
        .focusEffectDisabled()
        .accessibilityLabel(label)
        .accessibilityValue(title)
        .accessibilityHint(isOpen ? "Menu open" : "Opens a menu")
    }
}
