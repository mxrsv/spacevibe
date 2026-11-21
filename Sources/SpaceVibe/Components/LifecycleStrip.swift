import SwiftUI

/// One event of the Hooks lifecycle strip: the event, how many Hooks fire on it and the worst state among them.
struct LifecycleNode: Identifiable, Hashable, Sendable {
    enum Mark: Hashable, Sendable {
        /// Hooks fire here and none is dead or failing.
        case plain
        /// No Hook on this event (one of the six common events is always drawn).
        case empty
        /// A Hook here has errors in the last 7 days (RD26).
        case attention
        /// A Hook here is dead: every script it names is gone.
        case critical
    }

    let event: String
    let count: Int
    let mark: Mark

    var id: String { event }

    /// What VoiceOver reads (RD-R16 "Hooks node has a label and its state"): "PreToolUse: 3 Hooks, one is dead".
    var spoken: String {
        let hooks = NumberWording.plural(count, "Hook")
        switch mark {
        case .critical: return "\(event): \(hooks), one is dead"
        case .attention: return "\(event): \(hooks), one is failing"
        case .plain, .empty: return "\(event): \(hooks)"
        }
    }
}

/// The Hooks page's own figure (DS-R10 "Hooks lifecycle strip"; the mock's `.life`): one node per event in firing order on a
/// faint line, each a 22 pt disc with its Hook count and the event's name under it. A dead Hook rings its node in the
/// critical ink with an `x-circle-fill` badge, a failing one in the attention ink with `warning-fill` (glyph and colour,
/// RD-R16); an event with no Hook is quiet. A node is a toggle: pressing it shows only that event's Hooks, pressing it again
/// shows all. Each node is a VoiceOver button with its count, state and whether it is the filter.
struct LifecycleStrip: View {
    let nodes: [LifecycleNode]
    /// The event the list is filtered to, if any.
    let chosen: String?
    let pick: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                LifecycleNodeButton(node: node, isChosen: chosen == node.event, isFirst: index == 0) { pick(node.event) }
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hooks per event, in firing order")
    }
}

/// The disc's side and ring (the mock's `.nd .pt`: 22 px, a 2 px ring).
private let discSide: CGFloat = 22
private let ringWidth: CGFloat = 2
/// The badge disc on a marked node (the mock's `.ndb`: 14 px, 7 px past the disc's corner).
private let badgeOffset: CGFloat = 7

private struct LifecycleNodeButton: View {
    let node: LifecycleNode
    let isChosen: Bool
    let isFirst: Bool
    let press: () -> Void

    var body: some View {
        Button(action: press) { EmptyView() }
            .buttonStyle(LifecycleNodeStyle(node: node, isChosen: isChosen, isFirst: isFirst))
            .focusBarFocusable()
            .help("\(NumberWording.plural(node.count, "Hook")) on \(node.event)")
            .accessibilityLabel(node.spoken)
            .accessibilityAddTraits(isChosen ? [.isSelected] : [])
            .accessibilityValue(isChosen ? "Shown alone" : "")
    }
}

private struct LifecycleNodeStyle: ButtonStyle {
    let node: LifecycleNode
    let isChosen: Bool
    let isFirst: Bool

    func makeBody(configuration: Configuration) -> some View {
        NodeBody(node: node, isChosen: isChosen, isFirst: isFirst, isPressed: configuration.isPressed)
    }

    private struct NodeBody: View {
        let node: LifecycleNode
        let isChosen: Bool
        let isFirst: Bool
        let isPressed: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            VStack(spacing: SpaceRole.step6) {
                disc
                Text(verbatim: node.event)
                    .typeRole(.axisCaption)
                    .foregroundStyle(isChosen || hovering ? ColorRole.ink : ColorRole.ink3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.top, SpaceRole.step2)
            .frame(maxWidth: .infinity)
            // The line from the previous node's centre to this one's (the mock's `.nd::before`), behind the disc.
            .background(alignment: .top) {
                if !isFirst {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(ColorRole.faint)
                            .opacity(OpacityRole.dim)
                            .frame(width: proxy.size.width, height: ringWidth)
                            .offset(x: -proxy.size.width / 2, y: SpaceRole.step2 + discSide / 2 - ringWidth / 2)
                    }
                    .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(MotionRole.scale(pressed: isPressed, reduceMotion: reduceMotion))
            .pointerCursor()
            .onHover { hovering = $0 }
        }

        private var disc: some View {
            ZStack {
                Circle().fill(isChosen ? ColorRole.ink : ColorRole.canvasSurface)
                if !isChosen { Circle().strokeBorder(ring, lineWidth: ringWidth) }
                Text(verbatim: NumberWording.count(node.count))
                    .typeRole(.quietMedium.figures)
                    .foregroundStyle(isChosen ? ColorRole.canvasSurface : figureInk)
                    .lineLimit(1)
            }
            .frame(width: discSide, height: discSide)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    ZStack {
                        Circle().fill(ColorRole.canvasSurface)
                        FrameGlyph(badge.icon, side: SizeRole.icon12, ink: badge.ink)
                    }
                    .frame(width: SizeRole.icon14, height: SizeRole.icon14)
                    .offset(x: badgeOffset, y: -badgeOffset)
                }
            }
        }

        private var ring: Color {
            switch node.mark {
            case .critical: ColorRole.stateCritical
            case .attention: ColorRole.stateAttention
            case .plain: ColorRole.faint
            case .empty: ColorRole.hairline
            }
        }

        private var figureInk: Color {
            switch node.mark {
            case .critical: ColorRole.stateCritical
            case .attention: ColorRole.stateAttention
            case .plain: ColorRole.ink
            case .empty: ColorRole.ink3
            }
        }

        private var badge: (icon: FrameIcon, ink: Color)? {
            switch node.mark {
            case .critical: (.xCircleFill, ColorRole.stateCritical)
            case .attention: (.warningFill, ColorRole.stateAttention)
            case .plain, .empty: nil
            }
        }
    }
}
