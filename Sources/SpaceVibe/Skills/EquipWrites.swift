import Foundation

/// The Skills and Subagents writes beside the frame's own (`FrameWrites.swift`). Every write path this page calls:
///
/// - `FrameWrite.copyTo` (`loadout.copyTo`): an off logo or tile, `Add to…`, and the copy step of "Copy to …, then remove".
/// - `FrameWrite.removeFrom` (`loadout.removeFrom`): an on logo or tile whose files only that CLI reads; the sheet's per-row
///   fallback when a row has no readers map.
/// - `FrameWrite.removeMembers` below (`loadout.removeMany`): a shared file confirmed in `SharedFileConfirmation`, a file
///   another row reaches (`ItemReaders.reachesOtherRows`), and the sheet's `Remove from…` / `Remove N selected…` / `Remove…`.
///
/// Each goes through `FrameWrites.perform` (AR4): pending at its control, the toast with Undo, the refused toast, the re-read.
extension FrameWrite {
    /// Removes exactly `members` as one change with one Undo (`loadout.removeMany`). Unlike `removeMany(_:members:)`, the ids
    /// may belong to other rows (a link to the same file under another name), which the engine requires to be named; `rows`
    /// only words the toast ("Removed pdf-extract from Codex and Amp").
    static func removeMembers(_ rows: [FrameRow], members: [String], registry: [CoreRegistryCLI], control: String) -> FrameWrite {
        let what = selection(rows)
        return FrameWrite(control: control, label: "Removed \(what)", touches: loadoutSources) { core in
            let result = try await core.loadoutRemoveMany(ids: members)
            let label = result.lost.isEmpty ? "Removed a copy of \(what)" : "Removed \(what) from \(names(result.lost, registry))"
            return .entryToast(result.entry, label: label)
        }
    }
}

/// The controls a write shows pending at (FE-L2) and that a second press while pending does nothing to.
enum EquipControl {
    static func toggle(_ rowID: String, _ cli: String) -> String { "equip.toggle:\(rowID):\(cli)" }
    static func shared(_ rowID: String) -> String { "equip.shared:\(rowID)" }
    static func sheet(_ page: FramePage) -> String { "equip.sheet:\(page.rawValue)" }
}
