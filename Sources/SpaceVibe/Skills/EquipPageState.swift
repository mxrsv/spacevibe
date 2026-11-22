import Foundation
import Observation

/// The Skills or Subagents page's own state while the frame shows it (AR3): the view state (filter, CLI pick, ticks), the open
/// menu, legend, sheet and shared-file confirmation, and the writes they start. The list, the toolbar and the inspector are
/// separate views the frame places, so they share this one object: one per page per `FrameModel` (`FrameModel.pageState`),
/// made the first time the page draws.
@MainActor
@Observable
final class EquipPageState {
    /// Where an open shared-file confirmation is anchored: under the row's logo or under the inspector's tile.
    enum Anchor: Equatable, Sendable { case row, tile }

    struct SharedPrompt: Equatable, Sendable {
        let removal: EquipSharedRemoval
        let anchor: Anchor
    }

    let kind: EquipKind
    var view = EquipViewState()
    var isCLIMenuOpen = false
    var isLegendOpen = false
    var sheet: EquipSheetState?
    var shared: SharedPrompt?
    /// The inspector's long description shows in full.
    var isDescriptionExpanded = false

    @ObservationIgnored private weak var model: FrameModel?

    init(kind: EquipKind, model: FrameModel? = nil) {
        self.kind = kind
        self.model = model
    }

    static func of(_ model: FrameModel, kind: EquipKind) -> EquipPageState {
        model.pageState(EquipPageState.self, page: kind.page) { EquipPageState(kind: kind, model: model) }
    }

    // MARK: Reading

    /// The page's derivation now, from the store (observed) and this state.
    func list(now: Date = Date()) -> EquipListModel {
        guard let model else {
            return EquipListModel.make(kind: kind, world: FrameWorld(snapshot: FrameSnapshot(), now: now), loading: [], failed: [],
                                       failure: nil, view: view, now: now)
        }
        return EquipListModel.from(model.store, kind: kind, view: view, query: model.search.query, now: now)
    }

    var router: FrameRouter? { model?.router }
    var search: FrameSearch? { model?.search }
    var store: FrameStore? { model?.store }

    func isPending(_ control: String) -> Bool { model?.writes.isPending(control) ?? false }

    /// The row's CLIs whose logo or tile has a write running: that CLI's own toggle, or every one of the row while another
    /// write of it runs (a shared-file removal, the sheet, or a write started on another page: one busy key per row).
    func pendingToggles(_ row: EquipListRow) -> Set<String> {
        let ids = row.toggles.map(\.cli.id)
        let own = Set(ids.filter { isPending(EquipControl.toggle(row.id, $0)) })
        if own.isEmpty, model?.writes.isRowBusy(row.id) == true { return Set(ids) }
        return own
    }

    // MARK: View state

    func toggle(_ id: String) { view = view.toggling(id) }
    func toggleAll(_ ids: [String]) { view = view.togglingAll(ids) }
    func filter(_ filter: EquipFilter) { view = view.filtering(filter) }

    func scope(_ cli: String?) {
        view = view.scoping(cli)
        isCLIMenuOpen = false
    }

    /// `Select N Suggested` (RD41): shows the Never ran rows first when the page shows all, then ticks the suggested ones the
    /// page now shows; pressed again when all are ticked, it clears them (the mock's `selsug`).
    func selectSuggested() {
        if view.filter == .all { view = view.filtering(.neverRan) }
        toggleAll(list().suggested)
    }

    func select(_ id: String?) {
        if id != router?.route.selection { isDescriptionExpanded = false }
        router?.select(id)
    }

    /// The page closed: no sheet or confirmation waits for it.
    func closeOverlays() {
        sheet = nil
        shared = nil
        isCLIMenuOpen = false
        isLegendOpen = false
    }

    // MARK: Logo toggles and tiles

    /// A write on the row runs: any of its logos or tiles, or a shared-file removal of it.
    func isRowBusy(_ row: EquipListRow) -> Bool { !pendingToggles(row).isEmpty }

    /// A logo or tile pressed: copy, remove, or ask first when another CLI reads the file (RD-R11). Nothing changes on screen
    /// before the core answers (AR4). Returns the write's task (tests wait on it).
    ///
    /// While any write on the row runs, no press on it starts another: two logos turned off quickly would each be judged
    /// against the world before either landed, and together take the last copy without `Remove…` (D53). The press is judged
    /// again from the store's world now (a write's re-read lands before its pending ends), never from the row it was drawn
    /// with. The write's control is pending before this returns, so two presses in one main-actor turn cannot both pass.
    @discardableResult
    func press(_ drawn: CLIToggleState, on drawnRow: EquipListRow, from anchor: Anchor) -> Task<Void, Never>? {
        // An Undo that runs (a toast's, or the Journal window's) may change the row too: wait for it as for a write on it.
        guard let model, !isRowBusy(drawnRow), !model.writes.isUndoing, let row = list().row(drawnRow.id),
              let toggle = row.toggles.first(where: { $0.cli.id == drawn.cli.id }) else { return nil }
        let registry = model.store.snapshot.registry
        let control = EquipControl.toggle(row.id, toggle.cli.id)
        switch EquipToggles.intent(toggle, row: row.row, readers: row.readers) {
        case .none:
            return nil
        case .add(let cli):
            return run(.copyTo(row.row, targets: [cli], registry: registry, control: control))
        case .removeFrom(let cli):
            return run(.removeFrom(row.row, clis: [cli], registry: registry, control: control))
        case .removeMembers(_, let members):
            return run(.removeMembers([row.row], members: members, registry: registry, control: control))
        case .confirm(let removal):
            shared = SharedPrompt(removal: removal, anchor: anchor)
            return nil
        }
    }

