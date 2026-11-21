import SwiftUI

extension View {
    /// The group ground (DS-R10 "Group"; the mock's `.grp`), the one implementation of it: the group surface in the look's
    /// group corner, clipped, so content groups by a background step and space, never by divider lines (FE-SP5). Rows go in
    /// `RowGroup`, a padded card is `GroupCard`; both stand on this.
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
