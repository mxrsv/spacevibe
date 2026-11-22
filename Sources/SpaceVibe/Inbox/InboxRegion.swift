import AppKit
import Observation
import SwiftUI

/// The Inbox's own view state (AR3: never in the store): the ticked rows, whether kept findings are listed and the removal
/// waiting for its confirmation. Nothing is ticked at first (RD41). One per `FrameModel` (`FrameModel.pageState`).
@MainActor
@Observable
final class InboxPageState {
    var ticked: Set<String> = []
    var showsKept = false
    var confirming: InboxConfirmation?

    static func of(_ model: FrameModel) -> InboxPageState {
        model.pageState(InboxPageState.self) { InboxPageState() }
    }

    func toggleTick(_ id: String) {
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    /// The head's pick: ticks every suggested row of the group, or clears them when all are ticked (the mock's `selsug`).
    func pickSuggested(_ ids: [String]) {
        if !ids.isEmpty, ids.allSatisfy(ticked.contains) { ticked.subtract(ids) } else { ticked.formUnion(ids) }
    }
}

/// A removal that names its readers before it writes (RD-R11 "every other removal path names the readers too"): the
/// confirmation's lines and the write it runs.
struct InboxConfirmation {
    let items: [RemoveConfirmation.Item]
    let write: FrameWrite
    /// The rows it removes, unticked once it lands.
    let rowIDs: [String]
    /// `FrameRouter.revision` when it opened: a route changed from outside since (the glance widget) closes it, so it never
    /// comes back over another page or selection.
    var routeRevision = 0
}

/// What the Inbox reads: the store's world and its state for the page, or a fixed set for a shot.
struct InboxInputs {
    let world: FrameWorld
    let figure: PageFigure
    var failure: String?
    let now: Date
    /// A shot's selection; nil reads the route.
    var selection: String?

    @MainActor
    static func live(_ store: FrameStore, now: Date = Date()) -> InboxInputs {
        let world = store.world(now: now)
        let failed = store.failedEmpty
        let failure = failed.compactMap { source -> String? in
            if case .failed(let sentence) = store.states[source] { return sentence }
            return nil
        }.first
        return InboxInputs(world: world, figure: world.figure(for: .inbox, loading: store.loading, failed: failed), failure: failure, now: now)
    }
}

/// How a waiting session's app is found and brought forward (RD36): the shipped `HostAppResolver` (GW5), which starts no
/// process and needs no Automation permission. A shot or test passes its own.
@MainActor
struct InboxHost {
    var hostApp: (Int) -> HostApp?
    var activate: (HostApp) -> Bool

    static let live = InboxHost(
        hostApp: { pid in pid_t(exactly: pid).flatMap { HostAppResolver.hostApp(of: $0) } },
        activate: { HostAppResolver.activate($0) })
}

extension FramePageContent {
    /// The Inbox region (RB-R1): `FrameRegions` hands it the frame's model; a shot passes `fixed` inputs, its own host and a
    /// prepared page state.
    @MainActor
    static func inbox(model: FrameModel, fixed: InboxInputs? = nil, host: InboxHost? = nil, state: InboxPageState? = nil) -> FramePageContent {
        let host = host ?? .live
        let state = state ?? InboxPageState.of(model)
        let inputs = fixed ?? .live(model.store)
        let page = InboxPage(world: inputs.world, figure: inputs.figure, failure: inputs.failure, ticked: state.ticked,
                             showsKept: state.showsKept, hasHost: { host.hostApp($0) != nil }, query: model.search.query,
                             now: inputs.now)
        let selection = fixed == nil ? model.router.route.selection : inputs.selection
        var actions = InboxActions(model: model, state: state, page: page, world: inputs.world, host: host)
        if fixed == nil { actions.liveWorld = { model.store.world() } }
        let selected = page.row(selection)
        return FramePageContent(
            help: FramePage.inbox.help,
            searchItems: InboxPage.searchItems,
            primary: page.primary == .hidden ? nil : AnyView(InboxRemoveButton(page: page, actions: actions)),
            body: AnyView(InboxList(page: page, selection: selection, state: state, actions: actions)),
            inspector: AnyView(InboxInspector(row: selected, world: inputs.world, now: inputs.now, actions: actions,
                                              hasRows: !page.rows.isEmpty || !page.kept.isEmpty)),
            overlayActions: selected.map { AnyView(InboxOverlayActions(row: $0, actions: actions)) },
            dialog: state.confirming.flatMap { $0.routeRevision == model.router.revision ? $0 : nil }.map { confirmation in
                FrameDialog(id: "inbox.confirm", cancel: actions.cancelConfirmation) {
                    InboxConfirmationDialog(confirmation: confirmation, actions: actions)
                }
            })
    }
}

/// The removal that names its readers first (RD-R11), as the page's dialog over the whole window (RD-R16).
struct InboxConfirmationDialog: View {
    let confirmation: InboxConfirmation
    let actions: InboxActions

