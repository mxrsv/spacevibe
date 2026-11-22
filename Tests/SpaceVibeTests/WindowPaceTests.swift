import Foundation
import Testing
@testable import SpaceVibe

/// Pace and the Limits hero (RD30, RD-R4 "Watch", RD-A9; "Inferred, not decided": Pace thresholds 3 / 15 points).
@Suite("Window pace")
struct WindowPaceTests {
    typealias D = FrameTestData

    private func pace(_ entry: CoreLimitsEntry) -> WindowPace {
        WindowPace.windows(limits: CoreLimitsResult(limits: [entry]), registry: D.registry, now: D.now)[0]
    }

    @Test("on pace: share left is not more than 3 points below the share of time left")
    func onPace() {
        // Half the time left, 52% left: usage is behind time, fine.
        let w = pace(D.limits(used: 48, minutesLeft: 150))
        #expect(w.isJudged && !w.isBehind && w.severity == .ok)
        #expect(w.left == 52 && w.timeLeft == 50)
    }

    @Test("faster than time: attention above 3 points, critical above 15")
    func behind() {
        let a = pace(D.limits(used: 55, minutesLeft: 150))
        #expect(a.isBehind && a.severity == .attention && a.gap == 5)
        let c = pace(D.limits(used: 70, minutesLeft: 150))
        #expect(c.isBehind && c.severity == .critical)
    }

    @Test("pace is judged only once a tenth of the Window has passed")
    func tenth() {
        // 95% of the time left, 80% left: 15 points behind, but only 5% of the Window has passed.
        let early = pace(D.limits(used: 20, minutesLeft: 285))
        #expect(!early.isBehind)
        let later = pace(D.limits(used: 20, minutesLeft: 270))
        #expect(later.isBehind)
    }

    @Test("5% left or less and over the limit always count, critical, even before a tenth has passed (RD30)")
    func lowAndOver() {
        let low = pace(D.limits(used: 95, minutesLeft: 295))
        #expect(low.isBehind && low.isLow && low.severity == .critical)
        let over = pace(D.limits(used: 104.5, minutesLeft: 295))
        #expect(over.isBehind && over.over == 4.5 && over.left == 0 && over.severity == .critical)
    }

    @Test("a Window without a length is not judged by pace, but still counts at 5% left or less")
    func noLength() {
        #expect(!pace(D.limits(used: 80, minutes: nil)).isBehind)
        #expect(pace(D.limits(used: 96, minutes: nil)).isBehind)
    }

    @Test("a reading older than 6 hours, an inactive Window or one past its reset is shown but never judged")
    func neverJudged() {
        let old = pace(D.limits(used: 99, readAgo: 7 * 3600))
        #expect(old.isOld && !old.isJudged && !old.isBehind)
        #expect(!pace(D.limits(used: 99, active: false)).isJudged)
        let passed = pace(D.limits(used: 99, minutesLeft: -5))
        #expect(passed.left == nil && !passed.isJudged)
    }

    @Test("the hero is over the limit first, then 5% or less, then furthest behind, else the lowest left (RD-A9)")
    func hero() {
        let behind = pace(D.limits(id: "a", used: 70, minutesLeft: 150))
        let low = pace(D.limits(id: "b", used: 96, minutesLeft: 295))
        let over = pace(D.limits(id: "c", used: 101, minutesLeft: 295))
        let calm = pace(D.limits(id: "d", used: 10, minutesLeft: 150))
        #expect(WindowPace.hero([behind, low, over, calm])?.window.id == "c")
        #expect(WindowPace.hero([behind, low, calm])?.window.id == "b")
        #expect(WindowPace.hero([calm, behind])?.window.id == "a")
        let calmer = pace(D.limits(id: "e", used: 30, minutesLeft: 150))
        #expect(WindowPace.hero([calm, calmer])?.window.id == "e")
        let old = pace(D.limits(id: "f", used: 99, readAgo: 7 * 3600))
        #expect(WindowPace.hero([old, calm])?.window.id == "d")
        #expect(WindowPace.hero([old]) == nil)
    }

    @Test("only registry CLIs with limits count; the v5 gemini entry and unmeasured CLIs form the Unmeasurable line")
    func registryOnly() {
        let gemini = CoreLimitsEntry(cli: .gemini, state: .measured, plan: nil, source: nil, at: D.now.timeIntervalSince1970, windows: D.limits(used: 99).windows)
        let codex = CoreLimitsEntry(cli: .codex, state: .notRecorded, plan: nil, source: nil, at: nil, windows: [])
        let result = CoreLimitsResult(limits: [D.limits(used: 10), codex, gemini])
        #expect(WindowPace.windows(limits: result, registry: D.registry, now: D.now).map(\.cli) == ["claude"])
        #expect(WindowPace.unmeasurable(limits: result, registry: D.registry).map(\.id) == ["codex"])
        #expect(WindowPace.windows(limits: nil, registry: D.registry, now: D.now).isEmpty)
    }

    @Test("the Window id is the countdown's `cli:windowID`")
    func id() {
        #expect(pace(D.limits(.codex, id: "Weekly", used: 1)).id == "codex:Weekly")
    }

    @Test("one rounding rule: the figure and the flag read the same one-decimal value, so 5% left is never unflagged (RD46)")
    func oneRoundingRule() {
        // 94.96 used: 5.04 left rounds to 5.0, shown "5%", and 5% left or less is flagged.
        let five = pace(D.limits(used: 94.96, minutesLeft: 295))
        #expect(five.left == 5)
        #expect(WindowPace.percentText(five.left ?? -1) == "5%")
        #expect(five.isLow && five.isBehind && five.severity == .critical)
        // 94.94 used: 5.06 left rounds to 5.1, shown "5.1%", not low.
        let above = pace(D.limits(used: 94.94, minutesLeft: 295))
        #expect(WindowPace.percentText(above.left ?? -1) == "5.1%")
        #expect(!above.isLow && !above.isBehind)
        // The sidebar shows the same text as the figure.
        let sidebar = FrameSidebarValue(figure: .percentLeft(above.left ?? -1, tone: nil), page: .limits)
        #expect(sidebar.text == "5.1% left")
    }

    @Test("a share reads with one decimal and no trailing .0, the number apart for a hero")
    func percentText() {
        #expect(WindowPace.percentText(38) == "38%")
        #expect(WindowPace.percentText(69.5) == "69.5%")
        #expect(WindowPace.percentText(0.04) == "0%")
        #expect(WindowPace.percentText(4.46) == "4.5%")
        #expect(WindowPace.percentText(1_204) == "1,204%")
        #expect(WindowPace.shareText(77) == "77")
        #expect(WindowPace.shareText(69.5) == "69.5")
    }
}

@Suite("Window pace: absurd shares")
struct WindowPaceAbsurdShareTests {
    @Test("a share past Int's range, infinity or NaN is shown at a bound, never trapping Int()")
    func clampedShares() {
        #expect(WindowPace.shareText(1e300) == NumberWording.count(Int(WindowPace.shareBound)))
        #expect(WindowPace.shareText(-.infinity) == NumberWording.count(-Int(WindowPace.shareBound)))
        #expect(WindowPace.shareText(.nan) == "0")
        #expect(InboxWording.percent(1e300) == "\(Int(WindowPace.shareBound))%")
        #expect(InboxWording.percent(.nan) == "0%")
        #expect(WindowPace.shareText(69.46) == "69.5", "ordinary shares are unchanged")
    }
}
