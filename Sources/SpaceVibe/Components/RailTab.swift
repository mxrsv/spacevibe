import SwiftUI

/// One section on the Settings rail: its glyph (24) above its name (12, 500), 96 x 60, radius 8. Like a sidebar item, the
/// chosen one changes only its fill (`sel`) and its tone (`fg`, `fg2` for the others); the others fill with `hover` under
/// the pointer.
struct RailTab: View {
    let title: String
    let glyph: ContentGlyph
    let isActive: Bool
    let select: () -> Void

    @Environment(\.specimenInteraction) private var specimen
    @State private var hovering = false

    var body: some View {
        let hovered = hovering || specimen.contains(.hover)
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.block, style: Metrics.Radius.cornerStyle)
        Button(action: select) {
            VStack(spacing: Space.s4) {
                SpaceVibeIcon(content: glyph, size: .large)
                Text(title).spaceVibeText(.metaLabel)
            }
            .foregroundStyle(isActive || hovered ? Palette.fg : Palette.fg2)
            .frame(width: Metrics.railTabWidth, height: Metrics.railTabHeight)
            .background(shape.fill(isActive ? Palette.sel : (hovered ? Palette.hover : .clear)))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .spaceVibeFocusable(cornerRadius: Metrics.Radius.block)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
