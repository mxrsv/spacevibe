import Foundation
import Observation

/// What the core answered to a write.
enum FrameWriteOutcome: Equatable, Sendable {
    /// The Journal entry the write recorded: its id is what Undo runs.
    case entry(CoreJournalEntry)
    /// As `entry`, with the toast built from the core's answer (who lost the item, who reads the folder too), which the
    /// write cannot know before the call.
    case entryToast(CoreJournalEntry, label: String)
    /// `rules.setCapability` answered null: the file already holds that.
    case nothingToChange
    /// A change that is not journaled (Stop): no Undo.
    case done
    /// One write that recorded several Journal entries (Clean: the equipment's `loadout.removeMany`, then `clean.move`). The
    /// toast's one Undo reverts every entry, newest first. `isPartial`: something stayed where it was, so the toast is the
    /// attention one that stays until dismissed, still with Undo for what changed.
    case entries([CoreJournalEntry], label: String, isPartial: Bool)
    /// The write stopped before changing anything (Clean's Cancel before the first file): a notice, no Undo.
    case notice(String)
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

    /// Runs one write; true when the core accepted it. A control that is already pending starts nothing. `refused`, when
    /// given, takes the core's sentence instead of the refused-write toast: a form shows it next to its field (Rules'
    /// Add Rule sheet).
    @discardableResult
    func perform(_ write: FrameWrite, refused: (@MainActor (String) -> Void)? = nil) async -> Bool {
        guard claim(write.control) else { return false }
        return await run(write, refused: refused)
    }

    /// `perform` from a press: the control is pending before this returns, so a second press in the same main-actor turn
    /// (two logos of one row clicked before the first write's task ran) sees it and starts nothing (D53). Nil when the control
    /// is already pending.
    @discardableResult
    func start(_ write: FrameWrite, refused: (@MainActor (String) -> Void)? = nil) -> Task<Bool, Never>? {
        guard claim(write.control) else { return nil }
        return Task { @MainActor in await self.run(write, refused: refused) }
    }

    private func claim(_ control: String) -> Bool {
        guard !pending.contains(control) else { return false }
        pending.insert(control)
        return true
    }

    /// The write itself, its control already pending; the pending ends when it returns.
    private func run(_ write: FrameWrite, refused: (@MainActor (String) -> Void)?) async -> Bool {
        defer { pending.remove(write.control) }
        let outcome: Result<FrameWriteOutcome, Error>
        do { outcome = .success(try await write.run(core)) } catch { outcome = .failure(error) }
        switch outcome {
        case .success(.entry(let entry)):
            toasts.show(write.label, journalEntries: [entry.id],
                        asyncUndo: { [weak self] in await self?.undo(entry, label: write.label, touches: write.touches) })
        case .success(.entryToast(let entry, let label)):
            toasts.show(label, journalEntries: [entry.id], asyncUndo: { [weak self] in await self?.undo(entry, label: label, touches: write.touches) })
        case .success(.nothingToChange):
            toasts.show(Self.nothingToChange)
        case .success(.done):
            toasts.show(write.label)
        case .success(.entries(let entries, let label, let isPartial)):
            let tone: ToastTone = isPartial ? .partial : .info
            if entries.isEmpty {
                toasts.show(label, tone: tone)
            } else {
                toasts.show(label, tone: tone, journalEntries: entries.map(\.id),
                            asyncUndo: { [weak self] in await self?.undo(entries, label: label, touches: write.touches) })
            }
        case .success(.notice(let sentence)):
            toasts.show(sentence)
        case .failure(let error):
            if let refused { refused(AppEnvironment.message(error)) } else { showRefused(AppEnvironment.message(error), touches: write.touches) }
        }
        // A refusal re-reads too: the core may have refused because the file moved under the page.
        await store.reread(write.touches.union([.journal]))
        if case .success = outcome { return true }
        return false
    }

    /// A sentence about several writes together, after they ran (Add to…'s "Added 2 of 3; 1 refused: …"): the toast only,
    /// no Undo of its own (each write that landed already put its Undo on the session stack).
    func report(_ sentence: String, tone: ToastTone) {
        toasts.show(sentence, tone: tone)
    }

    /// The Journal entry `id` was undone from another window: this window's session stack drops its Undo (`ToastCenter`).
    func forgetUndo(journalEntry id: String) {
        toasts.forgetUndo(journalEntry: id)
    }

    // MARK: Reads before a write

    /// `rules.preview`: what a capability write to `file` would replace and write, before anything is written. It writes
    /// nothing, so it is not a `FrameWrite`.
    func preview(_ capability: CoreCapability, to verdict: CoreVerdict, in file: FrameScope) async throws -> CoreCapabilityPreview {
        try await core.rulesPreview(scope: file.scope, dir: file.dir, capability: capability, verdict: verdict)
    }

    /// `rules.check`: whether a rule string has a shape Claude Code reads, and the sentence a write would refuse it with.
    func check(rule: String) async throws -> CoreRuleCheck {
        try await core.rulesCheck(rule: rule)
    }

