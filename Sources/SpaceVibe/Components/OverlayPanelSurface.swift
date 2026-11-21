import SwiftUI

extension View {
    /// The ground of every overlay block (toast, menu, popover, sheet, DS-R8; the mock's `.toast`, `.cpop`, `.tpop`,
    /// `.alert`): in Glass the system glass at the popover corner, in Solid graphite `groupSurface` with a hairline edge; the
    /// one `float` shadow in both. The look comes from the frame (`\.materialLook`, AR8), so no block takes it as a parameter.
    /// `corner` overrides the popover corner.
    func overlayPanelSurface(corner: CornerRole? = nil) -> some View {
        modifier(OverlayPanelSurface(corner: corner))
    }
}

private struct OverlayPanelSurface: ViewModifier {
    let corner: CornerRole?
    @Environment(\.materialLook) private var look

    func body(content: Content) -> some View {
        let corner = corner ?? RadiusRole.popoverCorner(look)
        let shape = CornerRoleShape(corner)
        Group {
            switch look {
            case .glass:
                content.frameGlass(in: corner, solid: ColorRole.groupSurface)
            case .solid:
                content
                    .background(shape.fill(ColorRole.groupSurface))
                    .overlay(shape.strokeBorder(ColorRole.hairline, lineWidth: 1))
                    .clipShape(shape)
            }
        }
        .shadow(color: ColorRole.floatShadow, radius: ShadowRole.floatRadius, y: ShadowRole.floatOffsetY + ShadowRole.floatSpread)
    }
}
