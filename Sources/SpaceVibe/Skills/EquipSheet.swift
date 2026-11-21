import Foundation

/// The open per-CLI sheet (RD-R11 "Bulk and Remove…"): `Add to…`, `Remove from…`, `Remove N selected…` and an item's
/// `Remove…`. Holds the rows it acts on (fixed when it opened, so nothing hidden is touched) and the CLIs ticked. Nothing is
/// ticked at first.
struct EquipSheetState: Equatable, Sendable {
    var mode: PerCLISheetModel.Mode
    var rowIDs: [String]
    var ticked: Set<String> = []
}

/// What the sheet shows and writes, from the rows it holds. Pure: the sheet draws `model`, the page state runs `removal` or
/// `additions`, the tests check all three.
enum EquipSheet {
    /// The sheet's lines (the mock's `bulkSheet`):
    /// - Add: each shown CLI that has the kind, SpaceVibe can copy into, and lacks at least one of the rows; its line names
    ///   the folder the copy goes into and who else reads that folder.
    /// - Remove: each shown CLI that has at least one of the rows. A CLI holding none through its own folder is a "via" line,
    ///   shown and not tickable. A line names the folders the CLI reads the rows from, who else reads them, and every CLI
    ///   that loses a row when it is ticked (the button counts them all, a hidden CLI too).
    static func model(_ sheet: EquipSheetState, rows: [EquipListRow], kind: EquipKind, clis: [CoreRegistryCLI]) -> PerCLISheetModel {
        let items = sheet.rowIDs.compactMap { id in rows.first { $0.id == id } }
        let shown = clis.filter { $0.supports.supports(kind.kind) }
        let lines = sheet.mode == .add ? addLines(items, clis: shown) : removeLines(items, clis: shown)
        return PerCLISheetModel(mode: sheet.mode, itemName: items.count == 1 ? items[0].name : nil, itemCount: items.count,
                                noun: kind.noun, lines: lines, ticked: sheet.ticked,
                                removalLosers: sheet.mode == .remove ? removalLosers(sheet, items: items) : nil)
    }

    /// Every CLI, hidden ones included, that loses at least one row when the ticked CLIs' files go together, in the fixed
    /// order; nil when a row has no readers map (the lines' own answer stands).
    static func removalLosers(_ sheet: EquipSheetState, items: [EquipListRow]) -> [CLIIdentity]? {
        guard let registry = items.first?.readers.registry else { return nil }
        var lost: Set<String> = []
        for row in items {
            guard let readerMap = row.readers.readers else { return nil }
            var removed: Set<String> = []
            for cli in sheet.ticked where row.row.presence(cli) == .on && readerMap.via(cli) == nil { removed.formUnion(readerMap.turningOff(cli)) }
            guard !removed.isEmpty else { continue }
            lost.formUnion(row.readers.losers(removing: removed) ?? [])
        }
        return registry.filter { lost.contains($0.id) }.map { CLIIdentity(id: $0.id, name: $0.name) }
    }

    static func addLines(_ items: [EquipListRow], clis: [CoreRegistryCLI]) -> [PerCLISheetLine] {
        clis.compactMap { cli in
            let lacking = items.filter { $0.row.presence(cli.id) == .off }
            guard let readers = items.first?.readers, !lacking.isEmpty, readers.isCopyTarget(cli.id) else { return nil }
            let target = readers.folders.first { $0.ownedBy == cli.id && $0.kind == readers.kind && $0.copyTarget }
            let others = target.map { folder in folder.readBy.filter { $0 != cli.id } } ?? []
            return PerCLISheetLine(cli: identity(cli), folder: target.map { tilde($0.path) } ?? "\(cli.name)’s own folder",
                                   otherReaders: readers.names(others), itemCount: lacking.count)
        }
    }

