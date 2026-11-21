import SwiftUI

extension FramePageContent {
    /// The Clean region (RB-R5): `FrameRegions` hands it the frame's model; a shot passes `fixed` inputs and a prepared page
    /// state. No inspector (RD-R14 retires the static Clean inspector); the toolbar holds Scan Again and the one `Remove …`.
    @MainActor
    static func clean(model: FrameModel, fixed: CleanInputs? = nil, state: CleanPageState? = nil) -> FramePageContent {
        let state = state ?? CleanPageState.of(model)
        let inputs = fixed ?? .live(model.store)
        let page = CleanPage(inputs, ticked: state.ticked, move: inputs.move ?? state.run.snapshot)
        let actions = CleanActions(model: model, state: state, page: page, world: inputs.world)
        let selection = model.router.route.selection
        return FramePageContent(
            help: FramePage.clean.help,
            toolbarControls: AnyView(CleanScanAgainButton(page: page, isMeasuring: inputs.isMeasuring, actions: actions)),
            primary: page.primary == .hidden ? nil : AnyView(CleanRemoveButton(page: page, actions: actions)),
            body: AnyView(CleanList(page: page, selection: selection, state: state, actions: actions, measuresOnOpen: fixed == nil)),
            dialog: state.confirming.map { confirmation in
                FrameDialog(id: "clean.confirm", cancel: actions.cancelConfirmation) {
                    CleanConfirmationDialog(confirmation: confirmation, actions: actions)
                }
            })
    }
}

/// The removal that names its readers first (RD-R11; the mock's `rmConfirm`, only at 3+ CLIs where a file is shared), as the
/// page's dialog over the whole window (RD-R16). Confirming runs the whole selection, logs and caches included.
struct CleanConfirmationDialog: View {
    let confirmation: CleanConfirmation
    let actions: CleanActions

    var body: some View {
        RemoveConfirmation(items: confirmation.items, isWorking: actions.isConfirming, cancel: actions.cancelConfirmation,
                           remove: actions.confirm)
    }
}

/// Scan Again (the mock's `rescan`): `clean.scan` on demand, pending while it reads, disabled while measuring or moving.
struct CleanScanAgainButton: View {
    let page: CleanPage
    let isMeasuring: Bool
    let actions: CleanActions
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        let label = "Scan Again"
        Button { actions.using(toasts).scanAgain() } label: { SpaceVibeIcon(frame: .arrowClockwise, size: .control) }
            .buttonStyle(PushButtonStyle(.icon, isLoading: isMeasuring))
            .focusEffectDisabled()
            .disabled(!page.canScanAgain || isMeasuring)
            .help(label)
            .accessibilityLabel(label)
    }
}

/// The toolbar's `Remove …` (RD-R2, RD-R17 Layout: one width in the slot): the red tint, never primary (RD-R9), the trash
/// glyph, the selected bytes or count; `Measuring…` and `Moving 58%` disabled with their spinner.
struct CleanRemoveButton: View {
    let page: CleanPage
    let actions: CleanActions
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        let title = page.primary.title(narrow: false)
        Button { actions.using(toasts).remove() } label: { PushButtonLabel(title, icon: page.primary.isLoading ? nil : .trash) }
            .buttonStyle(PushButtonStyle(.destructive, isLoading: page.primary.isLoading))
            .focusEffectDisabled()
            .disabled(!page.primary.isEnabled)
            .help(page.primary.isEnabled ? title : page.primary.isLoading ? title : "Select rows to remove")
    }
}
