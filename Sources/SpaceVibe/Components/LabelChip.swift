import SwiftUI

/// A short label on the control fill (the mock's `.chip`): an optional glyph in its own ink and a `quiet` word, 20 high,
/// never wrapping. Used where a row names a fact about itself ("Whole tool"). The word is `controlSecondaryInk` and the
/// default glyph `controlQuietInk`, so both keep their ratio on the fill under Increase Contrast (DS-R1), where the chip also
/// takes the `hair` edge.
struct LabelChip: View {
    let text: String
    var icon: FrameIcon?
    var iconInk: Color = ColorRole.controlQuietInk

    init(_ text: String, icon: FrameIcon? = nil, iconInk: Color = ColorRole.controlQuietInk) {
        self.text = text
        self.icon = icon
        self.iconInk = iconInk
    }

    var body: some View {
        let shape = CornerRoleShape(.radius(RadiusRole.step6))
        HStack(spacing: SpaceRole.step4) {
            if let icon { FrameGlyph(icon, side: SizeRole.icon12, ink: iconInk) }
            Text(text)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.controlSecondaryInk)
                .lineLimit(1)
        }
        .padding(.horizontal, SpaceRole.step6)
        .frame(height: SizeRole.controlMini)
        .background(shape.fill(ColorRole.controlFill))
        .overlay(shape.strokeBorder(ColorRole.controlEdge, lineWidth: StrokeRole.hairline))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}
