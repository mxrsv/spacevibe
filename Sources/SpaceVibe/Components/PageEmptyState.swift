import AppKit
import SwiftUI

/// A page or list with nothing to show (DS-R10 "Empty"; RD32: say plainly what is missing; the mock's `.emp`), beside v5's
/// `QuietEmptyState`: the page's own icon at 40 in `ink3`, a `pageTitle` line, one or two quiet sentences at most 36
/// characters a line wide, and an optional action. It starts 72 below the top of its region (DS-R3) and is centred.
struct PageEmptyState<Action: View>: View {
    let icon: FrameIcon
    let title: String?
    let text: String
    @ViewBuilder var action: Action

    init(icon: FrameIcon, title: String? = nil, text: String, @ViewBuilder action: () -> Action) {
        self.icon = icon
        self.title = title
        self.text = text
        self.action = action()
    }

    var body: some View {
        VStack(spacing: SpaceRole.step12) {
            FrameGlyph(icon, side: SizeRole.icon40, ink: ColorRole.ink3)
            if let title {
                Text(title)
                    .typeRole(.pageTitle)
                    .foregroundStyle(ColorRole.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(text)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.textWidth)
            action
        }
        .padding(.top, SpaceRole.emptyStateTop)
        .padding(.horizontal, SpaceRole.step24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// 36 characters of `quiet` text (the mock's `max-width: 36ch`: CSS `ch` is the width of "0").
    static var textWidth: CGFloat {
        (36 * ("0" as NSString).size(withAttributes: [.font: TypeRole.quiet.nsFont]).width).rounded()
    }
}

extension PageEmptyState where Action == EmptyView {
    init(icon: FrameIcon, title: String? = nil, text: String) {
        self.init(icon: icon, title: title, text: text) { EmptyView() }
    }
}
