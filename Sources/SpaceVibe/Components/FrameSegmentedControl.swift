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

/// The new frame's segmented control (DS-R10 "Segmented control"; the mock's `.seg`), beside v5's `SegmentedControl`: a
/// regular 32 track (inner segments 28, inset 2) on the control ground (the system glass in Glass, the control fill with a
/// hairline in Solid). The chosen segment takes the neutral selection fill and `ink` (never the primary, RD-R9); the others
/// are `ink2` and show the hover fill under the pointer. Keyboard focus is the RD29 bar, not a ring (D57). It is a radio
/// group for VoiceOver: each segment is a button that reads its title, count and whether it is selected.
struct FrameSegmentedControl: View {
    let segments: [FrameSegment]
    let selection: String
    /// What the control chooses, for VoiceOver ("Activity list").
    let label: String
    let select: (String) -> Void

    @Environment(\.materialLook) private var look

    var body: some View {
        let corner = RadiusRole.controlCorner(look)
        HStack(spacing: SpaceRole.step2) {
            ForEach(segments) { segment in
                Button { select(segment.id) } label: {
                    HStack(spacing: SpaceRole.step6) {
                        Text(segment.title).typeRole(.bodyMedium)
                        if let count = segment.count {
                            Text(verbatim: NumberWording.count(count))
                                .typeRole(.quiet.figures)
                                .foregroundStyle(segment.id == selection ? ColorRole.ink2 : ColorRole.ink3)
                        }
                    }
                }
                .buttonStyle(FrameSegmentStyle(isSelected: segment.id == selection, corner: Self.innerCorner(corner)))
                .focusEffectDisabled()
                .accessibilityLabel(segment.spoken)
                .accessibilityAddTraits(segment.id == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(SizeRole.segmentedInset)
        .frame(height: SizeRole.segmentedRegular)
        .frameGlass(in: corner, solid: ColorRole.controlFill)
        .overlay {
            if look == .solid { CornerRoleShape(corner).strokeBorder(ColorRole.hairline, lineWidth: 1) }
        }
        .fixedSize()
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
    let corner: CornerRole

    func makeBody(configuration: Configuration) -> some View {
        SegmentBody(configuration: configuration, isSelected: isSelected, corner: corner)
    }

    private struct SegmentBody: View {
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool
        let corner: CornerRole
        @Environment(\.isFocused) private var isFocused
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let hovered = hovering || specimen.contains(.hover)
            let shape = CornerRoleShape(corner)
            configuration.label
                .lineLimit(1)
                .foregroundStyle(isSelected ? ColorRole.ink : ColorRole.ink2)
                .padding(.horizontal, SpaceRole.step10)
                .frame(height: SizeRole.segmentRegular)
                .background {
                    if isSelected || configuration.isPressed {
                        shape.fill(ColorRole.selectionFill)
                    } else if hovered {
                        shape.fill(ColorRole.hoverFill)
                    }
                }
                .overlay { if isSelected { shape.strokeBorder(ColorRole.hairline, lineWidth: 0.5) } }
                .contentShape(shape)
                .focusBar(isFocused || specimen.contains(.focus), inset: SpaceRole.step2)
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}
