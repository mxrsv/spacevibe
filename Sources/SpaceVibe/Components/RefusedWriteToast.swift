import SwiftUI

/// The toast when the core refused a write (DS-R10 "Toast, refused"; RD-R17; the mock's `.toast.err`): what did not change
/// comes first ("Nothing changed. …", `ToastText.refusedMessage`), at most 3 lines with `Details` for the rest, then the one
/// action that helps (Reload, Show in Finder; for a partial write Undo) and `Dismiss`. It stays until dismissed. A refusal
/// is the critical glyph; a partial write (some moved, some did not) is the attention glyph, because something did change.
/// Announced at high priority (RD-R16).
struct RefusedWriteToast: View {
    let message: String
    var isPartial = false
    /// The one helping action, by its full verb.
    var actionTitle: String?
    var actionIcon: FrameIcon?
    var action: (() -> Void)?
    let dismiss: () -> Void
    var look: MaterialLook = .solid

    @Environment(\.isShotRendering) private var isShotRendering
    @State private var expanded: Bool
    @State private var textWidth: CGFloat = 0

    /// `expanded` opens Details from the start (the gallery's open state).
    init(message: String, isPartial: Bool = false, actionTitle: String? = nil, actionIcon: FrameIcon? = nil,
         action: (() -> Void)? = nil, expanded: Bool = false, look: MaterialLook = .solid, dismiss: @escaping () -> Void) {
        self.message = message
        self.isPartial = isPartial
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.action = action
        self.look = look
        self.dismiss = dismiss
        _expanded = State(initialValue: expanded)
    }

    private var shown: String { ToastText.refusedMessage(message) }

    var body: some View {
        HStack(alignment: .top, spacing: SpaceRole.step12) {
            FrameGlyph(isPartial ? .warningFill : .xCircleFill, side: SizeRole.icon16,
                       ink: isPartial ? ColorRole.stateAttention : ColorRole.stateCritical,
                       label: isPartial ? "Partly done" : "Refused")
                .frame(height: BlockRole.toastMinHeight - 2 * SpaceRole.step8)
            Text(shown)
                .typeRole(.bodyText)
                .foregroundStyle(ColorRole.ink)
                .lineLimit(ToastText.lineLimit(expanded: expanded))
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, SpaceRole.step6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
            HStack(spacing: SpaceRole.step8) {
                if expanded || ToastText.needsDetails(shown, width: textWidth) {
                    Button { expanded.toggle() } label: { Text(expanded ? "Less" : "Details") }
                        .buttonStyle(PushButtonStyle(.quiet, size: .small, look: look))
                        .focusEffectDisabled()
                }
                if let actionTitle, let action {
                    Button(action: action) { PushButtonLabel(actionTitle, icon: actionIcon, size: .small) }
                        .buttonStyle(PushButtonStyle(.control, size: .small, look: look))
                        .focusEffectDisabled()
                }
                Button(action: dismiss) { Text("Dismiss") }
                    .buttonStyle(PushButtonStyle(.quiet, size: .small, look: look))
                    .focusEffectDisabled()
            }
            .fixedSize()
            .frame(minHeight: BlockRole.toastMinHeight - 2 * SpaceRole.step8)
        }
        .padding(.leading, SpaceRole.step16)
        .padding(.trailing, SpaceRole.step8)
        .padding(.vertical, SpaceRole.step8)
        .frame(minHeight: BlockRole.toastMinHeight)
        .frame(maxWidth: BlockRole.toastMaxWidth)
        .fixedSize(horizontal: false, vertical: true)
        .overlayPanelSurface(look: look)
        .overlay {
            PushButtonShape(corner: RadiusRole.popoverCorner(look))
                .strokeBorder(isPartial ? ColorRole.hairline : ColorRole.destructiveTintEdge, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .onAppear { if !isShotRendering { ToastText.announce(shown, refused: true) } }
    }
}
