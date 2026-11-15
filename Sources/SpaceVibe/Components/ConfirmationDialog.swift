import SwiftUI

/// The two buttons of a v5 confirmation and the `Tab` cycle between them (V5-R59): the focus starts on Cancel and `Tab`
/// or `Shift-Tab` moves it to the other button, never out of the dialog.
enum ConfirmationFocus: Hashable {
    case cancel, confirm

    static let initial = ConfirmationFocus.cancel

    var next: ConfirmationFocus { self == .cancel ? .confirm : .cancel }
}

/// The v5 confirmation in front of an action that has no Undo (V5-R59, the Stop dialog): the scrim over the window and a
/// 400-wide card centred on it, `bgPop` with a `hair2` edge, the top-edge highlight and the dialog shadow, padding 20 20 16,
/// its parts 8 apart. The title (14/20 600), the message (13/20 `fg2`; a `Text`, so a pid can be bold), the small line
/// (12/16 `fg3`), then 12 below them the actions at the right: `Cancel` with its `esc` cap and the solid danger button. Esc
/// and a click on the scrim cancel, except while the action runs (`isWorking`). The focus start on Cancel and the `Tab`
/// cycle apply where buttons take the keyboard focus (macOS keyboard navigation on); Esc works either way.
struct ConfirmationPanel: View {
    let title: String
    let message: Text
    var note: String?
    let confirmTitle: String
    var confirmGlyph: ContentGlyph?
    var isWorking = false
    let cancel: () -> Void
    let confirm: () -> Void

    @FocusState private var focus: ConfirmationFocus?

    var body: some View {
        ZStack {
            Palette.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if !isWorking { cancel() } }
                .accessibilityHidden(true)
            card
        }
        .onExitCommand { if !isWorking { cancel() } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Metrics.Dialog.spacing) {
            Text(title)
                .spaceVibeText(.dialogTitle, tone: .primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            message
                .spaceVibeText(.prose, tone: .secondary)
                .lineSpacing(SpaceVibeType.prose.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .lineBox(.prose)
            if let note {
                Text(note)
                    .spaceVibeText(.meta, tone: .tertiary)
                    .lineSpacing(SpaceVibeType.meta.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineBox(.meta)
            }
            HStack(spacing: Metrics.Dialog.actionSpacing) {
                Spacer(minLength: 0)
                // Esc reaches Cancel even when no button can take the focus (macOS keyboard navigation off), as
                // `StopSessionPanel` does.
                Button(action: cancel) { ActionLabel("Cancel", key: "esc") }
                    .buttonStyle(ActionButtonStyle())
                    .focused($focus, equals: .cancel)
                    .keyboardShortcut(.cancelAction)
                Button(action: confirm) { ActionLabel(confirmTitle, glyph: confirmGlyph) }
                    .buttonStyle(ActionButtonStyle(kind: .solidDanger))
                    .focused($focus, equals: .confirm)
            }
            .disabled(isWorking)
            .focusEffectDisabled()
            .padding(.top, Metrics.Dialog.actionsAbove)
        }
        .padding(Metrics.Dialog.insets)
        .frame(width: Metrics.Dialog.width)
        .blockSurface(Palette.bgPop, edge: Palette.hair2)
        .overlayShadow(.dialog)
        .onAppear { focus = .initial }
        .onKeyPress(.tab) {
            focus = (focus ?? .initial).next
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(title)
    }
}
