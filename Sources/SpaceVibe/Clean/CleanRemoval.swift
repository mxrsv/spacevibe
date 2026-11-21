import Foundation
import Observation

/// What one press of Clean's `Remove …` takes: the ticked open rows of the three sections (CL4: equipment first, then logs
/// and caches). Built by `CleanPage.request`, so only what is ticked and shown is ever sent.
struct CleanRequest: Equatable, Sendable {
    /// Never ran and Dead rows: `loadout.removeMany` into SpaceVibe's trash (CL-R1, one Journal entry).
    let rows: [FrameRow]
    /// Their member ids: every member of a Skill or Subagent, a Hook's Claude Code members only (D25).
    let members: [String]
    /// Log buckets and cache ids: `clean.move` into the macOS Trash (CL-R5, one Journal entry).
    let logs: [CoreCleanLogPick]
    let caches: [String]
    /// A group id of `clean.move` (`logs:<cli>` or a cache id) → what the page calls it, for the partial result.
    let groupNames: [String: String]

    var movesFiles: Bool { !logs.isEmpty || !caches.isEmpty }
    var isEmpty: Bool { members.isEmpty && !movesFiles }
}

/// The progress and the Cancel of one `clean.move` (RB-R5): `clean/progress` lands here for the band at the control that
/// started the move, and `cancel()` cancels the call's own task, which sends `$/cancelRequest`; the core stops before its
/// next file and still answers with what moved. Page state: one per frame, never in the store (AR3).
@MainActor
@Observable
final class CleanMoveRun {
    private(set) var isRunning = false
    private(set) var progress: CoreCleanProgress?
    /// Cancel was pressed; the move has not answered yet.
    private(set) var isCancelling = false

    /// The run as one value, for the pure page model.
    struct Snapshot: Equatable, Sendable {
        var isRunning = false
        var progress: CoreCleanProgress?
        var isCancelling = false

        static let idle = Snapshot()
    }

    var snapshot: Snapshot { Snapshot(isRunning: isRunning, progress: progress, isCancelling: isCancelling) }

    @ObservationIgnored private var task: Task<CoreCleanMoveResult, Error>?
    @ObservationIgnored private var generation = 0

    func begin() {
        generation += 1
        isRunning = true
        isCancelling = false
        progress = nil
    }

    func end() {
        generation += 1
        isRunning = false
        isCancelling = false
        progress = nil
        task = nil
    }

    /// Runs the move in a task of its own, so Cancel reaches the core call and nothing else: the re-read after it still runs.
    /// A Cancel pressed before the move started stops it from starting.
    func move(_ call: @escaping @Sendable (@escaping @Sendable (CoreCleanProgress) -> Void) async throws -> CoreCleanMoveResult) async throws
        -> CoreCleanMoveResult {
        if isCancelling { throw CancellationError() }
        let current = generation
        let report: @Sendable (CoreCleanProgress) -> Void = { [weak self] progress in
            Task { @MainActor in self?.report(progress, generation: current) }
        }
        let task = Task { try await call(report) }
        self.task = task
        return try await task.value
    }

    func cancel() {
        guard isRunning else { return }
        isCancelling = true
        task?.cancel()
    }

    /// A late note of an earlier move never shows on a later one.
    func report(_ progress: CoreCleanProgress, generation: Int) {
        guard generation == self.generation, isRunning else { return }
        self.progress = progress
    }
}

extension FrameWrite {
    /// The Clean control every press of `Remove …` pends on.
    static let cleanControl = "clean:remove"
    /// What a Clean write re-reads: the rows, and `clean.scan` for the sizes and what is left.
    static let cleanSources: Set<FrameSource> = [.inventory, .loadout, .clean]

    /// Clean's one write (AR4): the equipment first (`loadout.removeMany`), then the logs and caches (`clean.move`, through
    /// `run` for progress and Cancel). One toast, one Undo for both entries. A refused removal changes nothing and stops
    /// there; once the equipment is gone, a refused, cancelled or partial move is a partial result, never a refusal, because
    /// something did change.
    static func clean(_ request: CleanRequest, run: CleanMoveRun, registry: [CoreRegistryCLI]) -> FrameWrite {
        let what = request.rows.isEmpty ? nil : selection(request.rows)
        let editsSettings = request.rows.contains { $0.kind == .hook }
        return FrameWrite(control: cleanControl, label: CleanWording.done(what: what, moved: nil, editsSettings: editsSettings),
                          touches: cleanSources) { core in
            await run.begin()
            do {
                let outcome = try await cleanOutcome(request, what: what, editsSettings: editsSettings, run: run, core: core)
                await run.end()
                return outcome
            } catch {
                await run.end()
                throw error
            }
        }
    }