    /// The refused-write toast with Reload beside Dismiss (the mock's `writefail`): Reload reads the sources the write touched
    /// again, so a file that changed under the page shows as it is now before the user tries again.
    private func showRefused(_ message: String, touches: Set<FrameSource>) {
        toasts.show(message, tone: .danger, action: ToastAction(title: Self.reloadTitle) { [weak self] in
            guard let self else { return }
            Task { await self.store.reread(touches.union([.journal])) }
        })
    }

    /// The refused-write toast's action.
    static let reloadTitle = "Reload"

    /// Several entries of one write, newest first; the first refusal stops and says so, and what was undone stays undone.
    private func undo(_ entries: [CoreJournalEntry], label: String, touches: Set<FrameSource>) async {
        var labels: [String] = []
        do {
            for entry in entries.reversed() {
                let undone = try await core.journalUndo(id: entry.id)
                labels.insert(undone.label.isEmpty ? entry.label : undone.label, at: 0)
            }
            toasts.show("Undid \(CLINames.sentence(labels.isEmpty ? [label] : labels))")
        } catch {
            showRefused(AppEnvironment.message(error), touches: touches)
        }
        await store.reread(touches.union([.journal]))
    }

    private func undo(_ entry: CoreJournalEntry, label: String, touches: Set<FrameSource>) async {
        do {
            let undone = try await core.journalUndo(id: entry.id)
            toasts.show("Undid \(undone.label.isEmpty ? label : undone.label)")
        } catch {
            showRefused(AppEnvironment.message(error), touches: touches)
        }
        await store.reread(touches.union([.journal]))
    }
}

// MARK: The engine's writes today

/// The writes the core has now, each with the sources it touches (AR2): the v5 ones first, then the new frame's per-CLI,
/// batch and Keep writes (RB-E3, RB-E4, RB-E5).
extension FrameWrite {
    static let loadoutSources: Set<FrameSource> = [.inventory, .loadout]

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

    /// The pending key of a verdict change: the file's scope too, since a project's Shared and Local files share its folder.
    static func verdictControl(_ rule: String, in file: FrameScope) -> String { "verdict:\(file.scope.rawValue):\(file.dir ?? ""):\(rule)" }

