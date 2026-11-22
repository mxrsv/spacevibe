import SwiftUI

/// The redesign's Limits page body (RD-R2 Limits: first the Window that needs you, then the same Window's row and its tick;
/// the reference mock's `pageLimits`): the hero, one card per CLI with limit data in the fixed registry order, the one
/// "Unmeasurable" line, and the legend of the pace tick. It draws `LimitsCards` and nothing else, so a shot and the live page
/// are the same view. No inspector, no toolbar control, no Refresh (D69, RD21): the store re-reads on activation and ⌘R.
///
/// - Rows are selectable (highlight only; the spec's "Inferred, not decided" Limits selection): a click or ↑↓ sets the
///   route's selection, which is also how the widget's pill opens a Window here (LC-R7).
/// - A row inside its countdown lead ticks every second in its reset column (RD33, LC-R2, LC-R3); `pinnedNow` stops the
///   clock at one moment for a shot.
struct LimitsCardList: View {
    let cards: LimitsCards
    let selection: String?
    /// The row the arrow keys moved to: it shows the focus bar (RD29).
    var keyboardRow: String?
    /// The page's clock. Nil reads the live time and lets counting rows tick; a date pins every clock (a shot).
    var pinnedNow: Date?
    /// Try Again is waiting for its read.
    var isRetrying = false
    var select: (String) -> Void = { _ in }
    var copyInstallCommand: () -> Void = {}
    var tryAgain: () -> Void = {}

    var body: some View {
        // The screens' scroll view, so a headless shot draws the cards (a bare `ScrollView` renders blank there).
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                    .padding(.top, SpaceRole.step4)
                    .padding(.horizontal, SpaceRole.step8)
                    .padding(.bottom, SpaceRole.step20)
                if let failure = cards.failure {
                    StatusBanner(.problem(.critical), title: "Limits could not be read", detail: failure) { retryButton }
                        .padding(.bottom, SpaceRole.step16)
                }
                VStack(alignment: .leading, spacing: SpaceRole.step16) {
                    ForEach(cards.cards) { card($0) }
                    if !cards.unmeasurable.isEmpty { unmeasurableLine }
                }
                legend
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        switch cards.hero {
        case .reading: PageHero(.scanning, label: "Reading the limit records")
        case .unmeasurable: PageHero(.unmeasurable, label: "Unmeasurable")
        case .window(_, let left, let label): PageHero(.value(WindowPace.shareText(left), unit: "% left"), label: label)
        }
    }

    // MARK: Cards

    private func card(_ card: LimitsCards.Card) -> some View {
        GroupCard(spacing: card.isUnmeasurable ? SpaceRole.step10 : SpaceRole.step16) {
            head(card)
            switch card.body {
            case .windows(let rows):
                VStack(alignment: .leading, spacing: SpaceRole.step8) {
                    ForEach(rows) { windowRow($0, cli: card.name) }
                }
                // The rows' own inset lines their text up with the head; the selection fill reaches past it.
                .padding(.horizontal, -SpaceRole.step12)
            case .reading:
                VStack(alignment: .leading, spacing: SpaceRole.step16) {
                    SkeletonLine(.long)
                    SkeletonLine(.short)
                }
                .accessibilityElement()
                .accessibilityLabel("Reading \(card.name) limits")
            case .noSnapshot:
                sentence(LimitsCards.noSnapshotText)
                Button(action: copyInstallCommand) { PushButtonLabel("Copy Install Command", icon: .copy, size: .small) }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
            case .unreadable:
                sentence(LimitsCards.unreadableText(card.name))
                retryButton
            case .note(let text):
                sentence(text)
            }
        }
    }

