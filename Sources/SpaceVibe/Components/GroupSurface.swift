import SwiftUI

extension View {
    /// A group of rows on its own ground (DS-R10 "Group"; the mock's `.grp`): the group surface in the look's group corner,
    /// clipped, so rows group by a background step and space, never by divider lines (FE-SP5).
    func groupSurface() -> some View {
        modifier(GroupSurfaceGround())
    }
}

private struct GroupSurfaceGround: ViewModifier {
    @Environment(\.materialLook) private var look

    func body(content: Content) -> some View {
        let shape = CornerRoleShape(RadiusRole.groupCorner(look))
        content
            .background(shape.fill(ColorRole.groupSurface))
            .clipShape(shape)
    }
}
