import Foundation

/// Who reads one row and from where, from `loadout.rows`' readers map (`folders`, each member's `folder` and `realPath`;
/// inventory.md "Readers map"). The core never guesses and the shell only derives: via (RD31), the files of a row (D53)
/// and who loses the item (RD-R11). Port of the core's own proof of the rules (`readersOf`, `losersOf`, `filesOf`, `viaOf`
/// in `core/internal/inventory/readers-map_test.go`).
struct ItemReaders: Equatable, Sendable {
    struct Member: Equatable, Sendable {
        let id: String
        /// The path of the member's folder (for a Hook, its file).
        let folder: String
        /// The member's path with every link followed. A Hook is its own unit: its file holds other Hooks too.
        let realPath: String
        /// The member is a link (owner `link`): removing it takes only the link.
        let isLink: Bool
        /// The CLIs that read the member: its folder's readers plus those of every folder with the same real path.
        let readBy: [String]
        /// The readers of the member's own folder entry and its owner, for via: a link folder is judged as spelled.
        let folderReadBy: [String]
        let folderOwner: String
    }

    /// In the row's order.
    let members: [Member]
    /// Members of other rows that reach the file of a row member that is not a link: a link under another name (its
    /// `SKILL.md` has no name, so it is named after its folder) or the same folder spelled another way. Removing that file
    /// leaves them dangling, so the engine takes them along and refuses unless their readers are named (`expandRemoval`
    /// over every member in core/internal/mutate/member-removal.go). They never count as the row's own copies.
    let elsewhere: [Member]

    init(members: [Member], elsewhere: [Member] = []) {
        self.members = members
        self.elsewhere = elsewhere
    }

    /// Nil when a member names no folder of the table: a core before the readers map, or a folder it did not list. The
    /// answers are then unknown, never a guess. `loadoutItems` are every item of `loadout.rows` (`items` and `extraItems`),
    /// where the members of other rows that share a file with this one are found.
    init?(row: FrameRow, folders: [CoreReadersFolder], loadoutItems: [CoreInventoryItem] = []) {
        let byPath = Dictionary(folders.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        func readers(of folder: CoreReadersFolder) -> [String] {
            var out: [String] = []
            for other in folders where other.path == folder.path || other.realPath == folder.realPath {
                for cli in other.readBy where !out.contains(cli) { out.append(cli) }
            }
            return out
        }
        var built: [Member] = []
        for item in row.items {
            guard let path = item.folder, let realPath = item.realPath, let folder = byPath[path] else { return nil }
            built.append(Member(id: item.id, folder: path, realPath: realPath, isLink: item.owner == "link", readBy: readers(of: folder),
                                folderReadBy: folder.readBy, folderOwner: folder.ownedBy))
        }
        for hook in row.hooks {
            guard let path = hook.folder, let folder = byPath[path] else { return nil }
            built.append(Member(id: hook.id, folder: path, realPath: "hook:\(hook.id)", isLink: false, readBy: readers(of: folder),
                                folderReadBy: folder.readBy, folderOwner: folder.ownedBy))
        }
        guard !built.isEmpty else { return nil }
        let rowIDs = Set(row.items.map(\.id))
        let files = Set(row.items.filter { $0.owner != "link" }.compactMap(\.realPath))
        var others: [Member] = []
        for item in loadoutItems where !rowIDs.contains(item.id) {
            guard let realPath = item.realPath, files.contains(realPath) else { continue }
            guard let path = item.folder, let folder = byPath[path] else { return nil }
            others.append(Member(id: item.id, folder: path, realPath: realPath, isLink: item.owner == "link", readBy: readers(of: folder),
                                 folderReadBy: folder.readBy, folderOwner: folder.ownedBy))
        }
        members = built
        elsewhere = others
    }

    /// The members a CLI reads the row from. A CLI can read it from several folders: turning it off removes every one.
    func members(readBy cli: String) -> Set<String> {
        Set(members.filter { $0.readBy.contains(cli) }.map(\.id))
    }

    /// What removing `chosen` takes away: a link only itself; any other member its file, so every member with the same real
    /// path goes too, links included (they would dangle), in this row or `elsewhere`, as the engine does.
    func expand(_ chosen: Set<String>) -> Set<String> {
        let all = members + elsewhere
        var out = chosen
        for member in all where chosen.contains(member.id) && !member.isLink {
            out.formUnion(all.filter { $0.realPath == member.realPath }.map(\.id))
        }
        return out
    }

    /// Every CLI of `clis` that reads the row, or a link `elsewhere` to its file, and ends up with nothing of it once
    /// `removed` is gone (RD-R11: the button counts every CLI that loses the item; a hidden CLI still counts, "Show
    /// guard"). A CLI left with a dangling link loses, as the engine says when it refuses. `removed` is taken as given:
    /// pass it through `expand` first.
    func losers(removing removed: Set<String>, among clis: [String]) -> [String] {
        clis.filter { cli in
            let read = members(readBy: cli).union(elsewhere.filter { $0.readBy.contains(cli) }.map(\.id))
            return !read.isEmpty && read.isSubset(of: removed)
        }
    }

    /// Every CLI of `clis` that reads one of the files `removed` takes, the members `elsewhere` included: the readers the
    /// engine names when it refuses a removal that does not name them all (`loadout.removeFrom` 409). A Hook is its own file.
    func fileReaders(removing removed: Set<String>, among clis: [String]) -> [String] {
        let read = Set((members + elsewhere).filter { removed.contains($0.id) }.flatMap(\.readBy))
        return clis.filter(read.contains)
    }

    /// The removal reaches members of other rows: `loadout.removeFrom` names CLIs of this row only, so such a removal is
    /// refused unless it goes through `loadout.removeMany` with those member ids too.
    func reachesOtherRows(_ removed: Set<String>) -> Bool { elsewhere.contains { removed.contains($0.id) } }

    /// The CLIs whose folders give `cli` the row, when none of the folders it reads the row from is its own (RD31): such a
    /// logo is not a toggle and shows "via". Nil when `cli` has its own copy or does not read the row.
    func via(_ cli: String) -> [String]? {
        var owners: [String] = []
        for member in members where member.folderReadBy.contains(cli) {
            if member.folderOwner == cli { return nil }
            if !owners.contains(member.folderOwner) { owners.append(member.folderOwner) }
        }
        return owners.isEmpty ? nil : owners
    }

    /// The files of the row: the distinct real paths of the members not removed. D53 counts these, not lit logos.
    func files(excluding removed: Set<String> = []) -> Set<String> {
        Set(members.filter { !removed.contains($0.id) }.map(\.realPath))
    }

    /// Turning a CLI off removes every member it reads the row from, with the members that share their file.
    func turningOff(_ cli: String) -> Set<String> { expand(members(readBy: cli)) }

    /// Turning `cli` off would delete the row's last file, so its logo is not a toggle and `Remove…` is the explicit action
    /// (D53).
    func isLastCopy(turningOff cli: String) -> Bool {
        let removed = turningOff(cli)
        return !removed.isEmpty && files(excluding: removed).isEmpty
    }
}

/// An answer that needs the readers map: known, or not known because the core sent no map for this row.
enum ReadersAnswer<Value: Equatable & Sendable>: Equatable, Sendable {
    case known(Value)
    case unknown

    var value: Value? {
        if case .known(let value) = self { return value }
        return nil
    }
}
