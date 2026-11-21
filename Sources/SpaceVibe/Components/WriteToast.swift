import SwiftUI

/// The toast after a write (DS-R10 "Toast"; RD-R17; the mock's `.toast`), beside v5's `ToastBar`: the ok check, what was done
/// in one sentence that wraps instead of being cut, and Undo beside it, never pushed out of the window (the toast is at most
/// 620 wide and the frame keeps it inside). Undo is absent for the one write that has none (Stop). The frame places it at the
/// bottom centre and times it out (`FrameToastHost`); the block only draws it, and announces the sentence once when it
/// appears (RD-R16), with the action it offers.
struct WriteToast: View {
    let message: String
    /// Nil for a write with no Undo.
    var undo: (() -> Void)?
    /// The button's full verb: Undo after a write; another single action keeps its own (the update reminder's View).
    var actionTitle = ToastText.undoTitle
    /// Undo's arrow; nil for another action.
    var actionIcon: FrameIcon? = .arrowCounterClockwise

    @Environment(\.isShotRendering) private var isShotRendering

    var body: some View {
        HStack(spacing: SpaceRole.step12) {
            FrameGlyph(.checkCircleFill, side: SizeRole.icon16, ink: ColorRole.stateOk)
            Text(message)
                .typeRole(.bodyText)
                .foregroundStyle(ColorRole.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, SpaceRole.step4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let undo {
                Button(action: undo) { PushButtonLabel(actionTitle, icon: actionIcon, size: .small) }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
                    .fixedSize()
            }
        }
        .padding(.leading, SpaceRole.step16)
        .padding(.trailing, SpaceRole.step8)
        .padding(.vertical, SpaceRole.step6)
        .frame(minHeight: BlockRole.toastMinHeight)
        .frame(maxWidth: BlockRole.toastMaxWidth)
        .fixedSize(horizontal: false, vertical: true)
        .overlayPanelSurface()
        .accessibilityElement(children: .contain)
        .onAppear {
            if !isShotRendering { ToastText.announce(ToastText.spoken(message, action: undo == nil ? nil : actionTitle), refused: false) }
        }
    }
}
