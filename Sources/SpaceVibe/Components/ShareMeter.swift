import SwiftUI

/// A thin meter (DS-R10 "Meter"; RD7, RD-R6; the mock's `.mtr`, `.prog`), beside v5's `BarCell`: 4 pt in rows, 6 pt for the
/// hero and Limits, 3 pt for progress, round ends, on the `faint` track (which Increase Contrast lifts to 3:1). The fill is a
/// share of the width; the pace tick, when given, is a 2 pt `ink` mark standing 2 pt past the track above and below at the
/// share of time left (a Window's "time" mark, RD-R6). An unknown share is a dashed line, never an empty track that reads as
/// 0 (RD-R10). Decorative unless `label` is given; the figure beside it says the number.
struct ShareMeter: View {
    enum Height: Hashable, Sendable {
        case row, hero, progress

        var points: CGFloat {
            switch self {
            case .row: SizeRole.meterRow
            case .hero: SizeRole.meterHero
            case .progress: SizeRole.meterProgress
            }
        }
    }

    /// What the fill says. Colour is a state only when the value itself is one (DS-R11).
    enum Tone: Hashable, Sendable {
        /// A plain share: `ink2` in rows, `ink` on the hero.
        case plain
        /// Data compared by eye (`dataBar`, Clean's selected amount).
        case data
        case attention
        case critical
    }

    /// 0 to 1, or nil when Unmeasurable.
    let share: Double?
    var height: Height = .row
    var tone: Tone = .plain
    /// 0 to 1: where the pace tick sits; nil for none.
    var paceTick: Double?
    /// When set, the meter is a VoiceOver element with this label and the share as its value.
    var label: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let share {
                let fraction = Self.clamped(share)
                Capsule()
                    .fill(ColorRole.faint)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(fill)
                                .frame(width: proxy.size.width * fraction)
                                .animation(reduceMotion ? nil : .easeOut(duration: MotionRole.tileDuration), value: fraction)
                        }
                    }
                    .clipShape(Capsule())
                    .overlay(alignment: .leading) {
                        if let paceTick {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(ColorRole.ink)
                                    .frame(width: SizeRole.paceTickWidth, height: height.points + 2 * SizeRole.paceTickOverhang)
                                    .offset(x: Self.tickOffset(paceTick, width: proxy.size.width), y: -SizeRole.paceTickOverhang)
                            }
                        }
                    }
            } else {
                DashLine()
                    .stroke(ColorRole.ink3, style: StrokeStyle(lineWidth: 1, dash: [SpaceRole.step4, SpaceRole.step4]))
            }
        }
        .frame(height: height.points)
        .frame(maxWidth: .infinity)
        .modifier(MeterAccessibility(label: label, share: share))
    }

    private var fill: Color {
        switch tone {
        case .plain: height == .hero ? ColorRole.ink : ColorRole.ink2
        case .data: ColorRole.dataBar
        case .attention: ColorRole.attentionBar
        case .critical: ColorRole.criticalBar
        }
    }

    static func clamped(_ share: Double) -> Double { share.isFinite ? min(max(share, 0), 1) : 0 }

    /// The tick's leading edge, kept inside the track.
    static func tickOffset(_ tick: Double, width: CGFloat) -> CGFloat {
        min(max(0, width * clamped(tick) - SizeRole.paceTickWidth / 2), max(0, width - SizeRole.paceTickWidth))
    }

    /// "62%", "Unmeasurable".
    static func spokenValue(_ share: Double?) -> String {
        guard let share else { return "Unmeasurable" }
        return "\(Int((clamped(share) * 100).rounded()))%"
    }

    private struct DashLine: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

private struct MeterAccessibility: ViewModifier {
    let label: String?
    let share: Double?

    func body(content: Content) -> some View {
        if let label {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(ShareMeter.spokenValue(share))
        } else {
            content.accessibilityHidden(true)
        }
    }
}
