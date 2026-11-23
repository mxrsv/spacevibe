import SwiftUI

/// A page's header with a band beside its hero (the mock's `.hdr`: Clean's bar and note, the Hooks lifecycle strip, the
/// other CLIs' lines on Rules), 24 pt after the hero. The hero sits at the header's top-left whatever the band does (RD58).
/// The band sits on the hero's bottom line, as the mock draws it, while it is no taller than the hero; a band that wraps
/// (Clean's note at 1000 pt) grows down from the hero's top instead, so it never pushes the hero down. Without a band the
/// hero stands alone.
struct PageHeader<Hero: View, Band: View>: View {
    private let hero: Hero
    private let band: Band

    init(@ViewBuilder hero: () -> Hero, @ViewBuilder band: () -> Band) {
        self.hero = hero()
        self.band = band()
    }

    var body: some View {
        PageHeaderLayout(spacing: SpaceRole.step24) {
            hero.fixedSize()
            band
        }
    }
}

/// `PageHeader`'s placement. Pure (`place`), so the test asks it with the sizes the hero and a band have at a window width.
struct PageHeaderLayout: Layout {
    var spacing: CGFloat

    struct Placement: Equatable {
        var hero: CGRect
        var band: CGRect?
        var size: CGSize
    }

    /// The hero at the origin; the band after it, its bottom on the hero's while it is no taller, else its top on the hero's.
    /// `width` is the width offered to the header (nil: as wide as hero and band need).
    static func place(hero: CGSize, band: CGSize?, spacing: CGFloat, width: CGFloat?) -> Placement {
        let heroRect = CGRect(origin: .zero, size: hero)
        guard let band else { return Placement(hero: heroRect, band: nil, size: CGSize(width: width ?? hero.width, height: hero.height)) }
        let top = band.height <= hero.height ? hero.height - band.height : 0
        let bandRect = CGRect(origin: CGPoint(x: hero.width + spacing, y: top), size: band)
        return Placement(hero: heroRect, band: bandRect,
                         size: CGSize(width: width ?? bandRect.maxX, height: max(hero.height, band.height)))
    }

    /// The width a band is offered beside a hero `heroWidth` wide in a header `width` wide.
    static func bandWidth(header width: CGFloat?, heroWidth: CGFloat, spacing: CGFloat) -> CGFloat? {
        width.map { max(0, $0 - heroWidth - spacing) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = placement(width: bounds.width, subviews: subviews)
        guard let hero = subviews.first else { return }
        hero.place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: ProposedViewSize(placement.hero.size))
        if subviews.count > 1, let band = placement.band {
            subviews[1].place(at: CGPoint(x: bounds.minX + band.minX, y: bounds.minY + band.minY), proposal: ProposedViewSize(band.size))
        }
    }

    private func placement(width: CGFloat?, subviews: Subviews) -> Placement {
        guard let first = subviews.first else { return Placement(hero: .zero, band: nil, size: .zero) }
        let hero = first.sizeThatFits(.unspecified)
        let band = subviews.count > 1
            ? subviews[1].sizeThatFits(ProposedViewSize(width: Self.bandWidth(header: width, heroWidth: hero.width, spacing: spacing), height: nil))
            : nil
        return Self.place(hero: hero, band: band, spacing: spacing, width: width)
    }
}
