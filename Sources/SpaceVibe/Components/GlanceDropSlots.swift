import SwiftUI

/// The drop slots of one screen while the glance widget is dragged (spec `docs/specs/2026-11-19-session-glance-widget.md`,
/// GW13, GW-R7; the mock's "Đang kéo" view). It fills a click-through overlay that covers the screen's visible frame;
/// `canvas` is that frame's size and each outline's frame is in its coordinates, origin top left.
struct GlanceDropSlots: View {
    let outlines: [GlanceDropOutline]
    let canvas: CGSize
    /// The widget's tokens (`GlanceTokens`): the shipped set unless the redesign's switch is on.
    var tokens: GlanceTokens = .v5

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(outlines) { outline in
                GlanceDropSlot(isTarget: outline.isTarget)
                    .frame(width: outline.frame.width, height: outline.frame.height)
                    .offset(x: outline.frame.minX, y: outline.frame.minY)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .accessibilityHidden(true)
        .environment(\.glanceTokens, tokens)
    }
}

/// One drop slot, the widget's own size and shape: a dashed capsule on a faint fill, or, for the slot a release picks, a
/// solid edge in the text ink on a stronger fill.
struct GlanceDropSlot: View {
    let isTarget: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.glanceTokens) private var tokens

    var body: some View {
        let edge = StrokeStyle(lineWidth: Metrics.Glance.slotStroke, dash: isTarget ? [] : Metrics.Glance.slotDash)
        Capsule(style: Metrics.Radius.cornerStyle)
            .fill(isTarget ? tokens.slotTargetFill : tokens.slotFill)
            .overlay {
                Capsule(style: Metrics.Radius.cornerStyle)
                    .strokeBorder(isTarget ? tokens.slotTargetEdge : tokens.slotEdge, style: edge)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: Metrics.Motion.quick), value: isTarget)
    }
}
