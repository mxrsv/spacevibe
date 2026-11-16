import Foundation

/// One tab's Answer card (V5-R53): the sentence, an optional verdict box naming the first row that needs the user, and how many
/// more rows are marked in the list. Derived from the query in one function per tab, never a fixed string.
struct ActivityAnswer: Equatable, Sendable {
    struct Verdict: Equatable, Sendable {
        /// The row the fix acts on: a session id or a failure id, as `ActivityQuery` names them.
        let targetID: String
        let title: String
        let text: String
        let small: String?
    }

    /// Nil while the report has not arrived: the card shows its skeleton.
    let sentence: String?
    let verdict: Verdict?
    /// Rows beyond the one named: "N more are marked in the list."
    let more: Int

    static let loading = ActivityAnswer(sentence: nil, verdict: nil, more: 0)

    private init(sentence: String?, verdict: Verdict?, more: Int) {
        self.sentence = sentence
        self.verdict = verdict
        self.more = more
    }

    // MARK: Running (V5-R70)

    /// "N waiting for you", or that nothing is. A session whose state the core cannot tell (a long tool run looks the same as an
    /// approval wait, and neither CLI logs the approval) means "nothing" is not known, so the sentence says that instead.
    static func running(_ query: ActivityQuery) -> ActivityAnswer {
        guard !query.isLoading else { return .loading }
        let waiting = query.sessions.filter(\.isWaiting)
        if let first = waiting.first {
            let session = first.session
            let place = session.project.map { "In \($0). " } ?? ""
            return ActivityAnswer(
                sentence: "\(waiting.count) waiting for you",
                verdict: Verdict(targetID: first.id, title: session.title, text: "\(session.cli.label) is waiting for your answer to a question.",
                                 small: "\(place)Answer it in the terminal. The log does not hold the question."),
                more: waiting.count - 1)
        }
        let unread = query.sessions.filter(\.isUnmeasurable)
        guard let first = unread.first else {
            return ActivityAnswer(sentence: "Nothing is waiting for you.", verdict: nil, more: 0)
        }
        let count = unread.count, open = query.sessions.count
        return ActivityAnswer(
            sentence: "Nothing is known to be waiting for you.",
            verdict: Verdict(targetID: first.id, title: first.session.title, text: first.session.stateReason,
                             small: "\(count) of \(open) open \(open == 1 ? "session" : "sessions") cannot be measured."),
            more: count - 1)
    }

    // MARK: Failed (V5-R71)

    static func failed(_ query: ActivityQuery) -> ActivityAnswer {
        guard !query.isLoading else { return .loading }
        let still = query.failures.filter(\.stillFailing)
        guard let first = still.first else {
            return ActivityAnswer(sentence: "No command is still failing.", verdict: nil, more: 0)
        }
        return ActivityAnswer(
            sentence: "\(still.count) still failing",
            verdict: Verdict(targetID: first.id, title: first.failure.title, text: first.failure.reason,
                             small: "\(first.failure.cli.label). No later run has passed."),
            more: still.count - 1)
    }
}

/// The figures and labels of the cards beside the Answers.
enum ActivityFigures {
    /// The `Right now` card (V5-R70's `Today`): what the report holds about the sessions open now. It has no tool-call count and
    /// no cost per day (G4), and its cost is per session over its whole life, so nothing here is called "today". Empty when
    /// no session is open, which drops the card.
    static func rightNow(_ query: ActivityQuery) -> [StatFigures.Figure] {
        let open = query.sessions
        guard !open.isEmpty else { return [] }
        var figures: [StatFigures.Figure] = []
        let costs = open.compactMap { $0.session.cost?.usd }
        if !costs.isEmpty {
            let covers = costs.count == open.count ? "open sessions" : "\(costs.count) of \(open.count) open sessions"
            figures.append(.init(value: ActivityFormat.cost(costs.reduce(0, +)), label: "estimated cost, \(covers)"))
        }
        if let oldest = open.compactMap({ $0.session.ageMs }).max() {
            figures.append(.init(value: ActivityFormat.span(oldest + query.elapsedMs), label: "longest-open session"))
        }
        return figures
    }

    // MARK: Failed

    /// "Oct 25 to Nov 7": the span of the failures listed, from the core's first and last times (the core reports no scan window).
    /// Nil when none has a time.
    static func failedRange(_ failures: [ActivityFailureItem], calendar: Calendar = .current) -> String? {
        let first = failures.compactMap { ActivityFormat.date($0.failure.first) }.min()
        let last = failures.compactMap { ActivityFormat.date($0.failure.last) }.max()
        guard let first, let last else { return nil }
        let from = ActivityFormat.shortDay(first, calendar: calendar), to = ActivityFormat.shortDay(last, calendar: calendar)
        return from == to ? from : "\(from) to \(to)"
    }

    /// The `Passed later` card: one sentence, nothing about a fix (one pass is not proof). Nil when no command passed later.
    static func passedLater(_ query: ActivityQuery) -> (count: Int, sentence: String)? {
        let passed = query.failures.filter { !$0.stillFailing }
        guard !passed.isEmpty else { return nil }
        let n = passed.count
        return (n, "\(ActivityFormat.plural(n, "command")) failed, then passed on a later run. One pass is not proof of a fix.")
    }

    /// What `Dismiss passed` says in its toast.
    static func dismissedPassedLabel(_ count: Int) -> String {
        "Dismissed \(ActivityFormat.plural(count, "command")) that passed later"
    }
}

/// The sentences of the row detail popovers (V5-R57).
enum ActivityWording {
    static let answerInTerminal = "Answer in the terminal. SpaceVibe only shows that it is waiting."

    static func sessionLines(_ item: ActivitySessionItem, elapsedMs: Double) -> [String] {
        let session = item.session
        var lines = [session.stateReason]
        if item.isWaiting { lines.append(answerInTerminal) }
        // A running session's log would not show an approval wait: say so in the core's words (an unmeasurable one says it above).
        if !item.isUnmeasurable, let limit = item.cannotSee { lines.append(limit) }
        if let ago = session.lastWriteAgoMs {
            lines.append("Last log write \(ActivityFormat.span(ago + elapsedMs)) ago.")
        } else if let age = session.ageMs {
            lines.append("Started \(ActivityFormat.span(age + elapsedMs)) ago.")
        }
        if let cost = session.cost {
            lines.append("\(ActivityFormat.cost(cost.usd)) so far, estimated at API prices. It is not what a subscription bills.")
        } else if let note = session.costNote {
            lines.append(note)
        }
        return lines
    }

    static func failureLines(_ item: ActivityFailureItem, now: Date) -> [String] {
        let failure = item.failure
        var lines = ["\(failure.reason). Failed \(item.timesText) in \(ActivityFormat.plural(failure.sessions, "session"))."]
        if let hook = failure.hook { lines.append("A \(hook.event) hook.") }
        if let first = failure.first, let last = failure.last {
            lines.append(failure.count > 1 ? "First \(ActivityFormat.clock(first, now: now)), last \(ActivityFormat.clock(last, now: now))."
                                           : "At \(ActivityFormat.clock(last, now: now)).")
        }
        lines.append(ActivityFormat.laterPass(failure, now: now).map { "\($0.prefix(1).uppercased())\($0.dropFirst())." } ?? "No later run has passed.")
        return lines
    }
}
