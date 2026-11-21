import Foundation

/// The folder one member of a row lives in and which CLIs read that folder: the input RB-E2's readers map will fill (the
/// `folders` table of `loadout.rows` and each member's `folder` and `realPath`). Not on the wire yet, so the store leaves
/// every row without one, and each question below answers "unknown" rather than a guess (plan RB-E2: the core never guesses,
/// the shell derives).
struct MemberFolder: Equatable, Sendable {
    /// The folder (for a Hook, its file).
    let path: String
    /// The member's entry with links resolved: two members with the same `realPath` are one file (D53 counts files).
    let realPath: String
    /// The CLI whose own folder this is.
    let ownedBy: String
    /// Every registry CLI that reads this folder.
    let readBy: [String]
    /// The member is a link (owner `link`): removing it removes only the link, never the file behind it.
    let isLink: Bool
}

/// The readers of one row, keyed by member id. Port of the reference mock's `keysOf`, `losersOf`, `isVia` and `viaOf`
/// (`src/m-model.js`), over members instead of folder keys.
struct ItemReaders: Equatable, Sendable {
    let members: [String: MemberFolder]

    /// The members a CLI reads the row from. A CLI can read it from several folders: turning it off removes every one.
    func members(readBy cli: String) -> Set<String> {
        Set(members.filter { $0.value.readBy.contains(cli) }.keys)
    }

    /// What removing `chosen` takes away: a link member only itself; any other member every member with the same file.
    func expand(_ chosen: Set<String>) -> Set<String> {
        var out = chosen
        for id in chosen {
            guard let folder = members[id], !folder.isLink else { continue }
            out.formUnion(members.filter { !$0.value.isLink && $0.value.realPath == folder.realPath }.keys)
        }
        return out
    }

    /// Every CLI of `clis` that reads the row and ends up without it once `removed` is gone (RD-R11: the button counts every
    /// CLI that loses the item; a hidden CLI still counts, "Show guard").
    func losers(removing removed: Set<String>, among clis: [String]) -> [String] {
        clis.filter { cli in
            let read = members(readBy: cli)
            return !read.isEmpty && read.isSubset(of: removed)
        }
    }

    /// The CLIs whose own folder gives `cli` the row, when `cli` reads it only through another CLI's folder (RD31): such a
    /// logo is not a toggle and shows "via". Nil when `cli` has its own copy or does not read the row.
    func via(_ cli: String) -> [String]? {
        let read = members.values.filter { $0.readBy.contains(cli) }
        guard !read.isEmpty, !read.contains(where: { $0.ownedBy == cli }) else { return nil }
        var owners: [String] = []
        for folder in read.sorted(by: { $0.path < $1.path }) where !owners.contains(folder.ownedBy) { owners.append(folder.ownedBy) }
        return owners
    }

    /// The files of the row: distinct real paths of the members that are not links.
    func files(excluding removed: Set<String> = []) -> Set<String> {
        Set(members.filter { !removed.contains($0.key) && !$0.value.isLink }.map(\.value.realPath))
    }

    /// Turning a CLI off removes every member it reads the row from, expanded to the members that share their file.
    func turningOff(_ cli: String) -> Set<String> { expand(members(readBy: cli)) }

    /// Turning `cli` off would delete the row's last file, so its logo is not a toggle and `Remove…` is the explicit action
    /// (D53, counted by files, not by lit logos).
    func isLastCopy(turningOff cli: String) -> Bool {
        let removed = turningOff(cli)
        return !removed.isEmpty && files(excluding: removed).isEmpty
    }
}

/// An answer that needs the readers map: known, or not known until RB-E2 lands for this row.
enum ReadersAnswer<Value: Equatable & Sendable>: Equatable, Sendable {
    case known(Value)
    case unknown

    var value: Value? {
        if case .known(let value) = self { return value }
        return nil
    }
}
