import SwiftUI

/// The two layers of a glyph: the solid one and, in a duotone set, the lighter one.
enum GlyphLayer {
    case solid, light
}

/// The box every generated glyph is drawn in, whatever grid its set uses (the generator scales to it).
enum GlyphBox {
    static let side: CGFloat = 24
}

/// One glyph of a generated icon set (`CategoryIconData.swift`, `ContentIconData.swift`, `StateIconData.swift`, and for the new
/// frame `PageIconData.swift`, `InterfaceIconData.swift`, `SeverityIconData.swift`): its shapes in the 24 x 24 box and how the
/// set is drawn. `SpaceVibeIcon` draws any of them.
protocol GlyphSource: Sendable {
    /// The icon of the set this glyph is drawn from, for example `flash-line`.
    var iconName: String { get }
    /// False for a single-layer set (MingCute Line).
    var hasLightLayer: Bool { get }
    /// The opacity of the lighter layer.
    var layerOpacity: Double { get }
    /// A stroke in the glyph's colour added around every shape, in the 24 box (Phosphor's, as the mock draws it); 0 for none.
    var outlineWidth: CGFloat { get }
    /// The width of the glyph's stroked lines in the 24 box, drawn with round caps and joins over the solid layer; 0 for a set
    /// that only fills. Only SpaceVibe's own page set (`PageGlyph`) has lines.
    var lineWidth: CGFloat { get }
    func evenOdd(_ layer: GlyphLayer) -> Bool
    func draw(_ layer: GlyphLayer, into p: inout GlyphPen)
    /// The stroked lines, in the 24 box.
    func drawLines(into p: inout GlyphPen)
}

extension GlyphSource {
    var lineWidth: CGFloat { 0 }
    func drawLines(into p: inout GlyphPen) {}
}

/// Writes one layer of a generated glyph into a `Path`, in the glyph's 24 x 24 box.
struct GlyphPen {
    var path = Path()

    mutating func m(_ x: CGFloat, _ y: CGFloat) { path.move(to: CGPoint(x: x, y: y)) }
    mutating func l(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: CGPoint(x: x, y: y)) }
    mutating func c(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
    }
    mutating func z() { path.closeSubpath() }
}

extension GlyphSource {
    /// One layer as a path in the 24 x 24 box.
    func path(_ layer: GlyphLayer) -> Path {
        var pen = GlyphPen()
        draw(layer, into: &pen)
        return pen.path
    }

    /// The stroked lines as one path in the 24 x 24 box (the centre lines, before the stroke is applied).
    func linePath() -> Path {
        var pen = GlyphPen()
        drawLines(into: &pen)
        return pen.path
    }
}

extension GlyphBox {
    /// Scales the 24 pt box to `rect` (square, centred).
    static func transform(into rect: CGRect) -> CGAffineTransform {
        let side = min(rect.width, rect.height)
        let scale = side / Self.side
        return CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2).scaledBy(x: scale, y: scale)
    }
}

/// One layer of a glyph, scaled from its 24 pt box to the rect it is given (square, centred).
struct GlyphShape: Shape {
    let glyph: any GlyphSource
    let layer: GlyphLayer

    func path(in rect: CGRect) -> Path {
        glyph.path(layer).applying(GlyphBox.transform(into: rect))
    }
}

/// The stroked lines of a glyph, scaled like `GlyphShape`; the caller strokes them.
struct GlyphLineShape: Shape {
    let glyph: any GlyphSource

    func path(in rect: CGRect) -> Path {
        glyph.linePath().applying(GlyphBox.transform(into: rect))
    }
}

/// The icon sizes: 16 for controls, tabs, rows, menus and the sidebar; 14 in popovers, file rows, notes and beside 12 pt text;
/// 12 for chevrons, checks and the filter-chip close; 24 in a pane head's tile (V5-R16). Never below 12. `row` stays for the
/// verdict box.
enum IconSize: CaseIterable {
    /// The verdict glyph in a verdict box (the kit's 20): 20.
    case row
    /// Buttons, tags, fields, cells, tabs, rows, menus and the v5 sidebar: 16.
    case control
    /// Beside 12 pt text (the usage legend, notes, palette hints, popovers, file rows): 14.
    case inline
    /// A chevron, a check, the filter-chip close: 12, the smallest.
    case small
    /// An empty state's mark and the pane head's tile: 24.
    case large

