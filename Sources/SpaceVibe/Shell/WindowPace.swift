import Foundation

/// One limit Window judged by pace (RD30, RD-R4 "Watch"): the share left against the share of time left, not a fixed
/// threshold. Port of the reference mock's `windowsOf` (`src/m-model.js`).
///
/// - A Window at 5% left or less always counts, whatever its pace, and so does one over the limit.
/// - Pace is judged only once a tenth of the Window has passed, and only for a Window with a length.
/// - A reading older than 6 hours (`LimitsWording.staleAfter`) is shown but never judged; so is a Window that is not
///   current or not active (`LimitsWording.decisive` reads only current, active ones).
/// - Thresholds ("Inferred, not decided": Pace thresholds): attention when the share left is more than 3 points below the
///   share of time left; critical above 15 points, at 5% left or less, or over the limit.
struct WindowPace: Identifiable, Equatable, Sendable {
    enum Severity: Int, Comparable, Sendable {
        case ok, attention, critical
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }

    static let lowShare = 5.0
    static let attentionGap = 3.0
    static let criticalGap = 15.0
    /// The share of the Window that must have passed before pace is judged.
    static let judgedAfterElapsed = 10.0

    /// Registry id of the CLI.
    let cli: String
    let window: CoreLimitWindow
    /// Share left, 0 to 100, one decimal; nil when the Window is not current (its used share no longer describes it).
    let left: Double?
    /// Share used above 100, one decimal.
    let over: Double
    /// Share of the Window's time left, 0 to 100; nil without a length.
    let timeLeft: Double?
    /// The reading is older than 6 hours, or has no time.
    let isOld: Bool
    let isJudged: Bool
    let isBehind: Bool

    /// `cli:windowID`, the same id as a v5 Limits entry and `GlanceCountdownWindow.id`, so the countdown pill can route here.
    var id: String { "\(cli):\(window.id)" }
    var isLow: Bool { (left ?? .infinity) <= Self.lowShare }
    /// Time left minus share left: how far usage runs ahead of time.
    var gap: Double? { timeLeft.flatMap { time in left.map { time - $0 } } }

    var severity: Severity {
        guard isBehind else { return .ok }
        return over > 0 || isLow || (gap ?? 0) > Self.criticalGap ? .critical : .attention
    }

    /// The order of "needs you": over the limit first, then 5% or less left (lowest first), then furthest behind pace.
    var urgency: Double {
        if over > 0 { return 2000 + over }
        if isLow { return 1000 - (left ?? 0) }
        if isBehind { return gap ?? 0 }
        return -1
    }

    init(cli: String, window: CoreLimitWindow, readAt: Date?, now: Date) {
        self.cli = cli
        self.window = window
        let current = window.isCurrent(at: now)
        left = current ? Self.oneDecimal(max(0, 100 - window.usedPercent)) : nil
        over = current ? Self.oneDecimal(max(0, window.usedPercent - 100)) : 0
        if current, let minutes = window.minutes, minutes > 0 {
            let remaining = window.resetsAt - now.timeIntervalSince1970
            timeLeft = min(100, max(0, remaining / (Double(minutes) * 60) * 100))
        } else {
            timeLeft = nil
        }
        let old = readAt.map { LimitsWording.isStale(at: $0, now: now) } ?? true
        let shareLeft = left, overLimit = over, time = timeLeft
        let gap = time.flatMap { time in shareLeft.map { time - $0 } }
        let low = (shareLeft ?? .infinity) <= Self.lowShare
        let judged = current && window.active && !old && (gap != nil || overLimit > 0 || low)
        let elapsed = time.map { 100 - $0 }
        let pace = (gap ?? 0) > Self.attentionGap && (elapsed ?? 0) >= Self.judgedAfterElapsed
        isOld = old
        isJudged = judged
        isBehind = judged && (overLimit > 0 || low || pace)
    }

    /// The one rounding rule of a share (RD46: one decimal, as the mock's `r1`). `left` and `over` are kept in it, so the flag
    /// (`isLow`, `severity`) judges exactly the value the figure shows: "5% left" is never unflagged, "5.1%" never flagged.
    static func oneDecimal(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    /// A share as every new-frame surface shows it (the Limits hero and rows, the sidebar): one decimal, no trailing ".0"
    /// ("38%", "69.5%", "0%"), the mock's `pct`.
    static func percentText(_ share: Double) -> String { "\(shareText(share))%" }

    /// The number alone, for a figure whose unit is drawn apart (the hero's "77" before "% left").
    static func shareText(_ share: Double) -> String {
        let rounded = oneDecimal(share)
        let whole = rounded.rounded()
        return rounded == whole ? NumberWording.count(Int(whole)) : String(format: "%.1f", rounded)
    }
}

extension WindowPace {
    /// Every Window of every measured registry CLI with limits, in registry order. `limits.read` also holds a `gemini`
    /// entry the registry does not list: the registry is the one list of CLIs, so it is left out.
    static func windows(limits: CoreLimitsResult?, registry: [CoreRegistryCLI], now: Date) -> [WindowPace] {
        guard let limits else { return [] }
        return registry.filter(\.supports.limits).flatMap { cli -> [WindowPace] in
            guard let entry = limits.limits.first(where: { $0.cli.rawValue == cli.id }), entry.state == .measured else { return [] }
            let readAt = entry.at.map { Date(timeIntervalSince1970: $0) }
            return entry.windows.map { WindowPace(cli: cli.id, window: $0, readAt: readAt, now: now) }
        }
    }

    /// The registry CLIs without limit data, collapsed into one "Unmeasurable" line (RD-R10).
    static func unmeasurable(limits: CoreLimitsResult?, registry: [CoreRegistryCLI]) -> [CoreRegistryCLI] {
        registry.filter { cli in
            guard cli.supports.limits, let entry = limits?.limits.first(where: { $0.cli.rawValue == cli.id }) else { return true }
            return entry.state != .measured || entry.windows.isEmpty
        }
    }

    /// The Window that needs you: the most urgent one behind, else the lowest left (RD-R2 Limits, RD-A9: 5% left or less
    /// leads whatever its pace). Old readings and Windows that are not current never lead.
    static func hero(_ windows: [WindowPace]) -> WindowPace? {
        let measured = windows.filter { $0.left != nil && !$0.isOld }
        if let behind = measured.filter(\.isBehind).max(by: { $0.urgency < $1.urgency }) { return behind }
        return measured.min { ($0.left ?? 0) < ($1.left ?? 0) }
    }
}