    static func removeLines(_ items: [EquipListRow], clis: [CoreRegistryCLI]) -> [PerCLISheetLine] {
        let lines = clis.compactMap { cli -> PerCLISheetLine? in
            let lit = items.filter { $0.row.presence(cli.id) == .on }
            guard !lit.isEmpty else { return nil }
            let holds = lit.filter { $0.readers.readers?.via(cli.id) == nil }
            if holds.isEmpty {
                var through: [String] = []
                for row in lit { for id in row.readers.readers?.via(cli.id) ?? [] where !through.contains(id) { through.append(id) } }
                return PerCLISheetLine(cli: identity(cli), folder: "", via: lit[0].readers.names(through))
            }
            var folders: [String] = [], others: [String] = [], losers: [String] = []
            for row in holds {
                guard let readerMap = row.readers.readers, let removed = row.readers.turningOff(cli.id) else { continue }
                for member in readerMap.members where removed.contains(member.id) && member.readBy.contains(cli.id) {
                    let folder = tilde(member.folder)
                    if !folders.contains(folder) { folders.append(folder) }
                }
                for id in row.readers.fileReaders(removing: removed) ?? [] where id != cli.id && !others.contains(id) { others.append(id) }
                for id in row.readers.losers(removing: removed) ?? [] where !losers.contains(id) { losers.append(id) }
            }
            let names = holds[0].readers
            // The ticked CLI first, then the others that lose a row with it.
            if let index = losers.firstIndex(of: cli.id) { losers.insert(losers.remove(at: index), at: 0) }
            return PerCLISheetLine(cli: identity(cli), folder: folders.isEmpty ? "\(cli.name)’s folder" : folders.joined(separator: ", "),
                                   otherReaders: names.names(others), itemCount: holds.count,
                                   losers: losers.map { CLIIdentity(id: $0, name: names.name($0)) })
        }
        // Lines that can be ticked first, each group in the fixed order (the mock sorts holders first).
        return lines.filter(\.isTickable) + lines.filter { !$0.isTickable }
    }

    /// A removal the sheet confirms: one `loadout.removeMany` of exactly the members the ticked CLIs read each row from (with
    /// what shares their file), so one Undo restores it all. Nil when a row has no readers map: the page then asks the engine
    /// per row (`loadout.removeFrom`), which refuses a shared file it was not told about.
    static func removal(_ sheet: EquipSheetState, rows: [EquipListRow]) -> (rows: [FrameRow], members: [String])? {
        let items = sheet.rowIDs.compactMap { id in rows.first { $0.id == id } }
        var members: [String] = [], touched: [FrameRow] = []
        for row in items {
            guard let readerMap = row.readers.readers else { return nil }
            var removed: Set<String> = []
            for cli in sheet.ticked where row.row.presence(cli) == .on && readerMap.via(cli) == nil {
                removed.formUnion(readerMap.turningOff(cli))
            }
            guard !removed.isEmpty else { continue }
            touched.append(row.row)
            for id in row.readers.ordered(removed) where !members.contains(id) { members.append(id) }
        }
        return (touched, members)
    }

    /// The per-row fallback of `removal`: each row with the ticked CLIs that have it.
    static func removeFromEach(_ sheet: EquipSheetState, rows: [EquipListRow], order: [String]) -> [(row: FrameRow, clis: [String])] {
        sheet.rowIDs.compactMap { id in rows.first { $0.id == id } }.compactMap { row in
            let clis = order.filter { sheet.ticked.contains($0) && row.row.presence($0) == .on }
            return clis.isEmpty ? nil : (row.row, clis)
        }
    }

    /// An add the sheet confirms: per row, the ticked CLIs that lack it, in the fixed order. One `loadout.copyTo` each: the
    /// engine copies one item per call, so several rows are several writes, each with its Undo.
    static func additions(_ sheet: EquipSheetState, rows: [EquipListRow], order: [String]) -> [(row: FrameRow, targets: [String])] {
        sheet.rowIDs.compactMap { id in rows.first { $0.id == id } }.compactMap { row in
            let targets = order.filter { sheet.ticked.contains($0) && row.row.presence($0) == .off }
            return targets.isEmpty ? nil : (row.row, targets)
        }
    }

    /// The toast after `Add to…` when a row was refused: "Added 2 of 3; 1 refused: <the core's sentence>" as the partial
    /// toast (each row added keeps its Undo on the session stack); nothing added is the refused toast, the core's sentence
    /// alone for one row. Nil when nothing was refused: each row's own toast stands.
    static func addSummary(total: Int, refusals: [String]) -> (sentence: String, tone: ToastTone)? {
        guard let first = refusals.first else { return nil }
        if total == 1 { return (first, .danger) }
        let added = total - refusals.count
        let sentence = "Added \(NumberWording.count(added)) of \(NumberWording.count(total)); \(NumberWording.count(refusals.count)) refused: \(first)"
        return (sentence, added == 0 ? .danger : .partial)
    }

    /// The refused copy of "Copy to …, then remove": the core's sentence, then that the item stayed.
    static func copyRefused(_ name: String, reason: String) -> String {
        "\(CleanWording.sentence(reason)) \(name) was not removed."
    }

    private static func identity(_ cli: CoreRegistryCLI) -> CLIIdentity { CLIIdentity(id: cli.id, name: cli.name) }
    private static func tilde(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }
}