    var points: CGFloat {
        switch self {
        case .row: Metrics.iconRow
        case .control: Metrics.iconControl
        case .inline: Metrics.iconInline
        case .small: Metrics.iconSmall
        case .large: Metrics.iconLarge
        }
    }
}

/// An icon from one of the generated sets: its layers in one colour, the lighter at the set's `layerOpacity`. The colour is the
/// current foreground style, so an icon is neutral wherever it sits; `ink` is for the two places that tint one (a state tag, a
/// banner). Hidden from VoiceOver unless it has a `label`, for an icon that carries meaning on its own.
///
/// Each set has its own label, so a name that exists in two sets never reads two ways: `SpaceVibeIcon(category: .skill)`
/// (MingCute), `SpaceVibeIcon(content: .stack)` (Phosphor Duotone) and `SpaceVibeIcon(state: .checkCircle)` (Phosphor Bold). The
/// new frame picks by the mock's name instead: `SpaceVibeIcon(frame: .skills)` (own set), `SpaceVibeIcon(frame: .trash)`
/// (Phosphor Bold), `SpaceVibeIcon(frame: .warningFill)` (Phosphor Fill).
struct SpaceVibeIcon: View {
    let source: any GlyphSource
    var size: IconSize = .control
    var ink: Color?
    var label: String?

    init(source: any GlyphSource, size: IconSize = .control, ink: Color? = nil, label: String? = nil) {
        self.source = source
        self.size = size
        self.ink = ink
        self.label = label
    }

    init(category glyph: CategoryGlyph, size: IconSize = .control, ink: Color? = nil, label: String? = nil) {
        self.init(source: glyph, size: size, ink: ink, label: label)
    }

    init(content glyph: ContentGlyph, size: IconSize = .control, ink: Color? = nil, label: String? = nil) {
        self.init(source: glyph, size: size, ink: ink, label: label)
    }

    init(state glyph: StateGlyph, size: IconSize = .control, ink: Color? = nil, label: String? = nil) {
        self.init(source: glyph, size: size, ink: ink, label: label)
    }

    /// An icon of the new frame, by the reference mock's name for it (`FrameIcon`).
    init(frame icon: FrameIcon, size: IconSize = .control, ink: Color? = nil, label: String? = nil) {
        self.init(source: icon.glyph, size: size, ink: ink, label: label)
    }

    var body: some View {
        let drawn = ZStack {
            if source.hasLightLayer {
                GlyphLayerView(source: source, layer: .light, side: size.points).opacity(source.layerOpacity)
            }
            GlyphLayerView(source: source, layer: .solid, side: size.points)
        }
        .frame(width: size.points, height: size.points)
        Group {
            if let ink { drawn.foregroundStyle(ink) } else { drawn }
        }
        .modifier(IconAccessibility(label: label))
    }
}

/// A layer's fill, with the set's outline over it where it has one, and the solid layer's stroked lines in a set that has them
/// (round caps and joins, as the mock's SVG strokes them). One group, so the layer's opacity applies once and a line crossing a
/// dot never draws darker.
private struct GlyphLayerView: View {
    let source: any GlyphSource
    let layer: GlyphLayer
    let side: CGFloat

    var body: some View {
        let shape = GlyphShape(glyph: source, layer: layer)
        ZStack {
            shape.fill(style: FillStyle(eoFill: source.evenOdd(layer)))
            if source.outlineWidth > 0 {
                shape.stroke(style: StrokeStyle(lineWidth: source.outlineWidth * side / GlyphBox.side, lineJoin: .round))
            }
            if layer == .solid, source.lineWidth > 0 {
                GlyphLineShape(glyph: source)
                    .stroke(style: StrokeStyle(lineWidth: source.lineWidth * side / GlyphBox.side, lineCap: .round, lineJoin: .round))
            }
        }
        .compositingGroup()
    }
}

private struct IconAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityAddTraits(.isImage)
        } else {
            content.accessibilityHidden(true)
        }
    }
}