    var body: some View {
        RemoveConfirmation(items: confirmation.items, isWorking: actions.isConfirming, cancel: actions.cancelConfirmation,
                           remove: actions.confirm)
    }
}

/// Every press on the Inbox, through the one write path (AR4) or the route (AR5).
@MainActor
struct InboxActions {
    let model: FrameModel
    let state: InboxPageState
    let page: InboxPage
    let world: FrameWorld
    let host: InboxHost
    /// The window's toast center, for the notices that are not writes (a copy, a missing terminal app). Views set it from the
    /// environment (`using(_:)`).
    var toasts: ToastCenter?
    /// The store's world now (nil for a shot's fixed world): a press re-derives what it does from it, so a press drawn before
    /// a write landed acts on the world after it.
    var liveWorld: (@MainActor () -> FrameWorld)?

    /// The world a press acts on: the store's now, or the fixed one.
    var currentWorld: FrameWorld { liveWorld?() ?? world }

    var writes: FrameWrites { model.writes }

    func using(_ toasts: ToastCenter) -> InboxActions {
        var copy = self
        copy.toasts = toasts
        return copy
    }

    /// The row's actions as the frame's one list: buttons on the selected row, context menu, accessibility actions and the
    /// Item menu (`FrameRowAction`).
    func rowActions(_ row: InboxRowModel) -> [FrameRowAction] {
        row.actions.map { action in
            FrameRowAction(id: action.id, title: action.title, shortcut: action.shortcut, isDestructive: action.isDestructive,
                           isEnabled: action.isEnabled && !isPending(action, row), isQuiet: action.isQuiet) { perform(action, on: row) }
        }
    }

    func isPending(_ action: InboxAction, _ row: InboxRowModel) -> Bool {
        switch action {
        case .keep: writes.isPending("keep:\(row.id)")
        case .stopKeeping: writes.isPending("unkeep:\(row.id)")
        case .remove: writes.isPending(Self.removeControl(row.id))
        case .addTo:
            if case .balance(let item, _, _) = row.finding.subject { writes.isPending(Self.addControl(item.id)) } else { false }
        case .changeToAsk:
            if case .rule(let rule, let file) = row.finding.subject { writes.isPending(FrameWrite.verdictControl(rule.rule, in: file)) } else { false }
        default: false
        }
    }

    /// The pending keys of one item row's writes: its Remove, its Balance Add, its tiles.
    static func removeControl(_ rowID: String) -> String { "removeMany:\(rowID)" }
    static func addControl(_ rowID: String) -> String { "copyTo:\(rowID)" }
    static func tileControl(_ rowID: String) -> String { "tile:\(rowID)" }

    /// A write on the item runs (its Remove, Add or a tile): no tile of it starts another until the core answered and the
    /// store read it again, so two quick presses never act on the same world (D53).
    func isItemBusy(_ rowID: String) -> Bool {
        [Self.removeControl(rowID), Self.addControl(rowID), Self.tileControl(rowID)].contains(where: writes.isPending)
    }

    /// No press on the item starts a write: one runs on it, or an Undo runs (from a toast or the Journal window), which may
    /// change any item, so the press would be judged on the world before it (D53).
    func isItemLocked(_ rowID: String) -> Bool { isItemBusy(rowID) || writes.isUndoing }

