import SwiftUI

/// One option of a `FrameSegmentedControl`: its id, its title and an optional count drawn quietly after the title (the mock's
/// `.seg b i`).
struct FrameSegment: Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    var count: Int?

    /// What VoiceOver reads: "Failures, 3".
    var spoken: String { [title, count.map(NumberWording.count)].compactMap { $0 }.joined(separator: ", ") }
}

/// The new frame's one segmented control (DS-R10 "Segmented control"), beside v5's `SegmentedControl`. Two sizes only
/// (DS-R5), each the mock's own block:
/// - regular (`.seg`): a 32 track with 28 segments on the control ground (the system glass in Glass, the control fill with a
///   hairline in Solid), labels `bodyMedium`, the corner following the look;
/// - small (`.age`, `.dial`: a row's age control, the permission dial): a 26 track with 22 segments, always the control fill
///   at radius 8 with radius 6 segments in both looks (no glass in content, DS-R8), labels `quiet` with `quietMedium` on the
///   chosen segment; each segment keeps the width of its 500 label, so choosing one moves nothing.
///
/// Both inset 2. The chosen segment takes the neutral selection fill and `ink` (never the primary, RD-R9); the others are
/// `controlSecondaryInk` (`ink2`, `ink` under Increase Contrast, DS-R1) and show the hover fill under the pointer. Under
/// Increase Contrast every track takes the `hair` edge (`ColorRole.controlEdge`). No segment is chosen while `selection` is
/// nil. A `pending` segment shows the pending mark and no segment takes a press until it clears (FE-L2). A segment with the
/// keyboard focus draws the RD29 bar, not a ring (D57), and ← → choose the segment beside it and take the focus with them,
/// without wrapping. It is a radio group for VoiceOver: each segment is a button that reads its title, count and whether it
/// is selected.
struct FrameSegmentedControl: View {
    enum Size: Hashable, Sendable {
        case regular, small

        var track: CGFloat { self == .regular ? SizeRole.controlRegular : SizeRole.controlSmall }
        var segment: CGFloat { self == .regular ? SizeRole.segmentRegular : SizeRole.segmentSmall }
        /// A segment's label: `bodyMedium` at regular; at small `quiet`, and `quietMedium` when chosen.
        func typeRole(chosen: Bool) -> TypeRole {
            self == .regular ? .bodyMedium : chosen ? .quietMedium : .quiet
        }
        var sidePadding: CGFloat { self == .regular ? SpaceRole.step10 : SpaceRole.step8 }
        var gap: CGFloat { self == .regular ? SpaceRole.step2 : 0 }

        /// The track's corner: the look's control corner at regular, radius 8 at small in both looks (the mock's `.age`).
        func trackCorner(_ look: MaterialLook) -> CornerRole {
            self == .regular ? RadiusRole.controlCorner(look) : .radius(RadiusRole.step8)
        }

        /// A segment's corner: the track's less its inset at regular (a capsule stays a capsule), radius 6 at small.
        func segmentCorner(_ look: MaterialLook) -> CornerRole {
            guard self == .regular else { return .radius(RadiusRole.step6) }
            switch trackCorner(look) {
            case .capsule: return .capsule
            case .radius(let value): return .radius(max(0, value - SizeRole.segmentedInset))
            }
        }

        /// Only the regular control sits on glass; a small one is content (DS-R8).
        func isOnGlass(_ look: MaterialLook) -> Bool { self == .regular && look == .glass }
    }

    let segments: [FrameSegment]
    let selection: String?
    /// What the control chooses, for VoiceOver ("Activity list").
    let label: String
    var size: Size = .regular
    /// The segment a write is moving to; while set, no segment takes a press.
    var pending: String?
    /// The track spans the width it is given, segments at its leading end; otherwise it hugs its segments.
    var fillsWidth = false
    let select: (String) -> Void

    @Environment(\.materialLook) private var look
    /// The segment that holds the keyboard focus itself (`FocusBarRule`).
    @FocusState private var focused: String?

    init(segments: [FrameSegment], selection: String?, label: String, size: Size = .regular, pending: String? = nil,
         fillsWidth: Bool = false, select: @escaping (String) -> Void) {
        self.segments = segments
        self.selection = selection
        self.label = label
        self.size = size
        self.pending = pending
        self.fillsWidth = fillsWidth
        self.select = select
    }

    /// Whether a press reaches `select`: never while a segment is pending. Pure, for the tests.
    static func takesPress(pending: String?) -> Bool { pending == nil }

