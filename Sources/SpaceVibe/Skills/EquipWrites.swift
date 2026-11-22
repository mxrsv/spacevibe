import Foundation

/// The Skills and Subagents writes beside the frame's own (`FrameWrites.swift`). Every write path this page calls:
///
/// - `FrameWrite.copyTo` (`loadout.copyTo`): an off logo or tile.
/// - `FrameWrite.removeFrom` (`loadout.removeFrom`): an on logo or tile whose files only that CLI reads.
/// - `FrameWrite.removeMembers` below (`loadout.removeMany`): a shared file confirmed in `SharedFileConfirmation`, a file
///   another row reaches (`ItemReaders.reachesOtherRows`), and the sheet's `Remove from…` / `Remove N…` / `Remove…`.
/// - `FrameWrite.addEach`, `copyThenRemove` and `removeFromEach` below: one press that needs several engine calls (the sheet's
///   `Add to…` for several rows, "Copy to …, then remove", the sheet's per-row fallback), run as ONE write with one toast
///   whose one Undo reverts everything the press wrote, newest first (RD56, `FrameWriteOutcome.entries`).
///
/// Each goes through `FrameWrites.start` (AR4): pending at its control before the press returns, the toast with Undo, the
/// refused toast, the re-read.
extension FrameWrite {
    /// Removes exactly `members` as one change with one Undo (`loadout.removeMany`). Unlike `removeMany(_:members:)`, the ids
    /// may belong to other rows (a link to the same file under another name), which the engine requires to be named; `rows`
    /// only words the toast ("Removed pdf-extract from Codex and Amp").
    ///
    /// `shared`: the removal a `SharedFileConfirmation` confirmed, worded as the mock's: "Removed pdf-extract for Codex and
    /// Amp".
    static func removeMembers(_ rows: [FrameRow], members: [String], registry: [CoreRegistryCLI], control: String,
                              shared: Bool = false) -> FrameWrite {
        let what = selection(rows)
        return FrameWrite(control: control, label: "Removed \(what)", touches: loadoutSources, rows: Set(rows.map(\.id))) { core in
            let result = try await core.loadoutRemoveMany(ids: members)
            return .entryToast(result.entry, label: removedMembers(what, lost: result.lost, registry: registry, shared: shared, copiedTo: []))
        }
    }

    /// The toast of a members removal once the core named who lost it: "Removed a copy of s" when nobody did, else "Removed s
    /// from Codex", a confirmed shared file "Removed s for Codex and Amp", after a copy "Copied s to Claude Code, then removed
    /// it for Codex and Amp".
    static func removedMembers(_ what: String, lost: [String], registry: [CoreRegistryCLI], shared: Bool, copiedTo: [String]) -> String {
        guard !lost.isEmpty else { return "Removed a copy of \(what)" }
        let who = names(lost, registry)
        if !copiedTo.isEmpty { return "Copied \(what) to \(names(copiedTo, registry)), then removed it for \(who)" }
        return shared ? "Removed \(what) for \(who)" : "Removed \(what) from \(who)"
    }

    /// "Copy to …, then remove" (RD-R11, RD56): the copy into `targets` first, then exactly `members`, as one press with one
    /// toast and one Undo that reverts the removal, then the copy. A refused copy stops before the removal and is the
    /// refusal ("… commit-helper was not removed."); a refused removal after the copy landed is the partial toast, with Undo
    /// for the copy.
    static func copyThenRemove(_ row: FrameRow, copyTo targets: [String], members: [String], registry: [CoreRegistryCLI],
                               control: String) -> FrameWrite {
        let copied = names(targets, registry)
        return FrameWrite(control: control, label: "Copied \(row.name) to \(copied)", touches: loadoutSources, rows: [row.id]) { core in
            let copy: CoreJournalEntry
            do {
                copy = try await core.loadoutCopyTo(id: copySource(row), targets: targets).entry
            } catch {
                throw CoreError(EquipSheet.copyRefused(row.name, reason: sentence(of: error)), status: (error as? CoreError)?.status ?? 409)
            }
            do {
                let result = try await core.loadoutRemoveMany(ids: members)
                return .entries([copy, result.entry],
                                label: removedMembers(row.name, lost: result.lost, registry: registry, shared: true, copiedTo: targets),
                                isPartial: false)
            } catch {
                return .entries([copy], label: "Copied \(row.name) to \(copied), but it was not removed: \(CleanWording.sentence(sentence(of: error)))",
                                isPartial: true)
            }
        }
    }

