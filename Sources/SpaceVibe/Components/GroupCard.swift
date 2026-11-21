import AppKit
import SwiftUI

/// A group on the group surface (DS-R1 `group`, DS-R4 group corner; the mock's `.grp`): the block a page stacks its cards
/// from, grouped by a background step and space, never a divider line (FE-SP5). `regular` is a card (the mock's `.lc`,
/// 20 and 24 inside), `compact` a one-line group (12 and 24, the Limits "Unmeasurable" line). Its content runs top to bottom,
/// leading, `spacing` apart.
struct GroupCard<Content: View>: View {
    enum Inset: Hashable, Sendable {
        case regular, compact

        var vertical: CGFloat {
            switch self {
            case .regular: SpaceRole.step20
            case .compact: SpaceRole.step12
            }
        }

        var horizontal: CGFloat { SpaceRole.step24 }
    }

    var inset: Inset = .regular
    var spacing: CGFloat = SpaceRole.step16
    @ViewBuilder var content: Content

    init(inset: Inset = .regular, spacing: CGFloat = SpaceRole.step16, @ViewBuilder content: () -> Content) {
        self.inset = inset
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(.vertical, inset.vertical)
            .padding(.horizontal, inset.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupSurface()
            .accessibilityElement(children: .contain)
    }

    /// The widest a card's quiet sentence runs (the mock's `max-width: 62ch`: 62 widths of "0" in `quiet`), so a sentence in
    /// a wide card stays readable.
    static var sentenceWidth: CGFloat {
        (62 * ("0" as NSString).size(withAttributes: [.font: TypeRole.quiet.nsFont]).width).rounded()
    }
}
