import Foundation

/// The lock line of a locked log or cache row and its popover (the mock's `lockNote`): the sessions that hold it by name,
/// and the core's sentence (CL-R5 "the disabled control says why").
struct CleanLockNote: Identifiable, Equatable, Sendable {
    struct Session: Identifiable, Equatable, Sendable {
        let id: String
        let cli: String
        let title: String
        let pid: Int
    }

    /// `logs:<cli>` or `caches:<cli>`: one popover per locked section of a CLI.
    let id: String
    /// "In use by 2 sessions", "In use", "Process check failed".
    let title: String
    let sessions: [Session]
    /// The core's sentence, then what to do about it.
    let footnote: String

    init(id: String, lock: CleanLock, isCache: Bool, activity: CoreActivityReport?) {
        self.id = id
        let byID = Dictionary((activity?.sessions ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        sessions = lock.sessionIDs.compactMap { byID[$0] }.map { Session(id: $0.id, cli: $0.cli.rawValue, title: $0.title, pid: $0.pid) }
        switch lock.reason {
        case .sessions:
            title = "In use by \(NumberWording.plural(lock.sessionIDs.count, "session"))"
            let caches = isCache ? " Caches stay locked while any session of this CLI is open, idle ones too." : ""
            footnote = "\(CleanWording.sentence(lock.message))\(caches) Stopping them is in Activity."
        case .processes:
            title = "In use"
            footnote = CleanWording.sentence(lock.message)
        case .processUnknown:
            title = "Process check failed"
            footnote = CleanWording.sentence(lock.message)
        }
    }
}

/// One row of Clean, as the page draws it. Pure: every string is decided here.
struct CleanRowModel: Identifiable, Equatable, Sendable {
    enum Section: Equatable, Sendable { case agents, logs, caches }

    /// The third column (the mock's `190px`): where an item is loaded, the lock, or the age control.
    enum Detail: Equatable, Sendable {
        case none
        /// Up to three logos, then "+N".
        case clis([String], more: Int)
        case lock(CleanLockNote)
        /// The ages that hold a log and the one shown.
        case ages([Int], selected: Int)
    }

    /// The size column: a figure, a word, or a skeleton while measuring.
    enum Size: Equatable, Sendable {
        case bytes(String)
        case note(String)
        case quiet(String)
        case pending
    }

    let id: String
    let section: Section
    /// A log or cache row leads with its CLI's logo.
    let cli: String?
    let title: String
    let isMono: Bool
    let sub: String?
    let detail: Detail
    let size: Size
    /// It may be ticked: not locked, not read-only, not unreadable, and the page is not measuring or moving.
    let isOpen: Bool

    /// What VoiceOver reads: the name, the sub-line, the size and why it cannot be ticked.
    var spoken: String {
        let size: String? = switch self.size {
        case .bytes(let text), .note(let text), .quiet(let text): text
        case .pending: "measuring"
        }
        var parts = [title] + [sub, size].compactMap { $0 }
        if case .lock(let note) = detail { parts.append(note.title) }
        return parts.joined(separator: ", ")
    }
}

/// A section of Clean (the mock's `section`): its head with `Select N Suggested` or `Clear Selection`, and its rows. A
/// section with no row is left out; while the first scan runs it is skeleton rows.
struct CleanSectionModel: Identifiable, Equatable, Sendable {
    enum Pick: Equatable, Sendable {
        case none
        case select(Int)
        case clear
    }

    let section: CleanRowModel.Section
    let title: String
    let rows: [CleanRowModel]
    /// What the head's pick ticks or clears.
    let suggested: [String]
    let pick: Pick
    /// Skeleton rows instead of `rows` (the first scan).
    let skeletons: Int

    var id: CleanRowModel.Section { section }
}

/// The band at the top of the list (RD-R13 scanning and error, RD-R17 Honesty).
enum CleanBanner: Equatable, Sendable {
    /// `clean.scan` could not be read and nothing was read before: the core's sentence.
    case failed(String)
    /// A later scan failed: the rows are the last ones read.
    case rescanFailed(String)
    /// Some CLI folders could not be read: their figures are Unmeasurable, not zero.
    case unreadable(names: [String], paths: [String])
    /// The usage scan's problems (an unreadable usage archive): the logs Clean moved are not counted.
    case usage([String])
    /// `clean.scan`'s problems: what Clean could not settle, such as the staging folder of an interrupted move.
    case stranded([String])

    var title: String {
        switch self {
        case .failed: "Unmeasurable"
        case .rescanFailed: "Clean could not measure again"
        case .unreadable(let names, _): "\(CLINames.sentence(names)) \(names.count == 1 ? "folder" : "folders") could not be read"
        case .usage: "Some usage totals are not counted"
        case .stranded: "An interrupted move left files behind"
        }
    }

    var detail: String {
        switch self {
        case .failed(let sentence), .rescanFailed(let sentence): sentence
        case .unreadable(let names, let paths):
            "\(CLINames.sentence(paths)) could not be read, so every \(CLINames.sentence(names)) figure is Unmeasurable here, not zero."
        case .usage(let problems), .stranded(let problems): problems.map(CleanWording.sentence).joined(separator: " ")
        }
    }

    /// A failure the user can retry: Try Again.
    var retries: Bool {
        switch self {
        case .failed, .rescanFailed, .unreadable: true
        case .usage, .stranded: false
        }
    }

    var isCritical: Bool { if case .failed = self { true } else { false } }
}

/// The toolbar's slot (RD-R2: the primary carries the real number, FE-D3): `Remove 1.02 GB` while bytes are selected, else
/// `Remove N selected`, disabled with "Select rows to remove" at zero; `Measuring…` and `Moving 58%` disabled with their
/// spinner; nothing when the page is Tidy.
enum CleanPrimary: Equatable, Sendable {
    case hidden
    case measuring
    case moving(percent: Int?)
    case remove(bytes: Int64, count: Int)

    func title(narrow: Bool) -> String {
        switch self {
        case .hidden: ""
        case .measuring: "Measuring…"
        case .moving(let percent): percent.map { "Moving \($0)%" } ?? "Moving…"
        case .remove(let bytes, let count):
            count == 0 ? (narrow ? "Select rows" : "Select rows to remove")
                : bytes > 0 ? "Remove \(NumberWording.bytes(bytes))" : "Remove \(NumberWording.count(count)) selected"
        }
    }

    var isEnabled: Bool { if case .remove(_, let count) = self { count > 0 } else { false } }
    var isLoading: Bool {
        switch self {
        case .measuring, .moving: true
        case .hidden, .remove: false
        }
    }
}

/// The band under the hero while a move runs: the progress at the control that started it, and Cancel.
struct CleanMoveBand: Equatable, Sendable {
    let share: Double
    let text: String
    let isCancelling: Bool

    static let note = "Cancel stops before the next file. What already moved stays in the Trash, and Undo puts it back."

    /// `reading` archives the usage of the picked logs first (CL-R3), then `moving` renames; before the first note, nothing.
    init(progress: CoreCleanProgress?, selectedBytes: Int64, isCancelling: Bool) {
        self.isCancelling = isCancelling
        guard let progress, progress.total > 0 else {
            share = 0
            text = "Starting…"
            return
        }
        share = Double(progress.done) / Double(progress.total)
        if progress.phase == "reading" {
            text = "Keeping the usage of \(NumberWording.count(progress.done)) of \(NumberWording.plural(progress.total, "log"))"
        } else {
            text = "Moving \(NumberWording.count(progress.done)) of \(NumberWording.plural(progress.total, "file")) · "
                + "\(NumberWording.bytes(progress.bytes)) of \(NumberWording.bytes(max(selectedBytes, progress.bytes)))"
        }
    }

    /// The toolbar's percent: only once files move.
    static func percent(_ progress: CoreCleanProgress?) -> Int? {
        guard let progress, progress.phase == "moving", progress.total > 0 else { return nil }
        return Int((Double(progress.done) / Double(progress.total) * 100).rounded(.down))
    }
}
