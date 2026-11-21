import SwiftUI

/// A stand-in line while the first read has not answered (RD-R13 scanning; the mock's `.sk`): 10 high, the `hoverFill` step at
/// a 6 corner, a share of the width it is given. Still: no shimmer (DS-R9). Hidden from VoiceOver; the block it stands in
/// for says what is being read. The one skeleton bar: a card's lines (`Length`) and the table rows of `SkeletonRows` draw it.
struct SkeletonLine: View {
    /// The mock's two lengths, 60% and 48% of the width.
    enum Length: Hashable, Sendable {
        case long, short

        var share: CGFloat {
            switch self {
            case .long: 0.6
            case .short: 0.48
            }
        }
    }

    /// The share of the width the bar takes, 0 to 1.
    let share: CGFloat

    init(_ length: Length) {
        share = length.share
    }

    init(share: CGFloat) {
        self.share = min(1, max(0, share))
    }

    var body: some View {
        GeometryReader { proxy in
            CornerRoleShape(.radius(RadiusRole.step6))
                .fill(ColorRole.hoverFill)
                .frame(width: proxy.size.width * share)
        }
        .frame(height: SpaceRole.step10)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

/// Rows that stand in for a list still being read (the mock's `skel`): `count` table-height rows, each one `SkeletonLine` of
/// a stable, varied width. Put them in a `RowGroup`. Hidden from VoiceOver: the scanning banner above says what is read.
struct SkeletonRows: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<max(0, count), id: \.self) { index in
                SkeletonLine(share: Self.share(index))
                    .padding(.horizontal, SpaceRole.step12)
                    .frame(height: SizeRole.tableRow)
            }
        }
        .accessibilityHidden(true)
    }

    /// The mock's widths: 46% plus a step of 13 points modulo 40, so the rows differ but never change between renders.
    static func share(_ index: Int) -> CGFloat { CGFloat(46 + (index * 13) % 40) / 100 }
}
