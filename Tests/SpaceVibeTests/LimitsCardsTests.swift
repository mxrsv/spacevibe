import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// RB-R6: what the redesign's Limits page shows in every state (spec `docs/specs/2026-11-20-spacevibe-redesign.md`: RD-R2
/// Limits, RD30, RD24, RD33, RD-R10, RD-R13), from synthetic readings only (`LimitsFrameShotData`, S-R2).
@MainActor
@Suite("Limits page (redesign)")
struct LimitsCardsTests {
    private typealias Data = LimitsFrameShotData
    private let now = LimitsFrameShotData.now

    private func cards(_ limits: CoreLimitsResult?, registry: [CoreRegistryCLI] = LimitsFrameShotData.registry,
                       state: FrameSourceState? = .ready, lead: WeeklyCountdownLead = .standard,
                       hidden: Set<String> = []) -> (LimitsCards, FrameWorld) {
        var snapshot = FrameSnapshot()
        snapshot.registry = registry
        snapshot.limits = limits
        var facts = FrameFacts()
        facts.hidden = hidden
        let world = FrameWorld(snapshot: snapshot, facts: facts, now: now)
        return (LimitsCards(world: world, state: state, now: now, weeklyLead: lead), world)
    }

    private func row(_ cards: LimitsCards, _ id: String) throws -> LimitsCards.Row {
        try #require(cards.cards.flatMap(\.rows).first { $0.id == id })
    }

    // MARK: Normal

    @Test("normal: one card per CLI in registry order, Gemini left out, the hero is the Window behind pace and equals the sidebar")
    func normal() throws {
        let (cards, world) = cards(Data.normal)
        #expect(cards.cards.map(\.cliID) == ["claude", "codex"])
        #expect(cards.unmeasurable.isEmpty)
        #expect(cards.failure == nil)
        #expect(cards.hero == .window(id: "codex:primary", left: 77, label: "Codex · 5-hour Window · using it faster than time passes"))
        // AR3: the hero and the sidebar read the same Window and the same whole percent.
        #expect(world.heroWindow?.id == "codex:primary")
        let sidebar = FrameSidebarValue(figure: world.figure(for: .limits, loading: [], failed: []), page: .limits)
        #expect(sidebar.text == "77% left")
        #expect(cards.rowIDs == ["claude:five_hour", "claude:seven_day", "codex:primary", "codex:secondary"])
        #expect(cards.cards[0].source == "Status-line snapshot · 12 min ago")
        #expect(cards.cards[1].plan == "Pro")
        #expect(cards.cards[1].source == "Session log · 3 min ago")
    }

    @Test("a counting 5-hour row shows the clock in its tone and hides its note; a row behind pace keeps a coloured note")
    func rows() throws {
        let (cards, _) = cards(Data.normal)
        let claude = try row(cards, "claude:five_hour")
        #expect(claude.name == "5-hour")
        #expect(claude.left == 38)
        #expect(claude.tone == .plain)
        #expect(claude.countdownLead == LimitsCountdown.fiveHourLead)
        let left = try #require(claude.countdown(at: now))
        #expect(LimitsCountdown.clock(left) == "42:00")
        #expect(claude.shownNote(at: now) == nil)
        #expect(abs((claude.tick ?? 0) - 0.14) < 0.001)

        let codex = try row(cards, "codex:primary")
        #expect(codex.tone == .attention)
        #expect(codex.isBehind)
        #expect(codex.countdown(at: now) == nil)
        #expect(codex.reset.hasPrefix("Resets "))
        #expect(codex.shownNote(at: now) == LimitsCards.Note(mark: .attention, text: "Faster than time · 4 h 6 min"))

        // A weekly Window outside the 1 h lead never counts; its note is the time to its reset.
        let weekly = try row(cards, "claude:seven_day")
        #expect(weekly.countdown(at: now) == nil)
        #expect(weekly.shownNote(at: now) == LimitsCards.Note(mark: nil, text: "4 d 12 h"))
    }

    @Test("at the 24 h lead a weekly Window counts in H:MM:SS; at the default lead it does not (LC-R1, LC-R2)")
    func weeklyLead() throws {
        let (long, _) = cards(Data.weekly, lead: .hours24)
        let counting = try row(long, "claude:seven_day")
        #expect(counting.countdown(at: now).map(LimitsCountdown.clock) == "23:12:06")
        let (short, _) = cards(Data.weekly)
        #expect(try row(short, "claude:seven_day").countdown(at: now) == nil)
    }

    // MARK: Empty, scanning, error

    @Test("empty: Claude Code with no reading offers Copy Install Command; the hero falls back to the lowest left")
    func empty() throws {
        let (cards, _) = cards(Data.empty)
        #expect(cards.cards.map(\.body) == [.noSnapshot, cards.cards[1].body])
        #expect(cards.cards[0].isUnmeasurable)
        #expect(cards.cards[0].rows.isEmpty)
        #expect(cards.hero == .window(id: "codex:secondary", left: 52, label: "Codex · Weekly Window · lowest left"))
    }

