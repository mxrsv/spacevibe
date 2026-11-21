import Foundation

/// What the redesign's Limits page shows (spec `docs/specs/2026-11-20-spacevibe-redesign.md`: RD-R2 Limits, RD30, RD24,
/// RD33, RD-R10; the reference mock's `pageLimits` and `limitCard` in `src/e-clean-watch.js`). Pure: built from the store's
/// world (`FrameWorld`: the shown CLIs, every `WindowPace` and the hero Window the sidebar also reads, AR3), the state of the
/// `limits.read` source, the clock and the weekly countdown lead, so a test drives every state without a window.
///
/// - Hero: the Window that needs you (`FrameWorld.heroWindow`, `WindowPace.hero`), with why; `…` before the first read;
///   `?` Unmeasurable when no Window is measured.
/// - One card per CLI with limit data, in the registry's fixed order (RD-R10; D59 replaced). A CLI that keeps no limit record,
///   or says it cannot be measured, joins the one "Unmeasurable" line instead. A CLI that is not installed is not listed (the
///   mock's not-shown line "CLI chưa cài").
/// - Claude Code with no reading yet offers Copy Install Command for the status-line capture: the app copies, the owner runs
///   it (RD24, S-R4); a record that cannot be read offers Try Again.
/// - A Window row is judged by `WindowPace`: a reading older than 6 hours is shown but not judged, a Window past its reset
///   reads Unmeasurable, never 0%, and one with no length is not judged by pace but still counts at 5% left or less (RD30).
struct LimitsCards: Equatable {
    enum Hero: Equatable {
        /// `limits.read` has not answered yet.
        case reading
        /// No Window can be measured, or the read failed with nothing read before.
        case unmeasurable
        /// The Window that needs you: its share left, whole percent, and the label under it.
        case window(id: String, left: Int, label: String)
    }

    /// The tone of a Window's meter fill, its figure and its countdown clock (the mock's `col`).
    enum Tone: Equatable {
        /// Judged and on pace: `ink2`.
        case plain
        /// Shown, not judged: a reading older than 6 hours, or a Window past its reset (`ink3`).
        case muted
        case attention
        case critical
    }

    /// One Window of a CLI card.
    struct Row: Identifiable, Equatable {
        /// `cli:windowID`, the route's selection and the countdown pill's id (LC-R7).
        let id: String
        /// "5-hour", "Weekly", "Weekly · Fable".
        let name: String
        /// Whole percent left ("38%"; "0%" over the limit); nil when the Window is past its reset (Unmeasurable).
        let left: Int?
        /// 0 to 1: the meter's fill (0 for a Window past its reset, as the mock draws it).
        let share: Double
        /// 0 to 1: the share of the Window's time left, the pace tick; nil without a length or past its reset.
        let tick: Double?
        let tone: Tone
        /// The figure is drawn quiet (`ink3`): the reading is too old to judge.
        let isQuiet: Bool
        /// "Resets 17:40", or "Reset has passed".
        let reset: String
        /// The reset's clock time beside a running countdown ("17:40").
        let resetTime: String
        let resetsAt: Date
        /// How long before the reset the countdown runs (LC-R1); nil when this Window never counts.
        let countdownLead: TimeInterval?
        /// The quiet line under the reset: what the row says about pace, age or the limit.
        let note: Note
        /// The Window is judged behind pace or over the limit: its note stays while the clock counts (the mock's `cdown(w) && !w.behind`).
        let isBehind: Bool

        /// The clock's seconds left at `now`, nil when it does not count (LC-R1, LC-R2).
        func countdown(at now: Date) -> TimeInterval? {
            LimitsCountdown.remaining(until: resetsAt, lead: countdownLead, now: now)
        }

        /// The note, or nil while the clock counts and the Window is fine: the clock says it (the mock's `cdown(w) && !w.behind`).
        func shownNote(at now: Date) -> Note? {
            countdown(at: now) != nil && !isBehind ? nil : note
        }
    }

    /// A row's quiet line, with a severity glyph when it names a problem (RD-R16: glyph and colour).
    struct Note: Equatable {
        enum Mark: Equatable { case attention, critical }
        let mark: Mark?
        let text: String
    }