    private func head(_ card: LimitsCards.Card) -> some View {
        HStack(spacing: SpaceRole.step12) {
            CLILogo(CLIIdentity(id: card.cliID, name: card.name), size: SizeRole.logo20)
            Text(card.name).typeRole(.bodyMedium).foregroundStyle(ColorRole.ink).lineLimit(1)
            if let plan = card.plan {
                // A long plan name is cut by the width; its tooltip holds it whole (break-ui, RB-F3).
                Text(plan).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1).truncationMode(.tail).help(plan)
            }
            Spacer(minLength: SpaceRole.step12)
            if card.isUnmeasurable {
                HStack(spacing: SpaceRole.step6) {
                    FrameGlyph(.question, side: SizeRole.icon14, ink: ColorRole.ink3)
                    Text("Unmeasurable").typeRole(.quiet).foregroundStyle(ColorRole.ink3)
                }
                .fixedSize()
            } else if let source = card.source {
                Text(source).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1).fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sentence(_ text: String) -> some View {
        Text(text)
            .typeRole(.quiet)
            .foregroundStyle(ColorRole.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: GroupCard<EmptyView>.sentenceWidth, alignment: .leading)
    }

    private var retryButton: some View {
        Button(action: tryAgain) { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
            .buttonStyle(PushButtonStyle(.control, size: .small, isLoading: isRetrying))
            .disabled(isRetrying)
            .focusEffectDisabled()
    }

    private var unmeasurableLine: some View {
        GroupCard(inset: .compact, spacing: SpaceRole.step6) {
            HStack(spacing: SpaceRole.step12) {
                FrameGlyph(.question, side: SizeRole.icon20, ink: ColorRole.ink3)
                Text("Unmeasurable").typeRole(.bodyMedium).foregroundStyle(ColorRole.ink)
                Spacer(minLength: SpaceRole.step12)
                Text(cards.unmeasurableLine)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .truncationMode(.tail)
                    .help(cards.unmeasurableLine)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Rows

    private func windowRow(_ row: LimitsCards.Row, cli: String) -> some View {
        ItemRow(label: "\(cli), \(row.name)", height: .list, isSelected: selection == row.id,
                isKeyboardFocused: keyboardRow == row.id, select: { select(row.id) }) {
            WindowRow(name: row.name, left: row.left, isQuiet: row.isQuiet,
                      meter: WindowMeter(share: row.share, tone: Self.meterTone(row.tone), tick: row.tick, label: "\(row.name), \(cli)")) {
                resetColumn(row)
            }
        }
    }

    /// The reset column: the clock in the row's tone with the reset time after it while the Window counts (RD33), otherwise
    /// "Resets 5:40 PM"; the note under it. It ticks each second from a minute before its lead (`LimitsCountdown.wakeAhead`), as
    /// the v5 page does, so it starts on time although the page itself redraws once a minute.
    @ViewBuilder
    private func resetColumn(_ row: LimitsCards.Row) -> some View {
        if let pinnedNow {
            LimitsResetColumn(row: row, now: pinnedNow)
        } else {
            let now = Date()
            if let lead = row.countdownLead, row.resetsAt.timeIntervalSince(now) <= lead + LimitsCountdown.wakeAhead {
                TimelineView(.periodic(from: LimitsCountdown.wholeSecond(before: now), by: LimitsCountdown.tick)) { context in
                    LimitsResetColumn(row: row, now: context.date)
                }
            } else {
                LimitsResetColumn(row: row, now: now)
            }
        }
    }

    static func meterTone(_ tone: LimitsCards.Tone) -> WindowMeter.Tone {
        switch tone {
        case .plain: .plain
        case .muted: .muted
        case .attention: .attention
        case .critical: .critical
        }
    }

    // MARK: Legend

    private var legend: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step16) {
            HStack(spacing: SpaceRole.step6) {
                WindowMeterLegendTick()
                Text("Time left in the Window")
            }
            .fixedSize()
            Text(Self.legendText).fixedSize(horizontal: false, vertical: true)
        }
        .typeRole(.quiet)
        .foregroundStyle(ColorRole.ink3)
        .padding(.vertical, SpaceRole.step12)
        .padding(.horizontal, SpaceRole.step8)
    }

    static let legendText = "Fill is what is left. More than 3 points short of the tick, once a tenth of the Window has passed, "
        + "is flagged as faster than time; 5% left or less is always flagged."
}

/// One row's reset column at `now`: the countdown clock (LC-R2: `MM:SS`, `H:MM:SS` above an hour) in the row's tone with the
/// reset's clock time quiet after it, or the reset line; under it the row's note with its severity glyph.
struct LimitsResetColumn: View {
    let row: LimitsCards.Row
    let now: Date

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let left = row.countdown(at: now) {
                HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step4) {
                    Text(verbatim: LimitsCountdown.clock(left)).typeRole(.bodyMedium).foregroundStyle(Self.ink(row.tone))
                    Text(row.resetTime).typeRole(.quiet).foregroundStyle(ColorRole.ink3)
                }
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Resets at \(row.resetTime), \(LimitsCountdown.spoken(left))")
            } else {
                Text(row.reset).typeRole(.bodyText).foregroundStyle(ColorRole.ink).lineLimit(1)
            }
            if let note = row.shownNote(at: now) {
                HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step4) {
                    if let mark = note.mark {
                        let severity: GroupSeverity = mark == .critical ? .critical : .attention
                        FrameGlyph(severity.icon ?? .infoFill, side: SizeRole.icon12, ink: severity.ink, label: severity.spoken)
                    }
                    Text(note.text)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .truncationMode(.tail)
                }
            }
        }
    }

    /// The clock takes the row's tone (LC9, RD33): `ink2` on pace, the state ink when behind, `ink3` when not judged.
    static func ink(_ tone: LimitsCards.Tone) -> Color {
        switch tone {
        case .plain: ColorRole.ink2
        case .muted: ColorRole.ink3
        case .attention: ColorRole.stateAttention
        case .critical: ColorRole.stateCritical
        }
    }
}
