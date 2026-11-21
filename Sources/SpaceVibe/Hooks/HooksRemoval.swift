import Foundation

/// The Hooks page's removals on the one write path (AR4): `FrameWrite.removeMany` (`loadout.removeMany`, RB-E4) for one row
/// and for a selection alike, so a selection is one Journal entry and one Undo. Hooks never ask for confirmation (the mock's
/// `MOCK.na` "Hooks never ask"): every removal has Undo. Only Claude Code members are named (Hooks are written only into
/// Claude Code), so a key Codex also holds keeps its Codex member.
enum HooksRemoval {
    /// The toolbar's `Remove N selected` control.
    static let selectedControl = "hooks:removeSelected"

    /// The selected row's `Remove from Claude Code` control: its pending state shows on that row's button.
    static func control(for row: HooksListRow) -> String { "hooks:remove:\(row.id)" }

    /// One write for these rows; nil when none of them is writable.
    static func write(_ rows: [HooksListRow], registry: [CoreRegistryCLI], control: String? = nil) -> FrameWrite? {
        let writable = rows.filter(\.isWritable)
        guard let first = writable.first else { return nil }
        return FrameWrite.removeMany(writable.map(\.row), members: Set(writable.flatMap(\.removalIDs)), registry: registry,
                                     control: control ?? (writable.count == 1 ? self.control(for: first) : selectedControl))
    }
}
