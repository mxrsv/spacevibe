import SwiftUI

/// A new-frame icon at any of DS-R6's sizes (12, 14, 16, 20, 40), which `SpaceVibeIcon`'s v5 `IconSize` cannot all name (it
/// has no 40): the same glyph data and the same drawing (fill, the set's outline, the own set's round lines), in the current
/// foreground style or `ink`. Hidden from VoiceOver unless it has a `label`.
struct FrameGlyph: View {
    let icon: FrameIcon
    var side: CGFloat = SizeRole.icon16
    var ink: Color?
    var label: String?

    init(_ icon: FrameIcon, side: CGFloat = SizeRole.icon16, ink: Color? = nil, label: String? = nil) {
        self.icon = icon
        self.side = side
        self.ink = ink
        self.label = label
    }

    var body: some View {
        let source = icon.glyph
        let shape = GlyphShape(glyph: source, layer: .solid)
        let drawn = ZStack {
            shape.fill(style: FillStyle(eoFill: source.evenOdd(.solid)))
            if source.outlineWidth > 0 {
                shape.stroke(style: StrokeStyle(lineWidth: source.outlineWidth * side / GlyphBox.side, lineJoin: .round))
            }
            if source.lineWidth > 0 {
                GlyphLineShape(glyph: source)
                    .stroke(style: StrokeStyle(lineWidth: source.lineWidth * side / GlyphBox.side, lineCap: .round, lineJoin: .round))
            }
        }
        .compositingGroup()
        .frame(width: side, height: side)
        Group {
            if let ink { drawn.foregroundStyle(ink) } else { drawn }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(label == nil)
        .accessibilityLabel(label ?? "")
    }
}

extension SpaceVibeIcon {
    /// An icon of the new frame, by the reference mock's name for it (`FrameIcon`), at one of DS-R6's sizes: `SizeRole.Icon`,
    /// never v5's `IconSize`, so a new-frame icon cannot reach a v5 metric.
    init(frame icon: FrameIcon, size: SizeRole.Icon = .control, ink: Color? = nil, label: String? = nil) {
        self.init(source: icon.glyph, side: size.points, ink: ink, label: label)
    }
}
