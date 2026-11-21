import AppKit
import SwiftUI

/// A text role of the design-system spec (DS-R2): one size, its line height, one weight and one face. New-frame views take
/// a role with `.typeRole(_:)` and never build a font, set a weight or change letter-spacing themselves (AR6; v5 roles stay in
/// `SpaceVibeType`).
///
/// - Faces: SF Pro for text, SF Pro Rounded for figures only (RD6: the hero, a Window's figure, counts in tables and tiles,
///   sizes, sidebar values; `figures` gives any role its rounded twin), SF Mono for paths, commands, rule text and Hook labels.
/// - Weights: 400, and 500 only through the roles that carry it (`hero`, `windowFigure`, `pageTitle`, `bodyMedium`,
///   `quietMedium`); 600 exists only as `sidebarLabel` (RD23). No accessor turns another role to 500, so a screen cannot.
/// - Sizes are fixed points: the v5 Font size setting (`TypeScale`) does not move them.
/// - Digits are tabular in every role, as the mock's `font-variant-numeric: tabular-nums` on the whole window.
/// - Names (AR6): the spec's `figure`, `title`, `body` and `caption` are v5 `SpaceVibeType` names with other values, so here
///   they are `windowFigure`, `pageTitle`, `bodyText` and `axisCaption`; `all` gives each role's spec name.
struct TypeRole: Hashable, Sendable {
    enum Face: Hashable, Sendable {
        case text, figures, mono

        var design: Font.Design {
            switch self {
            case .text: .default
            case .figures: .rounded
            case .mono: .monospaced
            }
        }
    }

    enum Weight: Hashable, Sendable {
        /// 400, 500, and 600 for sidebar labels only.
        case regular, medium, sidebarLabel

        var font: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .sidebarLabel: .semibold
            }
        }

        var nsFont: NSFont.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .sidebarLabel: .semibold
            }
        }
    }

    let size: CGFloat
    /// The line box, like CSS `line-height`.
    let lineHeight: CGFloat
    let weight: Weight
    let face: Face

    private init(size: CGFloat, lineHeight: CGFloat, weight: Weight, face: Face) {
        self.size = size
        self.lineHeight = lineHeight
        self.weight = weight
        self.face = face
    }

    /// The page's one answer.
    static let hero = TypeRole(size: 40, lineHeight: 44, weight: .medium, face: .figures)
    /// A Window's share left.
    static let windowFigure = TypeRole(size: 22, lineHeight: 26, weight: .medium, face: .figures)
    /// The page title, an empty state's title.
    static let pageTitle = TypeRole(size: 15, lineHeight: 20, weight: .medium, face: .text)
    /// The unit beside the hero's figure ("MB", "% left"): `pageTitle`'s size at 400, in SF Pro (the mock's `.hero .fg small`,
    /// `400 15px/20px`), so the unit reads quieter than the figure.
    static let heroUnit = TypeRole(size: 15, lineHeight: 20, weight: .regular, face: .text)
    /// Rows, buttons, names.
    static let bodyText = TypeRole(size: 13, lineHeight: 18, weight: .regular, face: .text)
    /// `bodyText` at 500 (DS-R2 "body 400, 500"): a row's name, a button's label, a group head.
    static let bodyMedium = TypeRole(size: 13, lineHeight: 18, weight: .medium, face: .text)
    /// Sub-lines, notes, sidebar values.
    static let quiet = TypeRole(size: 12, lineHeight: 16, weight: .regular, face: .text)
    /// `quiet` at 500, only where the mock sets 12 at 500 (owner 2026-11-21): a small button's label (`.rb`), a sidebar
    /// group head (`.sbg h6`), an inspector section head (`.in .sec>h5`), and the count beside a thin bar in a table cell
    /// (`.rc b`, the Hooks Runs cell; `.rch b`, the Sessions cell of Skills and Subagents, is the same block), which takes
    /// `.figures`. A zero count there stays `quiet` (`.rc b.z`).
    static let quietMedium = TypeRole(size: 12, lineHeight: 16, weight: .medium, face: .text)
    /// Chart axes, legends and tile captions only.
    static let axisCaption = TypeRole(size: 11, lineHeight: 14, weight: .regular, face: .text)
    /// Paths, commands, rule text, Hook labels.
    static let mono = TypeRole(size: 12, lineHeight: 16, weight: .regular, face: .mono)
    /// A sidebar page label: `bodyText` at 600, the one place that weight is used (RD23).
    static let sidebarLabel = TypeRole(size: 13, lineHeight: 18, weight: .sidebarLabel, face: .text)

    /// Every role: its name here, the spec's name, the role. In the spec's order; the specimen draws them, the tests walk them.
    static let all: [(name: String, specName: String, role: TypeRole)] = [
        ("hero", "hero", hero), ("heroUnit", "hero unit", heroUnit), ("windowFigure", "figure", windowFigure),
        ("pageTitle", "title", pageTitle),
        ("bodyText", "body", bodyText), ("bodyMedium", "body 500", bodyMedium), ("quiet", "quiet", quiet),
        ("quietMedium", "quiet 500", quietMedium), ("axisCaption", "caption", axisCaption),
        ("mono", "mono", mono), ("sidebarLabel", "body 600", sidebarLabel),
    ]

    /// The same role with SF Pro Rounded, for a figure set in a text role (a count in a row, a size, a sidebar value).
    /// A mono role stays mono: paths and commands keep SF Mono.
    var figures: TypeRole {
        face == .mono ? self : TypeRole(size: size, lineHeight: lineHeight, weight: weight, face: .figures)
    }

    var font: Font { .system(size: size, weight: weight.font, design: face.design).monospacedDigit() }

    /// The AppKit font with the same face, for measuring.
    var nsFont: NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight.nsFont)
        switch face {
        case .text: return base
        case .figures: return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        case .mono: return NSFont.monospacedSystemFont(ofSize: size, weight: weight.nsFont)
        }
    }

    /// Ascent, descent and leading of the face at this size.
    var naturalLineHeight: CGFloat {
        let font = nsFont
        return font.ascender - font.descender + font.leading
    }

    /// What SwiftUI adds between lines so that every line takes `lineHeight`.
    var lineSpacing: CGFloat { max(0, lineHeight - naturalLineHeight) }

    /// Half the line box's leading, above the first line and below the last, so one line of text fills `lineHeight` as the
    /// mock's CSS draws it.
    var halfLeading: CGFloat { max(0, (lineHeight - naturalLineHeight) / 2) }
}

extension View {
    /// The role's font and line spacing. The colour comes from a `ColorRole`; letter-spacing is never changed (RD-R5).
    func typeRole(_ role: TypeRole) -> some View {
        font(role.font).lineSpacing(role.lineSpacing)
    }
}

extension Text {
    /// The `Text`-returning form, for concatenation.
    func typeRole(_ role: TypeRole) -> Text { font(role.font) }
}
