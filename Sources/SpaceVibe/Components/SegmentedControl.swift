import SwiftUI

struct SegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }

    init(_ title: String, value: Value) {
        self.title = title
        self.value = value
    }
}

/// A one-of-N switch (Settings > Font size). Always has a selection; Left and Right arrows move it while a segment has
/// focus. 28 high so it fits a card header: the frame is a normal button's surface (`bgRaise`, a `hair2` edge, the top-edge
/// highlight, radius 6) with 24 pt segments inside it; the selected segment takes the `sel` fill and 600, a hovered one
/// `hover`. Every segment reserves its 600 width so the control never changes width.
struct SegmentedControl<Value: Hashable>: View {
    let label: String
    let options: [SegmentOption<Value>]
    @Binding var selection: Value

    @FocusState private var focused: Value?
    @State private var hovered: Value?

    var body: some View {
        let frame = RoundedRectangle(cornerRadius: Metrics.Radius.control, style: Metrics.Radius.cornerStyle)
        HStack(spacing: 0) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(Space.s2)
        .frame(height: Metrics.ActionButton.compactHeight)
        .background(frame.fill(Palette.bgRaise))
        .overlay { TopEdgeHighlight(radius: Metrics.Radius.control).fill(Palette.hi).allowsHitTesting(false) }
        .overlay { frame.strokeBorder(Palette.hair2, lineWidth: Metrics.Radius.edge).allowsHitTesting(false) }
        .onKeyPress(.leftArrow) { move(-1) }
        .onKeyPress(.rightArrow) { move(1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func segment(_ option: SegmentOption<Value>) -> some View {
        let isOn = option.value == selection
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.small, style: Metrics.Radius.cornerStyle)
        return Button {
            selection = option.value
        } label: {
            // The hidden 600 copy holds the width; the visible title sits on it.
            Text(option.title)
                .spaceVibeText(Self.selectedType)
                .hidden()
                .overlay { Text(option.title).spaceVibeText(isOn ? Self.selectedType : .metaLabel, tone: isOn ? .primary : .secondary) }
                .padding(.horizontal, Space.s8)
                .frame(height: Metrics.segmentHeight)
                .background(shape.fill(isOn ? Palette.sel : (hovered == option.value ? Palette.hover : .clear)))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovered = $0 ? option.value : (hovered == option.value ? nil : hovered) }
        .focused($focused, equals: option.value)
        .focusEffectDisabled()
        .focusFill(focused == option.value, cornerRadius: Metrics.Radius.small)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityLabel(option.title)
    }

    private static var selectedType: SpaceVibeType { SpaceVibeType.metaLabel.weight(.semibold) }

    private func move(_ step: Int) -> KeyPress.Result {
        guard focused != nil, let index = options.firstIndex(where: { $0.value == selection }) else { return .ignored }
        let next = options[(index + step + options.count) % options.count].value
        selection = next
        focused = next
        return .handled
    }
}
