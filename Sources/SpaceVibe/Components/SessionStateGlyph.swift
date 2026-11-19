import SwiftUI

/// How each glance state is drawn (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW-R2, GW9, GW19, GW20): a Phosphor
/// Bold glyph in the state's muted token, or for idle a small dot. `ink` is the token's value, so a test checks the token
/// itself and not a copy of it.
extension GlanceState {
    /// Nil for idle, which is a dot rather than a glyph.
    var glyph: StateGlyph? {
        switch self {
        case .working: .circleNotch
        case .waiting: .chatCircleDots
        case .done: .checkCircle
        case .unmeasurable: .circleDashed
        case .idle: nil
        }
    }

    /// Working, waiting and done have their own state colours; unmeasurable and idle are `mute` (GW9).
    var ink: ColorValue {
        switch self {
        case .working: PaletteValue.sessionWorking
        case .waiting: PaletteValue.sessionWaiting
        case .done: PaletteValue.sessionDone
        case .unmeasurable, .idle: PaletteValue.mute
        }
    }

    /// Unmeasurable and idle are faint, so they never compete with a session that needs the user.
    var inkOpacity: Double {
        switch self {
        case .working, .waiting, .done: 1
        case .unmeasurable: Metrics.Glance.unmeasurableOpacity
        case .idle: Metrics.Glance.idleOpacity
        }
    }

    /// Only the working ring moves (GW-R11).
    var rotates: Bool { self == .working }
}

/// One session's state glyph at 12 (the smallest icon size): the glyph in its state colour, or the idle dot. The working ring
/// turns once a second; it holds still under Reduce Motion, in a headless shot, and when `isAnimating` is false (the widget
/// is hidden or covered, GW-R11). The ring is drawn by a `TimelineView`, so a still ring costs no frame at all. Decorative:
/// the entry or row around it says the state in words.
struct SessionStateGlyph: View {
    let state: GlanceState
    /// False while the widget is not on screen.
    var isAnimating = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isShotRendering) private var isShotRendering

    var body: some View {
        Group {
            if let glyph = state.glyph {
                let icon = SpaceVibeIcon(state: glyph, size: .small, ink: state.ink.color).opacity(state.inkOpacity)
                if state.rotates && isAnimating && !reduceMotion && !isShotRendering {
                    TimelineView(.animation(minimumInterval: Metrics.Glance.spinFrame)) { context in
                        icon.rotationEffect(Self.angle(at: context.date))
                    }
                } else {
                    icon
                }
            } else {
                Circle()
                    .fill(state.ink.color)
                    .frame(width: Metrics.Glance.idleDot, height: Metrics.Glance.idleDot)
                    .opacity(state.inkOpacity)
            }
        }
        .frame(width: IconSize.small.points, height: IconSize.small.points)
        .accessibilityHidden(true)
    }

    /// The ring's turn at `date`: one full turn per `spinPeriod`, from the clock, so every ring on screen turns together.
    static func angle(at date: Date) -> Angle {
        let period = Metrics.Glance.spinPeriod
        return .degrees(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period * 360)
    }
}
