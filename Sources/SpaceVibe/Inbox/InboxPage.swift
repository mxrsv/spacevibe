import Foundation

/// One thing an Inbox row offers, in the order its buttons sit (the reference mock's `actOf` in `src/c-inbox-equip.js`): Keep
/// first, then the finding's own fix. Keep and Stop Keeping act on one row at a time (RD40); Remove has a checkbox beside it
/// for the bulk `Remove N` (RD41).
enum InboxAction: Equatable, Sendable {
    case keep
    case stopKeeping
    /// `asks`: the item's file is read by more than one CLI (or who reads it is not known), so the removal names every reader
    /// first ("Inferred, not decided": Inbox Remove); otherwise it goes at once with Undo.
    case remove(title: String, asks: Bool)
    /// Balance: copy the item into the pinned CLI that lacks it.
    case addTo(cli: String, title: String)
    /// A failing Hook: the command goes to the clipboard.
    case copyCommand(String)
    /// A Rule that allows a whole tool: its verdict becomes Ask in the file it sits in.
    case changeToAsk
    /// A waiting session: its host app comes to the front (RD36, GW5).
    case showTerminal(pid: Int)
    /// A waiting session with no host app (tmux, screen, ssh): the same button, disabled (RD36).
    case terminalNotFound

    /// Stable within a row (`FrameRowAction.id`).
    var id: String {
        switch self {
        case .keep: "keep"
        case .stopKeeping: "unkeep"
        case .remove: "remove"
        case .addTo: "addTo"
        case .copyCommand: "copyCommand"
        case .changeToAsk: "changeToAsk"
        case .showTerminal, .terminalNotFound: "showTerminal"
        }
    }

    var title: String {
        switch self {
        case .keep: "Keep"
        case .stopKeeping: "Stop Keeping"
        case .remove(let title, _), .addTo(_, let title): title
        case .copyCommand: "Copy Command"
        case .changeToAsk: "Change to Ask"
        case .showTerminal: "Show Terminal"
        case .terminalNotFound: "Terminal app not found"
        }
    }

    var isDestructive: Bool { if case .remove = self { true } else { false } }
    var isEnabled: Bool { self != .terminalNotFound }

    /// Keep and Stop Keeping are the quiet button beside the finding's own fix (the mock's `.rb.q`, RD46).
    var isQuiet: Bool { self == .keep || self == .stopKeeping }

    /// Keep and Stop Keeping share ⌘K (a row has one of them); Remove, Add to, Change to Ask, Copy Command and Show Terminal
    /// take the frame's shared row shortcuts (RD-R16).
    var shortcut: FrameShortcut? {
        switch self {
        case .keep, .stopKeeping: FrameShortcut("k")
        case .remove: .remove
        case .addTo: .addTo
        case .changeToAsk: .changeToAsk
        case .copyCommand: .copyCommand
        case .showTerminal, .terminalNotFound: .showTerminal
        }
    }
}

/// The glyph that says what kind of finding a row is (design notes §10.1): grey inside rows, because severity is shown once at
/// the group head (RD10); the waiting session keeps its session ink ("Inferred, not decided": Row state icons).
struct InboxRowGlyph: Equatable, Sendable {
    enum Ink: Equatable, Sendable { case neutral, sessionWaiting }

    let icon: FrameIcon
    var ink: Ink = .neutral
}

/// One Inbox row as the page draws it. Pure: every string is decided here, so the tests read what the user reads.
struct InboxRowModel: Identifiable, Equatable, Sendable {
    let finding: InboxFinding
    let glyph: InboxRowGlyph
    /// The name; a Hook's script or a Rule's text is drawn in mono.
    let title: String
    let isMono: Bool
    /// The quiet line under the name: kind, where, when.
    let sub: String
    /// The short evidence column ("Never ran", "2 failures in 7 days").
    let evidence: String
    /// A Clean up row: it has a checkbox and counts in `Remove N` (RD40). Never on a kept row.
    let isRemovable: Bool
    let isKept: Bool
    let actions: [InboxAction]

    var id: String { finding.id }

    /// What the toolbar's search reads: the drawn name, sub-line and evidence, and the subject's own name, description,
    /// command and path.
    var searchFields: [String?] {
        var fields: [String?] = [title, sub, evidence]
        switch finding.subject {
        case .row(let row), .balance(let row, _, _), .failingHook(let row, _): fields += row.searchFields
        case .rule(let rule, let file): fields += [rule.rule, InboxWording.settingsFile(file)]
        case .window: break
        case .session(let session): fields += [session.title, session.project]
        }
        return fields
    }
}

/// A job's head and rows (RD-R4): severity once at the head, `Select N Suggested` on Clean up only.
struct InboxGroupModel: Identifiable, Equatable, Sendable {
    let job: InboxJob
    let severity: GroupSeverity
    let rows: [InboxRowModel]
    /// The rows the head's pick ticks: every removable row of the group (each one is suggested by definition, RD26).
    let suggested: [String]

    var id: InboxJob { job }
    var title: String { job.title }
}

/// The band at the top of the list (RD-R13 scanning and error).
enum InboxBanner: Equatable, Sendable {
    case scanning
    /// Sources the Inbox needs could not be read and nothing was read before: the store's sentence.
    case failed(String)
    /// Some CLI folders could not be read: every figure of theirs is Unmeasurable, not zero (the mock's `codexUnread`).
    case unreadable(names: [String], paths: [String])

    var title: String {
        switch self {
        case .scanning: "Reading your CLI folders and usage logs…"
        case .failed: "Unmeasurable"
        case .unreadable(let names, _): "\(CLINames.sentence(names)) \(names.count == 1 ? "folder" : "folders") could not be read"
        }
    }

