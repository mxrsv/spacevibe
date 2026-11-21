import Foundation
import Observation

/// What the core answered to a write.
enum FrameWriteOutcome: Equatable, Sendable {
    /// The Journal entry the write recorded: its id is what Undo runs.
    case entry(CoreJournalEntry)
    /// `rules.setCapability` answered null: the file already holds that.
    case nothingToChange
    /// A change that is not journaled (Stop): no Undo.
    case done
}

/// One write as the write service runs it.
struct FrameWrite: Sendable {
    /// The control that started it: it shows pending, and a second press while pending does nothing.
    let control: String
    /// The toast after the core accepted it ("Removed ponytail").
    let label: String
    /// The sources read again once the core answered, and again after its Undo.
    let touches: Set<FrameSource>
    let run: @Sendable (any CoreService) async throws -> FrameWriteOutcome
}

/// The redesign's one write path (plan AR4): pending at the control, the core call, then a toast with Undo on the returned
/// Journal id or the refused-write toast with the core's sentence, then the store re-reads the touched sources. Nothing
/// changes on screen before the core answers (no optimistic change): a page shows the store's data, which changes only by
/// the re-read.
///
/// Undo runs through `ToastCenter`'s one session stack, which the toast button, ⌘Z and Z all pop (RD39): an item holds the
/// Journal id and runs `journal.undo` on it, one at a time.
@MainActor
@Observable
final class FrameWrites {
    /// The sentence for a write the core found nothing to do for (the same as the v5 Rules page's).
    static let nothingToChange = "Nothing to change: the file already holds that."

    private(set) var pending: Set<String> = []

    @ObservationIgnored private let core: any CoreService
    @ObservationIgnored private let store: FrameStore
    @ObservationIgnored private let toasts: ToastCenter

    init(core: any CoreService, store: FrameStore, toasts: ToastCenter) {
        self.core = core
        self.store = store
        self.toasts = toasts
    }

    func isPending(_ control: String) -> Bool { pending.contains(control) }

    /// Runs one write; true when the core accepted it. A control that is already pending starts nothing.
    @discardableResult
    func perform(_ write: FrameWrite) async -> Bool {
        guard !pending.contains(write.control) else { return false }
        pending.insert(write.control)
        defer { pending.remove(write.control) }
        let outcome: Result<FrameWriteOutcome, Error>
        do { outcome = .success(try await write.run(core)) } catch { outcome = .failure(error) }
        switch outcome {
        case .success(.entry(let entry)):
            toasts.show(write.label, asyncUndo: { [weak self] in await self?.undo(entry, of: write) })
        case .success(.nothingToChange):
            toasts.show(Self.nothingToChange)
        case .success(.done):
            toasts.show(write.label)
        case .failure(let error):
            toasts.show(AppEnvironment.message(error), tone: .danger)
        }
        // A refusal re-reads too: the core may have refused because the file moved under the page.
        await store.reread(write.touches.union([.journal]))
        if case .success = outcome { return true }
        return false
    }

    private func undo(_ entry: CoreJournalEntry, of write: FrameWrite) async {
        do {
            let undone = try await core.journalUndo(id: entry.id)
            toasts.show("Undid \(undone.label.isEmpty ? write.label : undone.label)")
        } catch {
            toasts.show(AppEnvironment.message(error), tone: .danger)
        }
        await store.reread(write.touches.union([.journal]))
    }
}

// MARK: The engine's writes today

/// The writes the core has now, each with the sources it touches. RB-E3 (`copyTo`, `removeFrom`) and RB-E4
/// (`removeMany`, `rules.removeMany`) add theirs here as they land.
extension FrameWrite {
    private static let loadoutSources: Set<FrameSource> = [.inventory, .loadout]

    static func copyToOther(id: String, label: String) -> FrameWrite {
        FrameWrite(control: "copy:\(id)", label: label, touches: loadoutSources) { .entry(try await $0.loadoutCopyToOther(id: id).entry) }
    }

    static func removeItem(id: String, label: String) -> FrameWrite {
        FrameWrite(control: "remove:\(id)", label: label, touches: loadoutSources) { .entry(try await $0.loadoutRemoveItem(id: id).entry) }
    }

    static func removeDeadHooks(cli: CoreCLI, label: String) -> FrameWrite {
        FrameWrite(control: "removeDeadHooks:\(cli.rawValue)", label: label, touches: loadoutSources) {
            .entry(try await $0.loadoutRemoveDeadHooks(cli: cli).entry)
        }
    }

    static func changeVerdict(_ rule: String, from: CoreVerdict, to: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "verdict:\(file.dir ?? ""):\(rule)", label: label, touches: [.rules(file)]) {
            .entry(try await $0.rulesChangeVerdict(scope: file.scope, dir: file.dir, rule: rule, from: from, to: to).entry)
        }
    }

    static func removeRule(_ rule: String, verdict: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "removeRule:\(file.dir ?? ""):\(rule)", label: label, touches: [.rules(file)]) {
            .entry(try await $0.rulesRemove(scope: file.scope, dir: file.dir, verdict: verdict, rule: rule).entry)
        }
    }

    static func addRule(_ rule: String, verdict: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "addRule:\(file.dir ?? "")", label: label, touches: [.rules(file)]) {
            .entry(try await $0.rulesAdd(scope: file.scope, dir: file.dir, verdict: verdict, rule: rule).entry)
        }
    }

    static func setCapability(_ capability: CoreCapability, to verdict: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "capability:\(file.dir ?? ""):\(capability.rawValue)", label: label, touches: [.rules(file)]) { core in
            let result = try await core.rulesSetCapability(scope: file.scope, dir: file.dir, capability: capability, verdict: verdict)
            return result.entry.map(FrameWriteOutcome.entry) ?? .nothingToChange
        }
    }

    /// Stop is not undoable: the page confirms first (RD-R16), and the subscription pushes the ended session.
    static func stop(cli: CoreCLI, sessionID: String, label: String) -> FrameWrite {
        FrameWrite(control: "stop:\(cli.rawValue):\(sessionID)", label: label, touches: [.activity]) { core in
            _ = try await core.activityStop(cli: cli, id: sessionID)
            return .done
        }
    }
}
