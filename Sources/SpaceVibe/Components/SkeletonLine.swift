import SwiftUI

/// A stand-in line while the first read has not answered (RD-R13 scanning; the mock's `.sk`): 10 high, the `hoverFill` step at
/// a 6 corner, a share of the width it is given. Still: no shimmer (DS-R9). Hidden from VoiceOver; the block it stands in
/// for says what is being read.
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

    let length: Length

    init(_ length: Length) {
        self.length = length
    }

    var body: some View {
        GeometryReader { proxy in
            CornerRoleShape(.radius(RadiusRole.step6))
                .fill(ColorRole.hoverFill)
                .frame(width: proxy.size.width * length.share)
        }
        .frame(height: SpaceRole.step10)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