    var detail: String? {
        switch self {
        case .scanning: nil
        case .failed(let sentence): sentence
        case .unreadable(let names, let paths):
            "\(CLINames.sentence(paths)) could not be read, so every \(CLINames.sentence(names)) figure is Unmeasurable here, not zero."
        }
    }
}

/// The toolbar's slot: empty while scanning or with nothing to remove from, otherwise `Remove N` (RD-R2: the primary carries
/// the real number, FE-D3), disabled at zero.
enum InboxPrimary: Equatable, Sendable {
    case hidden
    case remove(count: Int)

    /// "Remove 104" (RD52: short enough never to be cut in the 196 slot); at zero "Select rows to remove" (the mock's
    /// `dstBtn`), "Select rows" in a list under 700 pt.
    func title(narrow: Bool) -> String? {
        guard case .remove(let count) = self else { return nil }
        if count == 0 { return narrow ? "Select rows" : "Select rows to remove" }
        return "Remove \(NumberWording.count(count))"
    }
}

/// Everything the Inbox shows for one world and one page state (RD-R4, RD-R13), the reference mock's `pageInbox`. Pure: the
/// view draws it, the tests read it. The hero counts exactly the open rows shown, and the sidebar reads the same
/// `FrameWorld.figure(for: .inbox)` (AR3), so the two cannot disagree.
struct InboxPage: Equatable, Sendable {
    let hero: PageHero.Figure
    let heroLabel: String
    /// The band above the list; an unreadable folder's band leaves the groups showing.
    let banner: InboxBanner?
    let groups: [InboxGroupModel]
    let kept: [InboxRowModel]
    let showsKept: Bool
    let primary: InboxPrimary
    /// The ticked removable rows among those shown, in page order: what `Remove N` takes.
    let ticked: [String]
    /// False while scanning or failed: the list is skeleton rows or nothing.
    let showsList: Bool
    /// The toolbar's search hides every open and kept row while there are some: "No findings match" with Clear Search.
    let isSearchMiss: Bool

    /// What the toolbar's search finds.
    static let searchItems = "findings"

    /// The open rows in page order.
    var rows: [InboxRowModel] { groups.flatMap(\.rows) }
    /// The rows the arrow keys walk and RD44 selects the first of: the open rows, then the kept ones while shown; none while
    /// scanning or failed, when no list is drawn.
    var order: [String] { showsList ? rows.map(\.id) + (showsKept ? kept.map(\.id) : []) : [] }
    /// "New findings land here." under the hero: nothing open, and the page is not scanning or failed.
    var isClear: Bool { showsList && groups.isEmpty && !isSearchMiss }

    func row(_ id: String?) -> InboxRowModel? {
        guard let id else { return nil }
        return rows.first { $0.id == id } ?? kept.first { $0.id == id }
    }

    /// - `figure`: `FrameWorld.figure(for: .inbox)` with the store's loading and failed sources.
    /// - `failure`: the store's sentence for a failed source, shown when `figure` is `.failed`.
    /// - `hasHost`: whether a session pid has a host app to bring forward (`HostAppResolver`), so a missing one is drawn
    ///   disabled before it is pressed.
    /// - `query`: the toolbar's search; the groups, the kept rows and what `Remove N` takes keep only the rows it
    ///   matches, while the hero counts every open finding (AR3).
    init(world: FrameWorld, figure: PageFigure, failure: String? = nil, ticked: Set<String> = [], showsKept: Bool = false,
         hasHost: (Int) -> Bool = { _ in true }, query: FrameSearchQuery = FrameSearchQuery(""), now: Date) {
        let wording = InboxWording(world: world, now: now)
        let everyOpen = world.findings.map { wording.row($0, kept: false, hasHost: hasHost) }
        let everyKept = world.keptFindings.map { wording.row($0, kept: true, hasHost: hasHost) }
        let open = query.filter(everyOpen, fields: \.searchFields)
        let keptRows = query.filter(everyKept, fields: \.searchFields)
        groups = Findings.groups(world.findings).compactMap { group in
            let rows = open.filter { $0.finding.job == group.job }
            guard !rows.isEmpty else { return nil }
            return InboxGroupModel(job: group.job, severity: group.job == .balance ? .none : GroupSeverity(group.severity), rows: rows,
                                   suggested: group.job == .cleanUp ? rows.filter(\.isRemovable).map(\.id) : [])
        }
        kept = keptRows
        self.showsKept = showsKept && !keptRows.isEmpty
        let removable = open.filter(\.isRemovable).map(\.id)
        self.ticked = removable.filter(ticked.contains)

        switch figure {
        case .pending:
            hero = .scanning
            heroLabel = "need you"
            banner = .scanning
            showsList = false
        case .failed:
            hero = .unmeasurable
            heroLabel = "Unmeasurable"
            banner = .failed(failure ?? "SpaceVibe could not read your CLI folders.")
            showsList = false
        default:
            let count = everyOpen.count
            hero = count == 0 ? .clear("Clear") : .value(NumberWording.count(count), unit: nil)
            heroLabel = count == 0 ? "Nothing needs you" : count == 1 ? "needs you" : "need you"
            banner = wording.unreadable
            showsList = true
        }
        primary = showsList && !everyOpen.isEmpty ? .remove(count: self.ticked.count) : .hidden
        // Rows were listed before the search (open ones, or kept ones while shown) and it hides them all.
        let listedBefore = !everyOpen.isEmpty || (showsKept && !everyKept.isEmpty)
        isSearchMiss = showsList && !query.isEmpty && listedBefore && open.isEmpty && (self.showsKept ? keptRows.isEmpty : true)
    }
}

extension GroupSeverity {
    init(_ severity: FindingSeverity) {
        switch severity {
        case .critical: self = .critical
        case .attention: self = .attention
        case .info: self = .none
        }
    }
}
