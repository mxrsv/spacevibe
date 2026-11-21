import AppKit
import Observation
import SwiftUI

/// The Inbox's own view state (AR3: never in the store): the ticked rows, whether kept findings are listed, the removal
/// waiting for its confirmation and the list's width. Nothing is ticked at first (RD41).
///
/// `FrameModel` has no home for a page's view state and `FramePageContent.region` is rebuilt on every frame render, so one
/// state lives per model here (`of(_:)`), dropped with its model.
@MainActor
@Observable
final class InboxPageState {
    var ticked: Set<String> = []
    var showsKept = false
    var confirming: InboxConfirmation?
    var listWidth: CGFloat = 0

    @ObservationIgnored private static var states: [ObjectIdentifier: (model: WeakModel, state: InboxPageState)] = [:]

    struct WeakModel { weak var model: FrameModel? }

    static func of(_ model: FrameModel) -> InboxPageState {
        states = states.filter { $0.value.model.model != nil }
        let key = ObjectIdentifier(model)
        if let found = states[key] { return found.state }
        let state = InboxPageState()
        states[key] = (WeakModel(model: model), state)
        return state
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
                             showsKept: state.showsKept, hasHost: { host.hostApp($0) != nil }, now: inputs.now)
        let selection = fixed == nil ? model.router.route.selection : inputs.selection
        let actions = InboxActions(model: model, state: state, page: page, world: inputs.world, host: host)
        let selected = page.row(selection)
        let narrow = !FindingRowLayout.showsEvidence(listWidth: state.listWidth)
        return FramePageContent(
            help: FramePage.inbox.help,
            primary: page.primary == .hidden ? nil : AnyView(InboxRemoveButton(page: page, narrow: narrow, actions: actions)),
            body: AnyView(InboxList(page: page, selection: selection, state: state, actions: actions)),
            inspector: AnyView(InboxInspector(row: selected, world: inputs.world, now: inputs.now, actions: actions,
                                              hasRows: !page.rows.isEmpty || !page.kept.isEmpty)),
            overlayActions: selected.map { AnyView(InboxOverlayActions(row: $0, actions: actions)) })
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
                           isEnabled: action.isEnabled && !isPending(action, row)) { perform(action, on: row) }
        }
    }

    func isPending(_ action: InboxAction, _ row: InboxRowModel) -> Bool {
        switch action {
        case .keep: writes.isPending("keep:\(row.id)")
        case .stopKeeping: writes.isPending("unkeep:\(row.id)")
        case .remove: writes.isPending("removeMany:\(row.id)")
        default: false
        }
    }

    func select(_ id: String) {
        model.router.select(id)
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
                    if wasSelected { model.router.select(next) }
                }
            }
        case .stopKeeping:
            Task { await writes.perform(.unkeep(findingID: finding.id)) }
        case .remove:
            guard case .row(let item) = finding.subject else { return }
            remove([item], control: "removeMany:\(row.id)")
        case .addTo(let cli, _):
            guard case .balance(let item, _, _) = finding.subject else { return }
            Task { await writes.perform(.copyTo(item, targets: [cli], registry: world.snapshot.registry)) }
        case .copyCommand(let command):
            copy(command)
        case .changeToAsk:
            guard case .rule(let rule, let file) = finding.subject else { return }
            let label = "Changed \(rule.rule) from Allow to Ask in \(InboxWording.settingsFile(file))"
            Task { await writes.perform(.changeVerdict(rule.rule, from: .allow, to: .ask, in: file, label: label)) }
        case .showInLimits(let windowID):
            model.router.go(to: .window(windowID))
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

    /// At once with Undo when no file is shared; otherwise the confirmation names every reader first (RD-R11).
    func remove(_ rows: [FrameRow], control: String) {
        guard !rows.isEmpty else { return }
        let wording = InboxWording(world: world, now: Date())
        let write = FrameWrite.removeMany(rows, members: InboxWording.removableMembers(rows), registry: world.snapshot.registry, control: control)
        let ids = rows.map(\.id)
        guard rows.contains(where: wording.asksBeforeRemoving) else {
            run(write, unticking: ids)
            return
        }
        state.confirming = InboxConfirmation(items: rows.map { Self.item($0, losers: wording.losers($0).map(wording.name)) },
                                             write: write, rowIDs: ids)
    }

    /// A tile turned on or off in the inspector (RD-R11): on copies into that CLI's folder; off removes every file it reads
    /// the item from, asking first when another CLI reads one of them.
    func toggleTile(_ tile: CLIToggleState, row: FrameRow) {
        let registry = world.snapshot.registry
        guard tile.isOn else {
            Task { await writes.perform(.copyTo(row, targets: [tile.cli.id], registry: registry, control: "tile:\(row.id)")) }
            return
        }
        let readers = world.readers(of: row)
        let removed = readers.map { $0.turningOff(tile.cli.id) } ?? []
        let losers = world.losers(of: row, removing: removed).value ?? [tile.cli.id]
        let write = FrameWrite.removeFrom(row, clis: losers, registry: registry, control: "tile:\(row.id)")
        guard tile.sharedWith.isEmpty else {
            let wording = InboxWording(world: world, now: Date())
            state.confirming = InboxConfirmation(items: [Self.item(row, losers: losers.map(wording.name))], write: write, rowIDs: [])
            return
        }
        Task { await writes.perform(write) }
    }

    func confirm() {
        guard let confirmation = state.confirming else { return }
        Task {
            if await writes.perform(confirmation.write) { state.ticked.subtract(confirmation.rowIDs) }
            state.confirming = nil
        }
    }

    func cancelConfirmation() { state.confirming = nil }

    var isConfirming: Bool { state.confirming.map { writes.isPending($0.write.control) } ?? false }

    /// A command or an id to the clipboard: not a write, so no Undo.
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        toasts?.show("Copied to the clipboard")
    }

    func tryAgain() { Task { await model.store.refresh(force: true) } }

    func showInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
    }

    private func run(_ write: FrameWrite, unticking ids: [String]) {
        Task { if await writes.perform(write) { state.ticked.subtract(ids) } }
    }

    static func item(_ row: FrameRow, losers: [String]) -> RemoveConfirmation.Item {
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
