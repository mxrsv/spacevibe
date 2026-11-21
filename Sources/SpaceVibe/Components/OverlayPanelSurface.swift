import SwiftUI

extension View {
    /// The ground of every overlay block (toast, menu, popover, sheet, DS-R8): graphite `groupSurface` with a hairline edge and
    /// the one `float` shadow, at the popover corner of the look. The one place the blocks paint an overlay, so the frame's
    /// Glass material (RB-S3's `frameGlass(in:interactive:solid:)`, read through `materialLook`) replaces it here alone;
    /// until then it draws Solid. `corner` overrides the popover corner (a toast's capsule-like control corner).
    func overlayPanelSurface(look: MaterialLook = .solid, corner: CornerRole? = nil) -> some View {
        modifier(OverlayPanelSurface(look: look, corner: corner ?? RadiusRole.popoverCorner(look)))
    }
}

private struct OverlayPanelSurface: ViewModifier {
    let look: MaterialLook
    let corner: CornerRole

    func body(content: Content) -> some View {
        let shape = PushButtonShape(corner: corner)
        content
            .background(shape.fill(ColorRole.groupSurface))
            .overlay(shape.strokeBorder(ColorRole.hairline, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: ColorRole.floatShadow, radius: ShadowRole.floatRadius, y: ShadowRole.floatOffsetY + ShadowRole.floatSpread)
    }
}
