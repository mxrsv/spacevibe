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

/// The new frame's segmented control (DS-R10 "Segmented control"; the mock's `.seg`), beside v5's `SegmentedControl`. Two
/// sizes only (DS-R5): regular, a 32 track with 28 segments, and small, a 26 track with 22 segments (a sheet's mode switch,
/// a row's age control); both inset 2, on the control ground (the system glass in Glass, the control fill with a hairline in
/// Solid). The chosen segment takes the neutral selection fill and `ink` (never the primary, RD-R9); the others are `ink2`
/// and show the hover fill under the pointer. A segment with the keyboard focus draws the RD29 bar, not a ring (D57), and
/// ← → choose the segment beside it and take the focus with them, without wrapping. It is a radio group for VoiceOver: each
/// segment is a button that reads its title, count and whether it is selected.
struct FrameSegmentedControl: View {
    enum Size: Hashable, Sendable {
        case regular, small

        var track: CGFloat { self == .regular ? SizeRole.segmentedRegular : SizeRole.segmentedSmall }
        var segment: CGFloat { self == .regular ? SizeRole.segmentRegular : SizeRole.segmentSmall }
        var typeRole: TypeRole { self == .regular ? .bodyMedium : .quietMedium }
    }

    let segments: [FrameSegment]
    let selection: String
    /// What the control chooses, for VoiceOver ("Activity list").
    let label: String
    var size: Size = .regular
    let select: (String) -> Void

    @Environment(\.materialLook) private var look
    /// The segment that holds the keyboard focus itself (`FocusBarRule`).
    @FocusState private var focused: String?

    init(segments: [FrameSegment], selection: String, label: String, size: Size = .regular, select: @escaping (String) -> Void) {
        self.segments = segments
        self.selection = selection
        self.label = label
        self.size = size
        self.select = select
    }

    var body: some View {
        let corner = RadiusRole.controlCorner(look)
        HStack(spacing: SpaceRole.step2) {
            ForEach(segments) { segment in
                Button { select(segment.id) } label: {
                    HStack(spacing: SpaceRole.step6) {
                        Text(segment.title).typeRole(size.typeRole)
                        if let count = segment.count {
                            Text(verbatim: NumberWording.count(count))
                                .typeRole(.quiet.figures)
                                .foregroundStyle(segment.id == selection ? ColorRole.ink2 : ColorRole.ink3)
                        }
                    }
                }
                .buttonStyle(FrameSegmentStyle(isSelected: segment.id == selection, isFocused: focused == segment.id,
                                               corner: Self.innerCorner(corner), height: size.segment))
                .focused($focused, equals: segment.id)
                .focusEffectDisabled()
                .accessibilityLabel(segment.spoken)
                .accessibilityAddTraits(segment.id == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(SizeRole.segmentedInset)
        .frame(height: size.track)
        .frameGlass(in: corner, solid: ColorRole.controlFill)
        .overlay {
            if look == .solid { CornerRoleShape(corner).strokeBorder(ColorRole.hairline, lineWidth: 1) }
        }
        .fixedSize()
        // A focused segment's arrows reach here: the neighbour is chosen and takes the focus (the mock's radio group).
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            guard let from = focused, press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
            let next = Self.step(from: from, by: press.key == .leftArrow ? -1 : 1, in: segments)
            guard next != from else { return .handled }
            select(next)
            focused = next
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// A segment's corner inside the track: the track's, less its inset (a capsule stays a capsule).
    static func innerCorner(_ corner: CornerRole) -> CornerRole {
        switch corner {
        case .capsule: .capsule
        case .radius(let value): .radius(max(0, value - SizeRole.segmentedInset))
        }
    }

    /// The id the arrow keys move to: the next or previous segment, without wrapping. Pure, so it is tested.
    static func step(from id: String, by delta: Int, in segments: [FrameSegment]) -> String {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return segments.first?.id ?? id }
        return segments[min(max(0, index + delta), segments.count - 1)].id
    }
}

private struct FrameSegmentStyle: ButtonStyle {
    let isSelected: Bool
    let isFocused: Bool
    let corner: CornerRole
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        SegmentBody(configuration: configuration, isSelected: isSelected, isFocused: isFocused, corner: corner, height: height)
    }

    private struct SegmentBody: View {
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool
        let isFocused: Bool
        let corner: CornerRole
        let height: CGFloat
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let hovered = hovering || specimen.contains(.hover)
            let shape = CornerRoleShape(corner)
            configuration.label
                .lineLimit(1)
                .foregroundStyle(isSelected ? ColorRole.ink : ColorRole.ink2)
                .padding(.horizontal, SpaceRole.step10)
                .frame(height: height)
                .background {
                    if isSelected || configuration.isPressed {
                        shape.fill(ColorRole.selectionFill)
                    } else if hovered {
                        shape.fill(ColorRole.hoverFill)
                    }
                }
                .overlay { if isSelected { shape.strokeBorder(ColorRole.hairline, lineWidth: 0.5) } }
                .contentShape(shape)
                .focusBar(FocusBarRule.isShown(ownFocus: isFocused, specimen: specimen.contains(.focus)), edge: corner)
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}
