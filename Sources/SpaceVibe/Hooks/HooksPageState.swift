import AppKit
import Foundation
import Observation

/// The Hooks page's own state while the frame shows it (AR3): the view state (ticks and filters) and the open `All CLIs` menu.
/// The list, the toolbar and the inspector are separate views the frame places, so they share this one object; there is one
/// per `FrameModel` (`FrameModel.pageState`), made the first time the page draws.
@MainActor
@Observable
final class HooksPageState {
    var view = HooksViewState()
    var isCLIMenuOpen = false

    @ObservationIgnored private weak var model: FrameModel?

    init(model: FrameModel? = nil) {
        self.model = model
    }

    /// The page state of this frame's model.
    static func of(_ model: FrameModel) -> HooksPageState {
        model.pageState(HooksPageState.self) { HooksPageState(model: model) }
    }

    // MARK: View state

    func toggle(_ id: String) { view = view.toggling(id) }
    func toggleAll(_ ids: [String]) { view = view.togglingAll(ids) }
    func filter(event: String?) { view = view.filtering(event: event) }

    /// A node pressed again shows every event.
    func pressNode(_ event: String) { filter(event: view.event == event ? nil : event) }

    func filter(cli: String?) {
        view = view.filtering(cli: cli)
        isCLIMenuOpen = false
    }

    // MARK: Writes

    /// The selected row's `Remove from Claude Code`: at once, with Undo (Hooks never ask).
    func remove(_ row: HooksListRow) {
        guard let model, let write = HooksRemoval.write([row], registry: model.store.snapshot.registry) else { return }
        run(write, removing: [row.id])
    }

    /// `Remove N selected`: the ticked rows shown, as one write and one Undo.
    func removeSelected(_ rows: [HooksListRow]) {
        guard let model, let write = HooksRemoval.write(rows, registry: model.store.snapshot.registry, control: HooksRemoval.selectedControl) else { return }
        run(write, removing: Set(rows.map(\.id)))
    }

    func isPending(_ control: String) -> Bool { model?.writes.isPending(control) ?? false }

    /// `Copy Command`: the whole command to the clipboard. Not a write, so no Undo (the mock's `say('Copied to the clipboard')`);
    /// a command whose credentials the core masked says so (S-R3).
    func copyCommand(_ row: HooksListRow, toasts: ToastCenter) {
        copyToPasteboard(row.command)
        toasts.show(Self.copiedMessage(for: row.command))
    }

    static func copiedMessage(for command: String) -> String { ToastText.copiedCommand(command, plain: copiedToast) }

    /// Puts text on the pasteboard; a test replaces it so it never touches the real one.
    @ObservationIgnored var copyToPasteboard: (String) -> Void = { text in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static let copiedToast = "Copied to the clipboard"

    private func run(_ write: FrameWrite, removing ids: Set<String>) {
        guard let model else { return }
        Task { @MainActor in
            guard await model.writes.perform(write) else { return }
            // The rows are gone: their ticks and the selection on them go too.
            view = HooksViewState(ticked: view.ticked.subtracting(ids), event: view.event, cli: view.cli)
            if let selected = model.router.route.selection, ids.contains(selected) { model.router.select(nil) }
        }
    }
}
