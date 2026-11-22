import Foundation
import Observation

/// A removal that names its readers before it writes (RD-R11 "every other removal path … Clean names the readers too"):
/// the confirmation's lines and the request it runs.
struct CleanConfirmation {
    let items: [RemoveConfirmation.Item]
    let request: CleanRequest
    /// `FrameRouter.revision` when it opened: a route changed from outside since (the glance widget) closes it.
    var routeRevision = 0
}

/// Clean's own view state (AR3: never in the store): the ticked rows, the open lock popover, the removal waiting for its
/// confirmation and the move's progress and Cancel. Nothing is ticked at first (RD41). The log age is a fact of the store
/// (`FrameFacts.cleanLogAges`), because what can be cleaned, which the sidebar shows, depends on it. One per `FrameModel`
/// (`FrameModel.pageState`).
@MainActor
@Observable
final class CleanPageState {
    var ticked: Set<String> = []
    /// `logs:<cli>` or `caches:<cli>`: the lock popover open now.
    var openLock: String?
    var confirming: CleanConfirmation?
    let run = CleanMoveRun()

    static func of(_ model: FrameModel) -> CleanPageState {
        model.pageState(CleanPageState.self) { CleanPageState() }
    }

    func toggle(_ id: String) {
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    /// A section head's pick: ticks every suggested row of the section, or clears them when all are ticked (the mock's
    /// `selgrp`).
    func pick(_ ids: [String]) {
        if !ids.isEmpty, ids.allSatisfy(ticked.contains) { ticked.subtract(ids) } else { ticked.formUnion(ids) }
    }

    func toggleLock(_ id: String) { openLock = openLock == id ? nil : id }
}

/// Every press on Clean, through the one write path (AR4) or the store's on-demand read.
@MainActor
struct CleanActions {
    let model: FrameModel
    let state: CleanPageState
    let page: CleanPage
    let world: FrameWorld
    /// The window's toast center, for the notice after Scan Again. Views set it from the environment (`using(_:)`).
    var toasts: ToastCenter?

    var writes: FrameWrites { model.writes }

    func using(_ toasts: ToastCenter) -> CleanActions {
        var copy = self
        copy.toasts = toasts
        return copy
    }

    /// The checkbox: Clean's rows are never selected (no inspector, the mock's `cursor:default`), so only it ticks a row.
    func toggle(_ row: CleanRowModel) {
        guard row.isOpen else { return }
        state.toggle(row.id)
    }

    /// Space on the row the arrow keys reached (`FrameChrome.keyboardRow`, the one with the focus bar): ticks it when open.
    func toggleFocused(_ id: String?) -> Bool {
        guard let row = page.row(id), row.isOpen else { return false }
        state.toggle(row.id)
        return true
    }

    func pick(_ section: CleanSectionModel) { state.pick(section.suggested) }

    /// The age control of a log row: a fact of the store, so the hero and the sidebar follow it.
    func setAge(_ days: Int, cli: String) {
        model.store.facts.cleanLogAges[cli] = days
    }

    /// The page opened: `clean.scan` once (never on the frame's timer). Nothing while a move runs: its re-read follows it.
    func measure() async {
        guard !state.run.isRunning else { return }
        await model.store.readClean()
    }

    /// Scan Again (the mock's `rescan`): the same read, and "Measured again" once it answered.
    func scanAgain() {
        Task {
            await model.store.readClean()
            if case .ready = model.store.states[.clean] { toasts?.show("Measured again") }
        }
    }

    /// Try Again on a failure band: every source, then the scan.
    func tryAgain() {
        Task {
            await model.store.refresh(force: true)
            await model.store.readClean()
        }
    }

    /// `Remove …`: at once with Undo when no ticked file is shared; otherwise the confirmation names every reader first.
    func remove() {
        let request = page.request(world)
        guard !request.isEmpty, !writes.isPending(FrameWrite.cleanControl) else { return }
        guard page.sharedRows(world).isEmpty else {
            state.confirming = CleanConfirmation(items: page.confirmationItems(world), request: request, routeRevision: model.router.revision)
            return
        }
        run(request)
    }

    func confirm() {
        guard let confirmation = state.confirming else { return }
        Task {
            await perform(confirmation.request)
            state.confirming = nil
        }
    }

    /// Cancel, and Esc through the frame (`FrameDialog.cancel`): nothing while the confirmed write runs (the move's own
    /// Cancel is in the band), so the dialog stays until the core answered.
    func cancelConfirmation() {
        guard !isConfirming else { return }
        state.confirming = nil
    }

    var isConfirming: Bool { state.confirming != nil && writes.isPending(FrameWrite.cleanControl) }

    /// Cancel in the moving band: the move stops before its next file.
    func cancelMove() { state.run.cancel() }

    private func run(_ request: CleanRequest) {
        Task { await perform(request) }
    }

    private func perform(_ request: CleanRequest) async {
        let ids = request.rows.map(\.id) + request.logs.map { CleanPlan.LogRow.id($0.cli) } + request.caches
        state.openLock = nil
        if await writes.perform(.clean(request, run: state.run, registry: world.snapshot.registry)) {
            state.ticked.subtract(ids)
        }
    }
}