    private static func cleanOutcome(_ request: CleanRequest, what: String?, editsSettings: Bool, run: CleanMoveRun,
                                     core: any CoreService) async throws -> FrameWriteOutcome {
        var entries: [CoreJournalEntry] = []
        if !request.members.isEmpty {
            entries.append(try await core.loadoutRemoveMany(ids: request.members).entry)
        }
        guard request.movesFiles else {
            return .entries(entries, label: CleanWording.done(what: what, moved: nil, editsSettings: editsSettings), isPartial: false)
        }
        do {
            let result = try await run.move { report in try await core.cleanMove(logs: request.logs, caches: request.caches, progress: report) }
            if let entry = result.entry { entries.append(entry) }
            if let partial = CleanWording.partial(result, request: request, removedRows: request.rows.count, what: what) {
                return .entries(entries, label: partial, isPartial: true)
            }
            return .entries(entries, label: CleanWording.done(what: what, moved: result.moved.bytes, editsSettings: editsSettings), isPartial: false)
        } catch is CancellationError {
            guard let what else { return .notice(CleanWording.cancelledBeforeAnyFile) }
            return .entries(entries, label: CleanWording.removedThen(what, CleanWording.cancelledBeforeMove), isPartial: true)
        } catch {
            guard let what else { throw error }
            return .entries(entries, label: CleanWording.removedThen(what, "Logs and caches stayed in place: \(CleanWording.sentence((error as? CoreError)?.message ?? CoreError.unexpectedMessage))"),
                            isPartial: true)
        }
    }
}

/// The toasts of Clean's write (the mock's `removeIds`, `writeToast` and `FAIL_MSG.clean`). Logs and caches are "moved to
/// the macOS Trash", never "freed": the disk gets the space back only when the Trash is emptied (clean.md). Bytes are what
/// the core reports as moved, not the estimate (CL-R6). Pure.
enum CleanWording {
    static let cancelledBeforeAnyFile = "Cancelled. Nothing was moved."
    static let cancelledBeforeMove = "The move was cancelled before any log or cache moved."
    static let undoMoved = "Undo puts back what moved."

    /// "Removed 3 Skills to SpaceVibe's trash and moved 1.02 GB of logs and caches to the macOS Trash. settings.json was
    /// edited"; either half alone.
    static func done(what: String?, moved: Int64?, editsSettings: Bool) -> String {
        let files = moved.map { "\(NumberWording.bytes($0)) of logs and caches to the macOS Trash" }
        let head: String = switch (what, files) {
        case let (what?, files?): "Removed \(what) to SpaceVibe's trash and moved \(files)"
        case let (what?, nil): "Removed \(what) to SpaceVibe's trash"
        case let (nil, files?): "Moved \(files)"
        case (nil, nil): "Moved the selection to the Trash"
        }
        return editsSettings ? "\(head). settings.json was edited" : head
    }

    /// "Removed 3 Skills to SpaceVibe's trash. <then> Undo puts back what moved."
    static func removedThen(_ what: String, _ then: String) -> String {
        "Removed \(what) to SpaceVibe's trash. \(then) \(undoMoved)"
    }

    /// The partial result of a move that left something in place, or nil when every row moved whole. Cancelled: what moved
    /// and that the rest stayed. Otherwise "Moved 2 of 3. ~/.codex/cache stayed in place: <the core's reason> Undo puts back
    /// what moved." (the mock's `FAIL_MSG.clean`); the equipment rows count as moved.
    static func partial(_ result: CoreCleanMoveResult, request: CleanRequest, removedRows: Int, what: String?) -> String? {
        let prefix = what.map { "Removed \($0) to SpaceVibe's trash. " } ?? ""
        if result.cancelled {
            let moved = "\(NumberWording.plural(result.moved.files, "file")) (\(NumberWording.bytes(result.moved.bytes)))"
            return "\(prefix)Cancelled: \(moved) moved to the macOS Trash, the rest stayed in place. \(undoMoved)"
        }
        let stayed = result.groups.filter { $0.stayed > 0 }
        guard let first = stayed.first else { return nil }
        let total = removedRows + result.groups.count
        let whole = removedRows + result.groups.count - stayed.count
        let name = request.groupNames[first.id] ?? first.id
        let who = first.moved.files > 0 ? "\(NumberWording.plural(first.stayed, "file")) of \(name)" : name
        let why = first.reason.map { ": \(sentence($0))" } ?? "."
        let more = stayed.count > 1 ? " \(NumberWording.plural(stayed.count - 1, "more row")) stayed in place too." : ""
        return "Moved \(NumberWording.count(whole)) of \(NumberWording.count(total)). \(who) stayed in place\(why)\(more) \(undoMoved)"
    }

    /// A sentence ends in a full stop.
    static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!") ? trimmed : trimmed + "."
    }
}