    static func changeVerdict(_ rule: String, from: CoreVerdict, to: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: verdictControl(rule, in: file), label: label, touches: [.rules(file)]) {
            .entry(try await $0.rulesChangeVerdict(scope: file.scope, dir: file.dir, rule: rule, from: from, to: to).entry)
        }
    }

    static func removeRule(_ rule: String, verdict: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "removeRule:\(file.scope.rawValue):\(file.dir ?? ""):\(rule)", label: label, touches: [.rules(file)]) {
            .entry(try await $0.rulesRemove(scope: file.scope, dir: file.dir, verdict: verdict, rule: rule).entry)
        }
    }

    static func addRule(_ rule: String, verdict: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "addRule:\(file.scope.rawValue):\(file.dir ?? "")", label: label, touches: [.rules(file)]) {
            .entry(try await $0.rulesAdd(scope: file.scope, dir: file.dir, verdict: verdict, rule: rule).entry)
        }
    }

    static func setCapability(_ capability: CoreCapability, to verdict: CoreVerdict, in file: FrameScope, label: String) -> FrameWrite {
        FrameWrite(control: "capability:\(file.scope.rawValue):\(file.dir ?? ""):\(capability.rawValue)", label: label, touches: [.rules(file)]) { core in
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

// MARK: Per-CLI, batch and Keep writes

extension FrameWrite {
    /// Turns CLIs on for a row: copies its Skill or Subagent into each target's own folder (`loadout.copyTo`). The toast
    /// names the CLIs that read a folder the copy went into ("… read the same folder, so they have it too").
    static func copyTo(_ row: FrameRow, targets: [String], registry: [CoreRegistryCLI], control: String? = nil) -> FrameWrite {
        let source = row.writableMembers.first { id in row.items.contains { $0.id == id } } ?? row.items.first?.id ?? row.id
        let added = "Added \(row.name) to \(names(targets, registry))"
        return FrameWrite(control: control ?? "copyTo:\(row.id)", label: added, touches: loadoutSources) { core in
            let result = try await core.loadoutCopyTo(id: source, targets: targets)
            return .entryToast(result.entry, label: added + alsoReaders(result.alsoReaders, registry))
        }
    }

    /// Turns CLIs off for a row: every file those CLIs read it from goes (`loadout.removeFrom`). The core refuses when a
    /// CLI not named reads one of those files; the toast names who lost it (the mock's "Removed pdf-extract from Codex").
    static func removeFrom(_ row: FrameRow, clis: [String], registry: [CoreRegistryCLI], control: String? = nil) -> FrameWrite {
        let member = row.writableMembers.first ?? row.items.first?.id ?? row.id
        return FrameWrite(control: control ?? "removeFrom:\(row.id)", label: "Removed \(row.name)", touches: loadoutSources) { core in
            let result = try await core.loadoutRemoveFrom(id: member, clis: clis)
            return .entryToast(result.entry, label: removedLabel(row.name, lost: result.lost, registry))
        }
    }

    /// `Remove N selected`: the rows shown and ticked (`FrameWorld.removalSet`), removed as one change with one Undo
    /// (`loadout.removeMany`). The label counts rows, not copies; the call passes `ids` as given when given (members of
    /// other rows included, `RowRemoval.members`), else every member id of each row, or only those in `members`.
    ///
    /// The toast is the mock's `removeIds` sentence: each kind with its word ("Removed Hook lint-staged.sh from Claude Code",
    /// "Removed 3 Skills from Codex"), and ". settings.json was edited" when a Hook went, since its removal edits that file.
    static func removeMany(_ rows: [FrameRow], members: Set<String>? = nil, ids given: [String]? = nil, registry: [CoreRegistryCLI],
                           control: String = "removeMany") -> FrameWrite {
        let ids = given ?? rows.flatMap(\.memberIDs).filter { members?.contains($0) ?? true }
        let what = selection(rows, namesKind: true)
        let edits = rows.contains { $0.kind == .hook } ? edited("settings.json") : ""
        return FrameWrite(control: control, label: "Removed \(what)\(edits)", touches: loadoutSources) { core in
            let result = try await core.loadoutRemoveMany(ids: ids)
            let label = result.lost.isEmpty ? "Removed \(what)" : "Removed \(what) from \(names(result.lost, registry))"
            return .entryToast(result.entry, label: label + edits)
        }
    }

    /// Removes these rules of one file in one edit (`rules.removeMany`); a selection over several files is one write per
    /// file.
    static func removeRules(_ rules: [CoreRule], in file: FrameScope, label: String? = nil) -> FrameWrite {
        let text = label ?? (rules.count == 1 ? "Removed Rule \(rules[0].rule)" : "Removed \(NumberWording.plural(rules.count, "Rule"))")
        return FrameWrite(control: "removeRules:\(file.scope.rawValue):\(file.dir ?? "")", label: text, touches: [.rules(file)]) {
            .entry(try await $0.rulesRemoveMany(scope: file.scope, dir: file.dir, ids: rules.map(\.id)).entry)
        }
    }

    /// Keep (RD26): the finding leaves the count and moves under `N kept · Show`. Journaled, so Undo stops keeping it.
    static func keep(findingID: String, label: String = "Kept. It no longer counts in Inbox; Show Kept lists it.") -> FrameWrite {
        FrameWrite(control: "keep:\(findingID)", label: label, touches: [.kept]) { .entry(try await $0.findingsKeep(id: findingID).entry) }
    }

    static func unkeep(findingID: String, label: String = "Counted in Inbox again.") -> FrameWrite {
        FrameWrite(control: "unkeep:\(findingID)", label: label, touches: [.kept]) { .entry(try await $0.findingsUnkeep(id: findingID).entry) }
    }

    // MARK: Wording

    /// Registry names in a sentence ("Claude Code and Codex"); an id the registry does not list shows as itself.
    static func names(_ ids: [String], _ registry: [CoreRegistryCLI]) -> String {
        CLINames.sentence(ids.map { id in registry.first { $0.id == id }?.name ?? id })
    }

    /// ". Codex reads the same folder, so it has it too", or nothing.
    static func alsoReaders(_ ids: [String], _ registry: [CoreRegistryCLI]) -> String {
        guard !ids.isEmpty else { return "" }
        let one = ids.count == 1
        return ". \(names(ids, registry)) \(one ? "reads" : "read") the same folder, so \(one ? "it has" : "they have") it too"
    }

    /// "Removed s from Codex" (the mock's toggle toast); "Removed a copy of s" when no CLI lost it.
    static func removedLabel(_ name: String, lost: [String], _ registry: [CoreRegistryCLI]) -> String {
        lost.isEmpty ? "Removed a copy of \(name)" : "Removed \(name) from \(names(lost, registry))"
    }

    /// ". settings.json was edited": what a removal of Hooks or Rules adds (the mock's `edits`).
    static func edited(_ file: String) -> String { ". \(file) was edited" }

    /// One row by name ("pdf-extract"; with `namesKind`, "Skill pdf-extract", the mock's `removeIds`); otherwise each kind
    /// counted, in page order ("2 Skills, Subagent review and 3 Hooks").
    static func selection(_ rows: [FrameRow], namesKind: Bool = false) -> String {
        if rows.count == 1 && !namesKind { return rows[0].name }
        let kinds: [(CoreKind, String)] = [(.skill, "Skill"), (.agent, "Subagent"), (.hook, "Hook")]
        let parts = kinds.compactMap { kind, word -> String? in
            let of = rows.filter { $0.kind == kind }
            if of.isEmpty { return nil }
            return of.count == 1 ? "\(word) \(of[0].name)" : NumberWording.plural(of.count, word)
        }
        return CLINames.sentence(parts)
    }
}
