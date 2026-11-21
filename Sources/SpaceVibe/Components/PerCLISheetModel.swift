import Foundation

/// One CLI's line in the per-CLI sheet (RD-R11 "Bulk and Remove…"; the mock's `bulkSheet` row): the CLI, the real folder the
/// write touches (the source folder for a removal, the target folder for an add), who else reads that folder, how many of the
/// picked items it holds (remove) or lacks (add), and, for a removal, every CLI that loses the items when this line is ticked
/// (itself included; the shell derives it from the readers map, RB-E2).
struct PerCLISheetLine: Hashable, Identifiable, Sendable {
    let cli: CLIIdentity
    let folder: String
    var otherReaders: [String] = []
    var itemCount: Int = 1
    /// Remove only: the CLI has the items only through these CLIs' folders (RD31). The line is shown, not tickable.
    var via: [String] = []
    /// Remove only: every CLI that loses the items if this line is ticked, itself first.
    var losers: [CLIIdentity] = []

    var id: String { cli.id }
    var isTickable: Bool { via.isEmpty }

    /// The quiet line under the name: the folder and who else reads it, or why it cannot be ticked.
    var detail: String {
        if !via.isEmpty { return "Via \(CLINames.sentence(via))’s folder: removed only with it" }
        guard !otherReaders.isEmpty else { return folder }
        return "\(folder) · also read by \(CLINames.sentence(otherReaders))"
    }
}

/// What the per-CLI sheet says and does (`Add to…` / `Remove from…`). Pure: the sheet draws it, the tests check the button.
struct PerCLISheetModel: Hashable, Sendable {
    enum Mode: Hashable, Sendable { case add, remove }

    var mode: Mode
    /// The item's name when one item is picked; nil for several.
    var itemName: String?
    var itemCount: Int
    /// The kind, singular ("Skill", "Subagent").
    var noun: String
    var lines: [PerCLISheetLine]
    /// Nothing is ticked at first (RD-R11, RD41).
    var ticked: Set<String> = []

    // MARK: Derived

    /// The ticked lines that can be ticked, in line order.
    var selected: [PerCLISheetLine] { lines.filter { ticked.contains($0.id) && $0.isTickable } }

    /// Every CLI the write changes: the ticked CLIs for an add; for a removal every CLI that loses an item, readers of a
    /// shared folder included, each once, in the order first met.
    var affected: [CLIIdentity] {
        switch mode {
        case .add: return selected.map(\.cli)
        case .remove:
            var seen = Set<String>(), result: [CLIIdentity] = []
            for line in selected {
                for cli in (line.losers.isEmpty ? [line.cli] : line.losers) where seen.insert(cli.id).inserted { result.append(cli) }
            }
            return result
        }
    }

    /// The CLIs that lose the items without being ticked: named in the sheet's warning.
    var alsoAffected: [CLIIdentity] {
        let picked = Set(selected.map(\.id))
        return affected.filter { !picked.contains($0.id) }
    }

    var canConfirm: Bool { !selected.isEmpty }

    var verb: String { mode == .add ? "Add" : "Remove" }
    var preposition: String { mode == .add ? "to" : "from" }

    /// "Add pdf-extract to…", "Remove 3 Skills from…".
    var title: String {
        let what = itemCount == 1 ? (itemName ?? noun) : "\(NumberWording.count(itemCount)) \(noun)s"
        return "\(verb) \(what) \(preposition)…"
    }

    /// "Select a CLI" until a line is ticked; then the count of every CLI that changes: "Remove from 3 CLIs", "Add 3 to 2 CLIs".
    var confirmTitle: String {
        guard canConfirm else { return "Select a CLI" }
        let count = itemCount == 1 ? "" : "\(NumberWording.count(itemCount)) "
        return "\(verb) \(count)\(preposition) \(NumberWording.plural(affected.count, "CLI"))"
    }

    /// "Shared files: this also removes it for Cursor CLI and Amp."; nil when no other CLI is touched.
    var sharedWarning: String? {
        guard mode == .remove, !alsoAffected.isEmpty else { return nil }
        return "Shared files: this also removes \(itemCount == 1 ? "it" : "them") for \(CLINames.sentence(alsoAffected))."
    }

    /// Ticking a line that cannot be ticked does nothing.
    func toggling(_ id: String) -> PerCLISheetModel {
        guard let line = lines.first(where: { $0.id == id }), line.isTickable else { return self }
        var next = self
        if next.ticked.contains(id) { next.ticked.remove(id) } else { next.ticked.insert(id) }
        return next
    }

    /// Switching between Add and Remove clears the ticks: the lines mean something else.
    func switching(to mode: Mode, lines: [PerCLISheetLine]) -> PerCLISheetModel {
        PerCLISheetModel(mode: mode, itemName: itemName, itemCount: itemCount, noun: noun, lines: lines)
    }
}