    /// Keep's move to the next finding, once the write landed: only on Inbox, and only while the kept row is still selected.
    static func keepMovesSelection(route: FrameRoute, keptRow: String) -> Bool {
        route.page == .inbox && route.selection == keptRow
    }

    func select(_ id: String?) {
        model.router.select(id)
    }

    /// Space on the selected row (the arrow keys select as they move): ticks or unticks it when it can be removed, as its
    /// checkbox does.
    func toggleTick(_ id: String?) -> Bool {
        guard let row = page.row(id), row.isRemovable else { return false }
        state.toggleTick(row.id)
        return true
    }

    func perform(_ action: InboxAction, on row: InboxRowModel) {
        let finding = row.finding
        switch action {
        case .keep:
            // Keep moves the selection to the next finding (the mock's `keep`).
            let order = page.order
            let next = order.firstIndex(of: row.id).flatMap { index in
                index + 1 < order.count ? order[index + 1] : index > 0 ? order[index - 1] : nil
            }
            let wasSelected = model.router.route.selection == row.id
            Task {
                if await writes.perform(.keep(findingID: finding.id)) {
                    state.ticked.remove(row.id)
                    // Only while Inbox still shows and the kept row is still the selected one: a page change or another
                    // selection made while the write ran is never pulled back.
                    if wasSelected, Self.keepMovesSelection(route: model.router.route, keptRow: row.id) { model.router.select(next) }
                }
            }
        case .stopKeeping:
            Task { await writes.perform(.unkeep(findingID: finding.id)) }
        case .remove:
            guard case .row(let item) = finding.subject else { return }
            remove([item], control: Self.removeControl(row.id))
        case .addTo(let cli, _):
            guard case .balance(let item, _, _) = finding.subject, !isItemLocked(item.id) else { return }
            Task { await writes.perform(.copyTo(item, targets: [cli], registry: world.snapshot.registry, control: Self.addControl(item.id))) }
        case .copyCommand(let command):
            copy(command)
        case .changeToAsk:
            guard case .rule(let rule, let file) = finding.subject else { return }
            changeVerdict(rule, in: file, to: .ask)
        case .showTerminal(let pid):
            if let app = host.hostApp(pid), host.activate(app) { return }
            toasts?.show("Terminal app not found", tone: .danger)
        case .terminalNotFound:
            return
        }
    }

    /// `Remove N selected`: the ticked rows shown (`FrameWorld.removalSet`), as one change with one Undo.
    func removeTicked() {
        let shown = page.rows.compactMap { row -> FrameRow? in if case .row(let item) = row.finding.subject { item } else { nil } }
        let rows = world.removalSet(selected: Set(page.ticked), shown: shown)
        remove(rows, control: "removeMany")
    }

    /// At once with Undo when no file is shared; otherwise the confirmation names every reader first (RD-R11). The removal
    /// names every member sharing a file with the rows, other rows' links included (`RowRemoval.members`), so the engine
    /// takes what the confirmation said instead of refusing.
    func remove(_ rows: [FrameRow], control: String) {
        guard !rows.isEmpty else { return }
        let world = currentWorld
        let wording = InboxWording(world: world, now: Date())
        let write = FrameWrite.removeMany(rows, ids: RowRemoval.members(rows, in: world), registry: world.snapshot.registry, control: control)
        let ids = rows.map(\.id)
        guard rows.contains(where: wording.asksBeforeRemoving) else {
            run(write, unticking: ids)
            return
        }
        state.confirming = InboxConfirmation(items: rows.map { Self.item($0, losers: wording.losers($0).map(wording.name)) },
                                             write: write, rowIDs: ids, routeRevision: model.router.revision)
    }