    /// One CLI's card.
    struct Card: Identifiable, Equatable {
        enum Body: Equatable {
            case windows([Row])
            /// The first read has not answered.
            case reading
            /// Claude Code has no reading yet: Copy Install Command (RD24).
            case noSnapshot
            /// The record could not be read: Try Again. Its Windows are Unmeasurable, not 0%.
            case unreadable
            /// The CLI keeps a record but nothing applies now ("Codex records no limit that applies right now.").
            case note(String)
        }

        let cliID: String
        let name: String
        /// "Pro", the plan the record names.
        let plan: String?
        /// "Status-line snapshot · 12 min ago".
        let source: String?
        let body: Body

        var id: String { cliID }
        /// The head says Unmeasurable instead of a source.
        var isUnmeasurable: Bool {
            switch body {
            case .noSnapshot, .unreadable, .note: true
            case .windows, .reading: false
            }
        }
        var rows: [Row] { if case .windows(let rows) = body { rows } else { [] } }
    }

    let hero: Hero
    let cards: [Card]
    /// CLIs without limit data, in the registry's order: the one "Unmeasurable" line (RD-R10).
    let unmeasurable: [String]
    /// The core's sentence when `limits.read` failed with nothing read before.
    let failure: String?

    /// Every row in page order: what ↑↓ and j/k move over.
    var rowIDs: [String] { cards.flatMap(\.rows).map(\.id) }

    /// The one "Unmeasurable" line's names: "Cursor CLI · opencode · Amp".
    var unmeasurableLine: String { unmeasurable.joined(separator: " · ") }

    // MARK: Building

    /// - `state`: the store's state of `limits.read` (nil before the store started it).
    init(world: FrameWorld, state: FrameSourceState?, now: Date, weeklyLead: WeeklyCountdownLead) {
        let limits = world.snapshot.limits
        let supported = world.clis.filter(\.supports.limits)
        var cards: [Card] = []
        var unmeasurable = world.clis.filter { !$0.supports.limits }.map(\.name)
        let failure: String?
        if case .failed(let message) = state, limits == nil { failure = message } else { failure = nil }

        if let limits {
            for cli in supported {
                guard let entry = limits.limits.first(where: { $0.cli.rawValue == cli.id }) else {
                    unmeasurable.append(cli.name)
                    continue
                }
                switch entry.state {
                case .notInstalled:
                    continue
                case .notMeasurable:
                    unmeasurable.append(cli.name)
                case .notRecorded:
                    let body: Card.Body = cli.id == CLIIdentity.claude.id
                        ? .noSnapshot : .note(LimitsWording.stateNote(entry)?.body ?? Self.noWindow(cli.name))
                    cards.append(Card(cliID: cli.id, name: cli.name, plan: nil, source: nil, body: body))
                case .unreadable:
                    cards.append(Card(cliID: cli.id, name: cli.name, plan: nil, source: nil, body: .unreadable))
                case .measured:
                    let rows = world.windows.filter { $0.cli == cli.id }
                        .map { Self.row($0, cli: entry.cli, readAt: entry.at, now: now, weeklyLead: weeklyLead) }
                    if rows.isEmpty, entry.windows.isEmpty {
                        unmeasurable.append(cli.name)
                        continue
                    }
                    cards.append(Card(cliID: cli.id, name: cli.name, plan: entry.plan.map(LimitsWording.planName),
                                      source: Self.source(entry, now: now),
                                      body: rows.isEmpty ? .note(Self.noWindow(cli.name)) : .windows(rows)))
                }
            }
        } else if failure == nil {
            // The first read: each CLI that can have limits waits in its own card (the mock's skeleton lines).
            cards = supported.map { Card(cliID: $0.id, name: $0.name, plan: nil, source: nil, body: .reading) }
        }

        self.cards = cards
        self.unmeasurable = unmeasurable
        self.failure = failure
        if limits == nil, failure == nil {
            hero = .reading
        } else if let window = world.heroWindow, let left = window.left {
            let name = world.clis.first { $0.id == window.cli }?.name ?? window.cli
            hero = .window(id: window.id, left: Self.whole(left), label: "\(name) · \(LimitsWording.name(window.window)) Window · \(Self.why(window))")
        } else {
            hero = .unmeasurable
        }
    }

    /// The hero's reason (the mock's `why`).
    static func why(_ window: WindowPace) -> String {
        if window.over > 0 { return "over the limit" }
        if window.isLow { return "almost used up" }
        if window.isBehind { return "using it faster than time passes" }
        return "lowest left"
    }

