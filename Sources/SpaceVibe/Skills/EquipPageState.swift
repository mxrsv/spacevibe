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

    /// The row's CLIs whose logo or tile has a write running: that CLI's own toggle, or every one of the row while a
    /// shared-file removal of it runs.
    func pendingToggles(_ row: EquipListRow) -> Set<String> {
        let ids = row.toggles.map(\.cli.id)
        if isPending(EquipControl.shared(row.id)) { return Set(ids) }
        return Set(ids.filter { isPending(EquipControl.toggle(row.id, $0)) })
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

    /// A logo or tile pressed: copy, remove, or ask first when another CLI reads the file (RD-R11). Nothing changes on screen
    /// before the core answers (AR4). Returns the write's task (tests wait on it).
    @discardableResult
    func press(_ toggle: CLIToggleState, on row: EquipListRow, from anchor: Anchor) -> Task<Void, Never>? {
        // A second press while the write runs is ignored (the toggle shows it pending).
        guard let model, !pendingToggles(row).contains(toggle.cli.id) else { return nil }
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

    /// The confirmation's `Remove for N CLIs`, or with `copyFirst` its `Copy to …, then remove`: the copy first (its own
    /// Undo), then exactly the members it named, as one removal with one Undo.
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
        return Task { @MainActor in
            let copied = copyFirst ? removal.savable : []
            if !copied.isEmpty {
                guard await model.writes.perform(.copyTo(row.row, targets: copied, registry: registry, control: control)) else { return }
            }
            await model.writes.perform(.removeMembers([row.row], members: removal.members, registry: registry, control: control,
                                                      shared: true, copiedTo: copied))
        }
    }

    // MARK: The per-CLI sheet

    /// `Add to…`, `Remove from…` (the ticked rows), `Remove N selected…` (the same, Remove mode) and an item's `Remove…`.
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

    /// The sheet's confirm. A removal is one `loadout.removeMany` (one Undo); an add is one `loadout.copyTo` per row.
    @discardableResult
    func confirmSheet() -> Task<Void, Never>? {
        guard let model, let current = sheet, !current.ticked.isEmpty else { return nil }
        let list = list()
        let registry = model.store.snapshot.registry
        let order = list.clis.map(\.id)
        let control = EquipControl.sheet(kind.page)
        return Task { @MainActor in
            switch current.mode {
            case .add:
                for step in EquipSheet.additions(current, rows: list.all, order: order) {
                    guard await model.writes.perform(.copyTo(step.row, targets: step.targets, registry: registry, control: control)) else { break }
                }
            case .remove:
                if let removal = EquipSheet.removal(current, rows: list.all) {
                    if !removal.members.isEmpty {
                        await model.writes.perform(.removeMembers(removal.rows, members: removal.members, registry: registry, control: control))
                    }
                } else {
                    for step in EquipSheet.removeFromEach(current, rows: list.all, order: order) {
                        guard await model.writes.perform(.removeFrom(step.row, clis: step.clis, registry: registry, control: control)) else { break }
                    }
                }
            }
            // The rows it acted on leave the selection either way: a refusal said so in its toast.
            view = EquipViewState(filter: view.filter, cli: view.cli, ticked: view.ticked.subtracting(current.rowIDs))
            sheet = nil
        }
    }

    private func run(_ write: FrameWrite) -> Task<Void, Never>? {
        guard let model else { return nil }
        return Task { @MainActor in await model.writes.perform(write) }
    }
}
