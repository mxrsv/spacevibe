import SwiftUI

/// The Limits page's Window row (design notes §27 "Limits CLI card and Window row"; the mock's `.win-row`, round 6): the
/// Window's name, its share left as the figure, the meter with the pace tick, and the reset column at the trailing end, in
/// four fixed columns so a long reset note or a starting countdown never moves another column (FE-L1, LC-R3). The page fills
/// the reset column (the clock ticks there, RD33); selection and the focus bar come from the `ItemRow` around it.
struct WindowRow<Reset: View>: View {
    typealias Column = WindowRowColumn

    let name: String
    /// Share left, shown with one decimal (`WindowPace.percentText`, RD46); nil reads `?` Unmeasurable (a Window past its
    /// reset, never 0%).
    let left: Double?
    /// The figure is quiet: a reading too old to judge.
    var isQuiet = false
    let meter: WindowMeter
    @ViewBuilder var reset: Reset

    init(name: String, left: Double?, isQuiet: Bool = false, meter: WindowMeter, @ViewBuilder reset: () -> Reset) {
        self.name = name
        self.left = left
        self.isQuiet = isQuiet
        self.meter = meter
        self.reset = reset()
    }

    var body: some View {
        HStack(spacing: Column.gap) {
            Text(name)
                .typeRole(.bodyMedium)
                .foregroundStyle(ColorRole.ink)
                .lineLimit(2)
                .truncationMode(.tail)
                .help(name)
                .frame(width: Column.name, alignment: .leading)
            figure
                .frame(width: Column.figure, alignment: .leading)
            meter
                .frame(maxWidth: .infinity)
            reset
                .frame(width: Column.reset, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var figure: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
            if let left {
                Text(verbatim: WindowPace.percentText(left))
                    .typeRole(.windowFigure)
                    .foregroundStyle(isQuiet ? ColorRole.ink3 : ColorRole.ink)
                Text("left").typeRole(.quiet).foregroundStyle(ColorRole.ink3)
            } else {
                Text(verbatim: "?").typeRole(.windowFigure).foregroundStyle(ColorRole.ink3)
                Text("Unmeasurable").typeRole(.quiet).foregroundStyle(ColorRole.ink3)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// The Window row's grid (the mock's `.win-row`): 96, 120, the rest, 200, 20 apart.
enum WindowRowColumn {
    static let name: CGFloat = 96
    static let figure: CGFloat = 120
    static let reset: CGFloat = 200
    static let gap = SpaceRole.step20
}

/// A Window's meter (RD-R6, DS-R5; the mock's `.pace`): the 6 pt meter (`ShareMeter`, `hero` height) centred in a band as high
/// as the Window's figure line, and the 2 pt `ink` time tick standing the band's whole height at the share of the Window's
/// time left (RD22, the tick D60 lacked), so the tick stays readable beside a thin bar. A fill shorter than the tick is usage
/// running ahead of time. No tick without a length or past the reset.
struct WindowMeter: View {
    enum Tone: Hashable, Sendable {
        /// On pace: `ink2`.
        case plain
        /// Shown, not judged (an old reading, past the reset): `ink3`.
        case muted
        case attention
        case critical

        var meter: ShareMeter.Tone {
            switch self {
            case .plain: .secondary
            case .muted: .quiet
            case .attention: .attention
            case .critical: .critical
            }
        }
    }

    /// 0 to 1, what is left.
    let share: Double
    var tone: Tone = .plain
    /// 0 to 1, the share of time left; nil for no tick.
    var tick: Double?
    /// VoiceOver: "5-hour, Claude Code".
    var label: String?

    var body: some View {
        ShareMeter(share: share, height: .hero, tone: tone.meter, label: label)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .leading) {
                if let tick {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(ColorRole.ink)
                            .frame(width: SizeRole.paceTickWidth)
                            .offset(x: ShareMeter.tickOffset(tick, width: proxy.size.width))
                    }
                    .help("Time left in the Window")
                    .accessibilityHidden(true)
                }
            }
            .frame(height: TypeRole.windowFigure.lineHeight)
    }
}

/// The Limits legend's tick (the mock's legend swatch): the time tick at the height of a quiet line, so the sentence beside it
/// names what the mark on every meter is.
struct WindowMeterLegendTick: View {
    var body: some View {
        Capsule()
            .fill(ColorRole.ink)
            .frame(width: SizeRole.paceTickWidth, height: SizeRole.icon12)
            .accessibilityHidden(true)
    }
}