    static func noWindow(_ name: String) -> String { "\(name) records no limit that applies right now." }

    /// The sentence of a card whose record could not be read.
    static func unreadableText(_ name: String) -> String {
        "\(name)'s limit record could not be read, so its Windows are Unmeasurable, not 0%."
    }

    /// The empty card's sentence (RD24).
    static let noSnapshotText = "No status-line snapshot yet. Copy the install command, paste it in a terminal, and the next Claude Code prompt fills this in."

    /// "Status-line snapshot · 12 min ago", "Session log · 3 min ago".
    static func source(_ entry: CoreLimitsEntry, now: Date) -> String? {
        let name: String? = switch (entry.cli, entry.source) {
        case (_, .claudeStatusline): "Status-line snapshot"
        case (.claude, _): "Usage cache"
        case (.codex, _): "Session log"
        case (.gemini, _): nil
        }
        let age = entry.at.map { LimitsWording.readAge(at: Date(timeIntervalSince1970: $0), now: now) }
        let parts = [name, age].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func whole(_ share: Double) -> Int { Int(share.rounded()) }

    /// "4.5%": the share over the limit, one decimal as `WindowPace` keeps it, no trailing ".0".
    static func percent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))%" : String(format: "%.1f%%", rounded)
    }

    /// "Reading is 7 hours old", "Reading is 2 days old"; a reading with no time says so.
    static func age(readAt: Double?, now: Date) -> String {
        guard let readAt else { return "Reading has no time" }
        let hours = Int(max(0, now.timeIntervalSince1970 - readAt) / 3600)
        if hours < 48 { return "Reading is \(NumberWording.plural(hours, "hour")) old" }
        return "Reading is \(NumberWording.plural(hours / 24, "day")) old"
    }

    static func row(_ pace: WindowPace, cli: CoreLimitsCLI, readAt: Double?, now: Date, weeklyLead: WeeklyCountdownLead) -> Row {
        let window = pace.window
        let passed = pace.left == nil
        let span = LimitsWording.resetsIn(window, now: now) ?? ""
        let tone: Tone = passed || pace.isOld ? .muted : !pace.isBehind ? .plain : pace.severity == .critical ? .critical : .attention
        let note: Note
        if passed {
            note = Note(mark: nil, text: "Reading is older than the reset")
        } else if pace.isOld {
            let length = window.minutes == nil ? " · no window length" : ""
            note = Note(mark: .attention, text: "\(age(readAt: readAt, now: now))\(length) · \(span)")
        } else if pace.over > 0 {
            note = Note(mark: .critical, text: "Over by \(percent(pace.over)) · \(span)")
        } else if pace.isLow {
            note = Note(mark: .critical, text: "Almost used up · \(span)")
        } else if pace.timeLeft == nil {
            note = Note(mark: nil, text: "No window length, so no pace · \(span)")
        } else if pace.isBehind {
            note = Note(mark: pace.severity == .critical ? .critical : .attention, text: "Faster than time · \(span)")
        } else {
            note = Note(mark: nil, text: span)
        }
        let resetTime = LimitsWording.resetsAt(window, now: now)
        return Row(
            id: pace.id, name: LimitsWording.name(window), left: pace.left.map(whole),
            share: passed ? 0 : (pace.left ?? 0) / 100,
            tick: passed ? nil : pace.timeLeft.map { min(Self.tickCap, $0) / 100 },
            tone: tone, isQuiet: pace.isOld,
            reset: passed ? "Reset has passed" : "Resets \(resetTime)", resetTime: resetTime, resetsAt: window.resetsAtDate,
            countdownLead: passed ? nil : LimitsCountdown.lead(window, cli: cli, weekly: weeklyLead),
            note: note, isBehind: pace.isBehind)
    }

    /// The tick stays inside the track's end (the mock's `Math.min(98, w.tl)`).
    static let tickCap = 98.0

    /// The toast after Copy Install Command (the mock's `say`).
    static let copiedMessage = "Copied to the clipboard"

    /// The command Copy Install Command puts on the clipboard: the status-line capture's install line for the core inside the
    /// app bundle (`LimitsTab.captureCommand`). Copy only, never run (RD24, S-R4).
    @MainActor
    static func installCommand(helper: URL) -> String { LimitsTab.captureCommand(helper: helper, subcommand: "install") }
}