    /// A tile turned on or off in the inspector (RD-R11): exactly what the row's logo does on Skills or Subagents
    /// (`RowRemoval.toggle`), derived from the world now: on copies into that CLI's folder; off removes what that CLI reads
    /// the item from, or asks first, naming every CLI that loses it, when another CLI reads one of those files. The last
    /// copy is not a toggle (D53).
    @discardableResult
    func toggleTile(_ tile: CLIToggleState, row: FrameRow) -> Task<Void, Never>? {
        // While any write on the item runs, no tile of it starts another (the tiles show it pending).
        guard !isItemLocked(row.id) else { return nil }
        let world = currentWorld
        let row = world.rows.first { $0.id == row.id } ?? row
        guard let state = CLIToggleStates.states(of: row, in: world).first(where: { $0.cli.id == tile.cli.id }) else { return nil }
        let registry = world.snapshot.registry
        let control = Self.tileControl(row.id)
        let write: FrameWrite
        switch RowRemoval.toggle(state, row: row, in: world) {
        case .none:
            return nil
        case .add(let cli):
            write = .copyTo(row, targets: [cli], registry: registry, control: control)
        case .removeFrom(let cli):
            write = .removeFrom(row, clis: [cli], registry: registry, control: control)
        case .removeMembers(_, let members):
            write = .removeMembers([row], members: members, registry: registry, control: control)
        case .confirm(let removal):
            let wording = InboxWording(world: world, now: Date())
            self.state.confirming = InboxConfirmation(
                items: [Self.item(row, losers: removal.losers.map(wording.name))],
                write: .removeMembers([row], members: removal.members, registry: registry, control: control, shared: true),
                rowIDs: [], routeRevision: model.router.revision)
            return nil
        }
        // Pending before this returns (`FrameWrites.start`): a second tile press in the same main-actor turn finds the item busy.
        guard let task = writes.start(write) else { return nil }
        return Task { _ = await task.value }
    }

    func confirm() {
        guard let confirmation = state.confirming else { return }
        Task {
            if await writes.perform(confirmation.write) { state.ticked.subtract(confirmation.rowIDs) }
            state.confirming = nil
        }
    }

    /// Cancel, and Esc through the frame (`FrameDialog.cancel`): nothing while the confirmed write runs, so the dialog
    /// stays until the core answered.
    func cancelConfirmation() {
        guard !isConfirming else { return }
        state.confirming = nil
    }

    var isConfirming: Bool { state.confirming.map { writes.isPending($0.write.control) } ?? false }

    /// A command or an id to the clipboard: not a write, so no Undo.
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        toasts?.show("Copied to the clipboard")
    }

    func tryAgain() { Task { await model.store.refresh(force: true) } }

    /// The rule inspector's dial (the mock's `ruleInspector`, RD46): the rule's verdict becomes `verdict` in its own file,
    /// with Undo. Nothing while that rule's write runs, so a second quick press never sends a `from` the file no longer holds.
    func changeVerdict(_ rule: CoreRule, in file: FrameScope, to verdict: CoreVerdict) {
        guard rule.verdict != verdict, !writes.isPending(FrameWrite.verdictControl(rule.rule, in: file)) else { return }
        let label = "Changed \(rule.rule) from \(PermissionDial.title(rule.verdict)) to \(PermissionDial.title(verdict)) in \(InboxWording.settingsFile(file))"
        // Pending before this returns (`FrameWrites.start`), so a press in the same main-actor turn finds the write running.
        writes.start(.changeVerdict(rule.rule, from: rule.verdict, to: verdict, in: file, label: label))
    }

    func showInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
    }

    private func run(_ write: FrameWrite, unticking ids: [String]) {
        Task { if await writes.perform(write) { state.ticked.subtract(ids) } }
    }

    nonisolated static func item(_ row: FrameRow, losers: [String]) -> RemoveConfirmation.Item {
        let icon: FrameIcon = row.kind == .hook ? .hooks : row.kind == .agent ? .subagents : .skills
        return RemoveConfirmation.Item(id: row.id, name: row.name, icon: icon, losers: losers)
    }
}

/// The selected row's actions at the overlay inspector's top below 1100 pt, where the overlay covers the row (DS-R10).
struct InboxOverlayActions: View {
    let row: InboxRowModel
    let actions: InboxActions
    @Environment(ToastCenter.self) private var toasts

    var body: some View { FrameRowActionButtons(actions: actions.using(toasts).rowActions(row)) }
}
