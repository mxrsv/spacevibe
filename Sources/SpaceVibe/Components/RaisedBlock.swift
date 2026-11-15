import SwiftUI

/// A raised block inside a card with no border: Settings' font size
/// sample and the note that says why updates are off. `surfaceRaised`, radius 8; `inset` is the space inside.
struct RaisedBlock<Content: View>: View {
    var inset: EdgeInsets = EdgeInsets(top: Space.s12, leading: Space.s12, bottom: Space.s12, trailing: Space.s12)
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous).fill(Palette.surfaceRaised))
    }
}