    /// The sheet's `Add to…` (RD56): one `loadout.copyTo` per row that lacks it (the engine copies one item per call), as one
    /// press with one toast and one Undo that reverts every copy, newest first. A refused row never stops the others: "Added 2
    /// of 3; 1 refused: <the core's sentence>" is the partial toast, with Undo for what was added; nothing added is the
    /// refusal (`EquipSheet.addSummary`).
    static func addEach(_ steps: [(row: FrameRow, targets: [String])], registry: [CoreRegistryCLI], control: String) -> FrameWrite {
        let rows = steps.map(\.row)
        var targets: [String] = []
        for step in steps { for cli in step.targets where !targets.contains(cli) { targets.append(cli) } }
        let added = "Added \(selection(rows)) to \(names(targets, registry))"
        return FrameWrite(control: control, label: added, touches: loadoutSources, rows: Set(rows.map(\.id))) { core in
            var entries: [CoreJournalEntry] = [], refusals: [String] = [], readers: [String] = []
            for step in steps {
                do {
                    let result = try await core.loadoutCopyTo(id: copySource(step.row), targets: step.targets)
                    entries.append(result.entry)
                    for id in result.alsoReaders where !readers.contains(id) { readers.append(id) }
                } catch {
                    refusals.append(sentence(of: error))
                }
            }
            if let summary = EquipSheet.addSummary(total: steps.count, refusals: refusals) {
                if entries.isEmpty { throw CoreError(summary.sentence, status: 409) }
                return .entries(entries, label: summary.sentence, isPartial: true)
            }
            return .entries(entries, label: added + alsoReaders(readers, registry), isPartial: false)
        }
    }

    /// The sheet's removal when a row has no readers map (`EquipSheet.removeFromEach`): one `loadout.removeFrom` per row, as
    /// one press with one toast and one Undo (RD56). The first refusal stops; what was removed before it keeps its Undo in the
    /// partial toast.
    static func removeFromEach(_ steps: [(row: FrameRow, clis: [String])], registry: [CoreRegistryCLI], control: String) -> FrameWrite {
        let rows = steps.map(\.row)
        return FrameWrite(control: control, label: "Removed \(selection(rows))", touches: loadoutSources, rows: Set(rows.map(\.id))) { core in
            var entries: [CoreJournalEntry] = [], lost: [String] = [], removed: [FrameRow] = []
            for step in steps {
                do {
                    let result = try await core.loadoutRemoveFrom(id: removeSource(step.row), clis: step.clis)
                    entries.append(result.entry)
                    removed.append(step.row)
                    for id in result.lost where !lost.contains(id) { lost.append(id) }
                } catch {
                    guard !entries.isEmpty else { throw error }
                    let head = removedLabel(selection(removed), lost: lost, registry)
                    return .entries(entries, label: "\(head); \(NumberWording.count(steps.count - removed.count)) not removed: "
                                        + CleanWording.sentence(sentence(of: error)), isPartial: true)
                }
            }
            return .entries(entries, label: removedLabel(selection(removed), lost: lost, registry), isPartial: false)
        }
    }

    /// A refusal's sentence, safe to show (S-R3: a `CoreError`'s message, never another error's description).
    private static func sentence(of error: Error) -> String { (error as? CoreError)?.message ?? CoreError.unexpectedMessage }
}

/// The controls a write shows pending at (FE-L2) and that a second press while pending does nothing to.
enum EquipControl {
    static func toggle(_ rowID: String, _ cli: String) -> String { "equip.toggle:\(rowID):\(cli)" }
    static func shared(_ rowID: String) -> String { "equip.shared:\(rowID)" }
    static func sheet(_ page: FramePage) -> String { "equip.sheet:\(page.rawValue)" }
}