    @Test("Copy Install Command copies the status-line capture's install line for the bundled core (RD24); the app never runs it")
    func installCommand() {
        let helper = URL(fileURLWithPath: "/Applications/Space Vibe's.app/Contents/Helpers/spacevibe")
        let command = LimitsCards.installCommand(helper: helper)
        #expect(command == LimitsTab.captureCommand(helper: helper, subcommand: "install"))
        #expect(command.hasSuffix("' statusline install"))
        #expect(LimitsCards.copiedMessage == "Copied to the clipboard")
    }

    @Test("scanning: before the first read every CLI with limits waits in its card, the hero is pending and no row is selectable")
    func scanning() {
        let (cards, _) = cards(nil, state: .loading)
        #expect(cards.hero == .reading)
        #expect(cards.cards.map(\.body) == [.reading, .reading])
        #expect(cards.rowIDs.isEmpty)
        #expect(cards.failure == nil)
    }

    @Test("a failed first read: the core's sentence in the banner, no card, the hero Unmeasurable; a failed refresh keeps the data")
    func failed() {
        let (first, _) = cards(nil, state: .failed("The core could not be started."))
        #expect(first.failure == "The core could not be started.")
        #expect(first.cards.isEmpty)
        #expect(first.hero == .unmeasurable)
        let (later, _) = cards(Data.normal, state: .failed("The core could not be started."))
        #expect(later.failure == nil)
        #expect(later.cards.count == 2)
    }

