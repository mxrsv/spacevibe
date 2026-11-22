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

    /// From 100 Hooks the count needs more than the 22 pt disc: the disc grows into a capsule around it.
    var growsDisc: Bool { count >= 100 }

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
///
/// An event's name is never cut by truncation (`UserPromptSubmit` whole). The nodes share the strip's width as the mock's
/// `flex:1` does while every name fits; when they do not (ten events and more beside the hero), each node takes its name's
/// width and the strip scrolls sideways instead. Then the trailing edge fades out over `fadeWidth` (RB-F3: never a name cut
/// mid-glyph at a hard edge), and the row ends with as much room, so the last name scrolls clear of the fade. A headless shot
/// has no scroll view: it shows what fits, faded at the same edge.
struct LifecycleStrip: View {
    let nodes: [LifecycleNode]
    /// The event the list is filtered to, if any.
    let chosen: String?
    let pick: (String) -> Void
    @Environment(\.isShotRendering) private var isShotRendering
    /// The strip's own width, measured: what the nodes share inside the scroll view.
    @State private var room: CGFloat = 0
    /// The row's width before its end room, measured: wider than `room` when the names do not fit.
    @State private var lineWidth: CGFloat = 0

    /// How far the trailing fade reaches, and the room the row ends with when it overflows.
    static let fadeWidth = SpaceRole.step24

    /// Whether the row runs past the strip, so the trailing edge fades. Pure, for the tests.
    static func overflows(lineWidth: CGFloat, room: CGFloat) -> Bool { room > 0 && lineWidth > room + 0.5 }

    var body: some View {
        Group {
            if isShotRendering {
                // A headless shot has no scroll view: every node at its share when the names fit, otherwise the names at
                // their widths, cut at the edge under the fade.
                ViewThatFits(in: .horizontal) {
                    line(minWidth: nil)
                    line(minWidth: nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()
                        .mask { LifecycleEdgeFade() }
                }
            } else {
                let overflows = Self.overflows(lineWidth: lineWidth, room: room)
                ScrollView(.horizontal, showsIndicators: false) {
                    line(minWidth: room > 0 ? room : nil)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { lineWidth = $0 }
                        .padding(.trailing, overflows ? Self.fadeWidth : 0)
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { room = $0 }
                .mask {
                    if overflows { LifecycleEdgeFade() } else { Rectangle() }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hooks per event, in firing order")
    }

    private func line(minWidth: CGFloat?) -> some View {
        LifecycleRowLayout(minWidth: minWidth) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                LifecycleNodeButton(node: node, isChosen: chosen == node.event, isFirst: index == 0,
                                    isLast: index == nodes.count - 1) { pick(node.event) }
            }
        }
    }
}

/// The strip's mask while its row runs past it: opaque, then fading to nothing over the trailing `fadeWidth`. Only the
/// alpha counts in a mask, so the ink is any opaque role.
private struct LifecycleEdgeFade: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [ColorRole.ink, ColorRole.ink.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: LifecycleStrip.fadeWidth)
        }
    }
}

/// The strip's row: the nodes side by side, top-aligned. With room for every name at an equal share, the shares are equal
/// (the mock's `flex:1`); with room for the names but not equal shares, each node gets its name's width and an equal part
/// of what is left; without room, each node gets its name's width and the row runs past the room (the scroll view scrolls,
/// a shot cuts). `minWidth` is the room when the row sits in a scroll view (which proposes no width); otherwise the
/// proposal is.
struct LifecycleRowLayout: Layout {
    var minWidth: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let sum = ideals.reduce(0) { $0 + $1.width }
        let height = ideals.map(\.height).max() ?? 0
        if let minWidth { return CGSize(width: max(minWidth, sum), height: height) }
        return CGSize(width: proposal.width ?? sum, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let widths = Self.widths(names: ideals.map(\.width), room: bounds.width)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: widths[index], height: ideals[index].height))
            x += widths[index]
        }
    }

    /// Each node's width from its name's width (`names`, padding included) and the room. Never below a node's name. Pure.
    static func widths(names: [CGFloat], room: CGFloat) -> [CGFloat] {
        guard !names.isEmpty else { return [] }
        let count = CGFloat(names.count)
        let share = room / count
        if (names.max() ?? 0) <= share { return names.map { _ in share } }
        let sum = names.reduce(0, +)
        guard sum < room else { return names }
        let extra = (room - sum) / count
        return names.map { $0 + extra }
    }
}

/// The disc's side and ring, and its badge's offset (`BlockRole.lifecycleDisc`, `lifecycleRing`, `lifecycleBadgeOffset`).
private let discSide = BlockRole.lifecycleDisc
private let ringWidth = BlockRole.lifecycleRing
private let badgeOffset = BlockRole.lifecycleBadgeOffset

private struct LifecycleNodeButton: View {
    let node: LifecycleNode
    let isChosen: Bool
    let isFirst: Bool
    let isLast: Bool
    let press: () -> Void

    var body: some View {
        Button(action: press) { EmptyView() }
            .buttonStyle(LifecycleNodeStyle(node: node, isChosen: isChosen, isFirst: isFirst, isLast: isLast))
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
    let isLast: Bool

    func makeBody(configuration: Configuration) -> some View {
        NodeBody(node: node, isChosen: isChosen, isFirst: isFirst, isLast: isLast, isPressed: configuration.isPressed)
    }

    private struct NodeBody: View {
        let node: LifecycleNode
        let isChosen: Bool
        let isFirst: Bool
        let isLast: Bool
        let isPressed: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            VStack(spacing: SpaceRole.step6) {
                disc
                // Never cut (the mock's `white-space:nowrap`): the strip makes room or scrolls instead.
                Text(verbatim: node.event)
                    .typeRole(.axisCaption)
                    .foregroundStyle(isChosen || hovering ? ColorRole.ink : ColorRole.ink3)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, SpaceRole.step4)
            }
            .padding(.top, SpaceRole.step2)
            .frame(maxWidth: .infinity)
            // The line through the nodes (the mock's `.nd::before`), behind the disc: each node draws its own halves, from
            // its left edge to its centre and from its centre to its right edge, so nodes of any width join up.
            .background(alignment: .top) {
                HStack(spacing: 0) {
                    halfLine.opacity(isFirst ? 0 : 1)
                    halfLine.opacity(isLast ? 0 : 1)
                }
                .padding(.top, SpaceRole.step2 + discSide / 2 - ringWidth / 2)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .scaleEffect(MotionRole.scale(pressed: isPressed, reduceMotion: reduceMotion))
            .pointerCursor()
            .onHover { hovering = $0 }
        }

        private var halfLine: some View {
            // The connector is a track: `faint` at full (RD49 keeps `dim` for an off logo).
            Rectangle()
                .fill(ColorRole.faint)
                .frame(maxWidth: .infinity)
                .frame(height: ringWidth)
        }

        /// A 22 pt disc up to 99; from 100 it grows sideways into a capsule around the whole count (RB-F3: "1,006" never
        /// spills out of its disc), the same height, ring and badge.
        private var disc: some View {
            FigureText(NumberWording.count(node.count), role: .quietMedium)
                .foregroundStyle(isChosen ? ColorRole.canvasSurface : figureInk)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, node.growsDisc ? SpaceRole.step6 : 0)
                .frame(minWidth: discSide, minHeight: discSide, maxHeight: discSide)
                .background {
                    Capsule().fill(isChosen ? ColorRole.ink : ColorRole.canvasSurface)
                    if !isChosen { Capsule().strokeBorder(ring, lineWidth: ringWidth) }
                }
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
