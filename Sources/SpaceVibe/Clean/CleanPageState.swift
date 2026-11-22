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

    /// A tick on a row that can no longer hold one (it became locked, read-only or went) is dropped, never kept for when the
    /// lock ends: the next Remove takes only what the user sees ticked now.
    func keepTicks(_ tickable: Set<String>) {
        let kept = ticked.intersection(tickable)
        if kept != ticked { ticked = kept }
    }
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
            // The answer of the scan this press waited for (it joins one in flight), never a later one's state.
            if await model.store.readClean() { toasts?.show("Measured again") }
        }
    }

    /// Try Again on a failure band: every source and one scan (`refresh(force:)` runs the scan with the rest).
    func tryAgain() {
        Task { await model.store.refresh(force: true) }
    }

    /// `Remove …`: at once with Undo when no ticked file is shared; otherwise the confirmation names every reader first.
    /// Returns the write's task (tests wait on it).
    @discardableResult
    func remove() -> Task<Bool, Never>? {
        let request = page.request(world)
        guard !request.isEmpty, !writes.isPending(FrameWrite.cleanControl) else { return nil }
        guard page.sharedRows(world).isEmpty else {
            state.confirming = CleanConfirmation(items: page.confirmationItems(world), request: request, routeRevision: model.router.revision)
            return nil
        }
        return start(request)
    }

    /// The confirmation's Remove: the write is pending before this returns (`FrameWrites.start`), and the dialog closes at
    /// once, so the moving band's progress and Cancel are in reach while the files move (the dialog would cover them).
    @discardableResult
    func confirm() -> Task<Bool, Never>? {
        guard let confirmation = state.confirming, let task = start(confirmation.request) else { return nil }
        state.confirming = nil
        return task
    }

    /// Cancel, and Esc through the frame (`FrameDialog.cancel`). The dialog closes as the write starts, so it never waits for
    /// one; the guard is for a write started elsewhere while it shows.
    func cancelConfirmation() {
        guard !isConfirming else { return }
        state.confirming = nil
    }

    var isConfirming: Bool { state.confirming != nil && writes.isPending(FrameWrite.cleanControl) }

    /// Cancel in the moving band: the move stops before its next file.
    func cancelMove() { state.run.cancel() }

    /// Clean's write, pending at once. The ticks it took are dropped as soon as the core answered (before the re-read), so
    /// Remove is never drawn enabled for rows that already moved.
    private func start(_ request: CleanRequest) -> Task<Bool, Never>? {
        let ids = request.rows.map(\.id) + request.logs.map { CleanPlan.LogRow.id($0.cli) } + request.caches
        let state = state
        let write = FrameWrite.clean(request, run: state.run, registry: world.snapshot.registry) { state.ticked.subtract(ids) }
        guard let task = writes.start(write) else { return nil }
        state.openLock = nil
        return task
    }
}