    @Test("an unreadable record is a card with Try Again, its Windows Unmeasurable and out of the hero")
    func unreadable() {
        let (cards, _) = cards(Data.error)
        #expect(cards.cards.map(\.body).last == .unreadable)
        #expect(cards.cards.last?.isUnmeasurable == true)
        if case .window(let id, _, _) = cards.hero { #expect(id.hasPrefix("claude:")) } else { Issue.record("hero should be a Claude Window") }
        #expect(LimitsCards.unreadableText("Codex") == "Codex's limit record could not be read, so its Windows are Unmeasurable, not 0%.")
    }

    // MARK: Worst case (RD30)

    @Test("worst: a 7-hour-old reading is shown, not judged; a Window past its reset reads Unmeasurable; over the limit leads")
    func worst() throws {
        let (cards, _) = cards(Data.worst)
        let passed = try row(cards, "claude:five_hour")
        #expect(passed.left == nil)
        #expect(passed.share == 0)
        #expect(passed.tick == nil)
        #expect(passed.tone == .muted)
        #expect(passed.reset == "Reset has passed")
        #expect(passed.countdownLead == nil)
        #expect(passed.note == LimitsCards.Note(mark: nil, text: "Reading is older than the reset"))

        let old = try row(cards, "claude:seven_day")
        #expect(old.tone == .muted)
        #expect(old.isQuiet)
        #expect(!old.isBehind)
        #expect(old.note == LimitsCards.Note(mark: .attention, text: "Reading is 7 hours old · 4 d 12 h"))
        let noLength = try row(cards, "claude:weekly")
        #expect(noLength.name == "Weekly · Fable")
        #expect(noLength.tick == nil)
        #expect(noLength.note.text == "Reading is 7 hours old · no window length · 4 d 12 h")

        let over = try row(cards, "codex:secondary")
        #expect(over.left == 0)
        #expect(over.tone == .critical)
        #expect(over.note == LimitsCards.Note(mark: .critical, text: "Over by 4.5% · 3 d 8 h"))
        let low = try row(cards, "codex:primary")
        #expect(low.tone == .critical)
        #expect(low.note == LimitsCards.Note(mark: .critical, text: "Almost used up · 4 h 6 min"))
        #expect(cards.hero == .window(id: "codex:secondary", left: 0, label: "Codex · Weekly Window · over the limit"))
        #expect(cards.cards[1].plan == "Business (annual, 150 seats, invoiced through the reseller)")
    }

    @Test("a fresh Window with no length is not judged by pace but still leads at 5% left or less (RD30, RD-A9)")
    func noLength() throws {
        let result = CoreLimitsResult(limits: [
            Data.entry(.claude, [Data.window("opus", nil, used: 96, resetsIn: 600), Data.window("five_hour", 300, used: 90, resetsIn: 10)],
                       readAgo: 1),
        ])
        let (cards, _) = cards(result)
        let opus = try row(cards, "claude:opus")
        #expect(opus.tick == nil)
        #expect(opus.tone == .critical)
        #expect(opus.note.mark == .critical)
        #expect(cards.hero == .window(id: "claude:opus", left: 4, label: "Claude Code · Opus Window · almost used up"))

        let paceOnly = CoreLimitsResult(limits: [Data.entry(.claude, [Data.window("opus", nil, used: 50, resetsIn: 600)], readAgo: 1)])
        let (quiet, _) = self.cards(paceOnly)
        let row = try row(quiet, "claude:opus")
        #expect(row.tone == .plain)
        #expect(row.note == LimitsCards.Note(mark: nil, text: "No window length, so no pace · 10 h 0 min"))
    }

    // MARK: N CLIs (RD-R10)

    @Test("ten CLIs: the eight without limit data collapse into one Unmeasurable line in registry order; the cards keep their shape")
    func many() {
        let (cards, _) = cards(Data.normal, registry: Data.manyRegistry)
        #expect(cards.cards.map(\.cliID) == ["claude", "codex"])
        #expect(cards.unmeasurable == ["Cursor CLI", "Copilot CLI", "opencode", "Amp", "Antigravity CLI", "Kiro", "Qwen Code", "Aider"])
        #expect(cards.unmeasurableLine.hasPrefix("Cursor CLI · Copilot CLI · "))
        let (two, _) = self.cards(Data.normal)
        #expect(two.cards.map(\.rows) == cards.cards.map(\.rows))
    }

    @Test("not installed is not listed; not measurable, no entry and no Window join the Unmeasurable line; a hidden CLI leaves")
    func cliStates() {
        let registry = Data.registry + [CoreRegistryCLI(id: "gemini", name: "Gemini CLI", supports: Data.all)]
        let result = CoreLimitsResult(limits: [
            Data.entry(.claude, [], readAgo: 0, state: .notInstalled),
            Data.entry(.codex, [], readAgo: 0, state: .notMeasurable),
        ])
        let (cards, _) = cards(result, registry: registry)
        #expect(cards.cards.isEmpty)
        #expect(cards.unmeasurable == ["Codex", "Gemini CLI"])
        #expect(cards.hero == .unmeasurable)

        let measuredEmpty = CoreLimitsResult(limits: [Data.entry(.codex, [], readAgo: 1)])
        #expect(self.cards(measuredEmpty).0.unmeasurable == ["Claude Code", "Codex"])

        let (hidden, _) = self.cards(Data.normal, hidden: ["claude"])
        #expect(hidden.cards.map(\.cliID) == ["codex"])
    }

    @Test("Codex with no reading yet says so in its card, without the install command (that is Claude Code's status line)")
    func codexNotRecorded() {
        let result = CoreLimitsResult(limits: [Data.entry(.codex, [], readAgo: 0, state: .notRecorded)])
        let (cards, _) = cards(result)
        #expect(cards.cards.map(\.body) == [.note("No Codex turn has logged limits yet.")])
    }

    // MARK: Region

    @Test("the region has no inspector, no toolbar control and no primary action (D69: no Refresh)")
    func region() {
        let model = FrameModel(core: UnservedCore(), toasts: ToastCenter(announce: false), route: FrameRoute(page: .limits))
        let content = FramePageContent.region(.limits, model: model)
        #expect(content.inspector == nil)
        #expect(content.primary == nil)
        #expect(content.toolbarControls == nil)
        #expect(content.help == FramePage.limits.help)
        #expect(!FramePage.limits.hasInspector)
    }

    // MARK: Blocks (GroupCard, SkeletonLine, WindowRow, WindowMeter)

    @Test("the blocks keep the mock's measures and map each row tone to one meter fill and one clock ink")
    func blocks() {
        #expect(GroupCard<EmptyView>.Inset.regular.vertical == SpaceRole.step20)
        #expect(GroupCard<EmptyView>.Inset.compact.vertical == SpaceRole.step12)
        #expect(GroupCard<EmptyView>.Inset.regular.horizontal == SpaceRole.step24)
        #expect(GroupCard<EmptyView>.sentenceWidth > PageEmptyState<EmptyView>.textWidth)
        #expect(SkeletonLine.Length.long.share == 0.6)
        #expect(SkeletonLine.Length.short.share == 0.48)
        #expect([WindowRowColumn.name, WindowRowColumn.figure, WindowRowColumn.reset] == [96, 120, 200])
        #expect(WindowMeter.Tone.plain.meter == .secondary)
        #expect(WindowMeter.Tone.muted.meter == .quiet)
        #expect(WindowMeter.Tone.attention.meter == .attention)
        #expect(WindowMeter.Tone.critical.meter == .critical)
        let tones: [LimitsCards.Tone] = [.plain, .muted, .attention, .critical]
        #expect(tones.map(LimitsCardList.meterTone) == [.plain, .muted, .attention, .critical])
        #expect(LimitsResetColumn.ink(.plain) == ColorRole.ink2)
        #expect(LimitsResetColumn.ink(.muted) == ColorRole.ink3)
        #expect(LimitsResetColumn.ink(.attention) == ColorRole.stateAttention)
        #expect(LimitsResetColumn.ink(.critical) == ColorRole.stateCritical)
    }

    @Test("every shot scenario builds, and its sidebar value is the hero's figure")
    func shotScenarios() {
        for scenario in LimitsFrameShotData.Scenario.allCases {
            let cards = scenario.cards
            switch cards.hero {
            case .window(_, let left, _): #expect(scenario.sidebarValue.text == "\(left)% left", "\(scenario)")
            case .reading: #expect(scenario.sidebarValue.text == "\u{2026}", "\(scenario)")
            case .unmeasurable: #expect(scenario.sidebarValue.text == "Unmeasurable", "\(scenario)")
            }
        }
    }
}