    /// The confirmation's `Remove for N CLIs`, or with `copyFirst` its `Copy to …, then remove`: exactly the members it named,
    /// after the copy when there is one, as one press with one toast and one Undo (RD56, `FrameWrite.copyThenRemove`). The
    /// write is pending before this returns, so a second press in the same turn starts nothing.
    @discardableResult
    func confirmShared(copyFirst: Bool) -> Task<Void, Never>? {
        guard let model, let prompt = shared, let row = list().row(prompt.removal.rowID) else {
            shared = nil
            return nil
        }
        shared = nil
        let registry = model.store.snapshot.registry
        let removal = prompt.removal
        let control = EquipControl.shared(row.id)
        let copied = copyFirst ? removal.savable : []
        return run(copied.isEmpty
            ? .removeMembers([row.row], members: removal.members, registry: registry, control: control, shared: true)
            : .copyThenRemove(row.row, copyTo: copied, members: removal.members, registry: registry, control: control))
    }

    // MARK: The per-CLI sheet

    /// `Add to…`, `Remove from…` (the ticked rows), `Remove N…` (the same, Remove mode) and an item's `Remove…`.
    func openSheet(_ mode: PerCLISheetModel.Mode, rows: [String]) {
        guard !rows.isEmpty else { return }
        shared = nil
        sheet = EquipSheetState(mode: mode, rowIDs: rows)
    }

    func sheetToggle(_ cli: String) {
        guard var next = sheet else { return }
        if next.ticked.contains(cli) { next.ticked.remove(cli) } else { next.ticked.insert(cli) }
        sheet = next
    }

    /// The Add to / Remove from switch: the lines mean something else, so the ticks clear.
    func sheetSwitch(_ mode: PerCLISheetModel.Mode) {
        guard let current = sheet else { return }
        sheet = EquipSheetState(mode: mode, rowIDs: current.rowIDs)
    }

    func cancelSheet() {
        guard !isPending(EquipControl.sheet(kind.page)) else { return }
        sheet = nil
    }

    /// The sheet's confirm, as one write with one toast and one Undo (RD56): a removal is one `loadout.removeMany`, or one
    /// `loadout.removeFrom` per row without a readers map; an add is one `loadout.copyTo` per row. The write is pending before
    /// this returns (`FrameWrites.start`), so a second press in the same turn starts nothing; the sheet waits for the answer.
    @discardableResult
    func confirmSheet() -> Task<Void, Never>? {
        guard let model, let current = sheet, !current.ticked.isEmpty else { return nil }
        guard let write = sheetWrite(current) else {
            close(current)
            return nil
        }
        guard let task = model.writes.start(write) else { return nil }
        return Task { @MainActor in
            _ = await task.value
            close(current)
        }
    }

    /// The rows the sheet acted on leave the selection either way (a refusal said so in its toast), and it closes.
    private func close(_ current: EquipSheetState) {
        view = EquipViewState(filter: view.filter, cli: view.cli, ticked: view.ticked.subtracting(current.rowIDs))
        sheet = nil
    }

    /// What the sheet's confirm writes, nil when it would write nothing.
    private func sheetWrite(_ current: EquipSheetState) -> FrameWrite? {
        guard let model else { return nil }
        let list = list()
        let registry = model.store.snapshot.registry
        let order = list.clis.map(\.id)
        let control = EquipControl.sheet(kind.page)
        switch current.mode {
        case .add:
            let steps = EquipSheet.additions(current, rows: list.all, order: order)
            return steps.isEmpty ? nil : .addEach(steps, registry: registry, control: control)
        case .remove:
            if let removal = EquipSheet.removal(current, rows: list.all) {
                return removal.members.isEmpty ? nil : .removeMembers(removal.rows, members: removal.members, registry: registry, control: control)
            }
            let steps = EquipSheet.removeFromEach(current, rows: list.all, order: order)
            return steps.isEmpty ? nil : .removeFromEach(steps, registry: registry, control: control)
        }
    }

    /// The press's write, its control pending at once (`FrameWrites.start`): the row is busy before this returns, so a second
    /// press in the same main-actor turn finds it busy (D53).
    private func run(_ write: FrameWrite) -> Task<Void, Never>? {
        guard let task = model?.writes.start(write) else { return nil }
        return Task { @MainActor in _ = await task.value }
    }
}