    var body: some View {
        let corner = size.trackCorner(look)
        let onGlass = size.isOnGlass(look)
        HStack(spacing: size.gap) {
            ForEach(segments) { segment in
                let chosen = segment.id == selection
                Button { if Self.takesPress(pending: pending) { select(segment.id) } } label: {
                    HStack(spacing: SpaceRole.step6) {
                        if pending == segment.id { PendingMark() }
                        SegmentTitle(title: segment.title, size: size, chosen: chosen)
                        if let count = segment.count {
                            FigureText(NumberWording.count(count), role: .quiet)
                                .foregroundStyle(chosen ? ColorRole.controlSecondaryInk : ColorRole.controlQuietInk)
                        }
                    }
                }
                .buttonStyle(FrameSegmentStyle(isSelected: chosen, isFocused: focused == segment.id,
                                               corner: size.segmentCorner(look), size: size))
                .focused($focused, equals: segment.id)
                .focusEffectDisabled()
                .accessibilityLabel(segment.spoken)
                .accessibilityValue(pending == segment.id ? "Changing" : "")
                .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(SizeRole.segmentedInset)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .frame(height: size.track)
        .frameGlass(in: corner, solid: ColorRole.controlFill, when: onGlass)
        .background { if look == .glass && !onGlass { CornerRoleShape(corner).fill(ColorRole.controlFill) } }
        .overlay {
            // Solid's regular track always draws its hairline (the same grey as the edge under Increase Contrast); every
            // other track takes the edge under Increase Contrast only.
            CornerRoleShape(corner).strokeBorder(Self.edge(size: size, look: look), lineWidth: StrokeRole.hairline)
        }
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        // A focused segment's arrows reach here: the neighbour is chosen and takes the focus (the mock's radio group).
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            guard let from = focused, press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
            let next = Self.step(from: from, by: press.key == .leftArrow ? -1 : 1, in: segments)
            guard next != from, Self.takesPress(pending: pending) else { return .handled }
            select(next)
            focused = next
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// The track's edge: the hairline on Solid's regular track, otherwise the Increase Contrast edge.
    static func edge(size: Size, look: MaterialLook) -> Color {
        look == .solid && size == .regular ? ColorRole.hairline : ColorRole.controlEdge
    }

    /// The id the arrow keys move to: the next or previous segment, without wrapping. Pure, so it is tested.
    static func step(from id: String, by delta: Int, in segments: [FrameSegment]) -> String {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return segments.first?.id ?? id }
        return segments[min(max(0, index + delta), segments.count - 1)].id
    }
}

/// A segment's title. At small the chosen title is 500 and the others 400; each reserves the 500 width, so choosing a
/// segment never moves its neighbours.
private struct SegmentTitle: View {
    let title: String
    let size: FrameSegmentedControl.Size
    let chosen: Bool

    var body: some View {
        if size == .small {
            Text(title)
                .typeRole(.quietMedium)
                .hidden()
                .overlay { Text(title).typeRole(size.typeRole(chosen: chosen)) }
        } else {
            Text(title).typeRole(size.typeRole(chosen: chosen))
        }
    }
}

private struct FrameSegmentStyle: ButtonStyle {
    let isSelected: Bool
    let isFocused: Bool
    let corner: CornerRole
    let size: FrameSegmentedControl.Size

    func makeBody(configuration: Configuration) -> some View {
        SegmentBody(configuration: configuration, isSelected: isSelected, isFocused: isFocused, corner: corner, size: size)
    }

    private struct SegmentBody: View {
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool
        let isFocused: Bool
        let corner: CornerRole
        let size: FrameSegmentedControl.Size
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let hovered = isEnabled && (hovering || specimen.contains(.hover))
            let shape = CornerRoleShape(corner)
            configuration.label
                .lineLimit(1)
                .foregroundStyle(isSelected ? ColorRole.ink : ColorRole.controlSecondaryInk)
                .padding(.horizontal, size.sidePadding)
                .frame(height: size.segment)
                .background {
                    if isSelected || configuration.isPressed {
                        shape.fill(ColorRole.chosenSegmentFill)
                    } else if hovered {
                        shape.fill(ColorRole.hoverFill)
                    }
                }
                .overlay {
                    // The mock's `.seg b.on` edge; the small control's chosen segment has none (`.age b.on`).
                    if isSelected && size == .regular {
                        shape.strokeBorder(ColorRole.hairline, lineWidth: StrokeRole.selectedSegmentEdge)
                    }
                }
                .contentShape(shape)
                .opacity(isEnabled ? 1 : OpacityRole.disabled)
                .focusBar(FocusBarRule.isShown(ownFocus: isFocused, specimen: specimen.contains(.focus)), edge: corner)
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}
