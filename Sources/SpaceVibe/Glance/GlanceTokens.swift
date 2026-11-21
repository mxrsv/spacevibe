import SwiftUI

/// The glance widget's surface and text tokens, the one seam between the shipped look and the redesign's (spec
/// `docs/specs/2026-11-20-spacevibe-redesign.md`, RD34, RD-R3: GW1 to GW22 carry over, only the surface and text tokens
/// change). The controller picks the set once from `LaunchMode.Surface` and every widget view hands it to its parts through
/// the environment, so the parts never ask which build they are in.
///
/// - `.v5` (in `Components/GlanceStripParts.swift`, beside the v5 tokens it names) is exactly what the widget drew before the
///   seam: the shipped app and every build with the switch off look as they did (FE-P9).
/// - `.redesign` takes the design system's roles (DS-R1, DS-R2) for the ground, its edge, the hover and well fills, the
///   faint mark, the ring's track and the text inks and type.
/// - Neither set holds a state colour: the session glyph inks (GW20, `SessionStateGlyph`) and a counting window's ring and
///   clock tones (LC9) stay the widget's own in both (GW22).
/// - Geometry (sizes, padding, corners) is not a token here: it carries over unchanged.
struct GlanceTokens: Sendable {
    /// The text roles the widget uses, named by job: `label` a row's title and a clock, `note` a sentence, `small` a quiet
    /// detail line, `smallLabel` the `+N` count and a stacked clock.
    enum TextRole: CaseIterable, Sendable {
        case label, note, small, smallLabel

        /// The design-system role of the redesign set (DS-R2): 12/500, 12/400, 11/400 and 12/500. DS-R2 has no 11/500 role,
        /// so `smallLabel` takes 12/500.
        var typeRole: TypeRole {
            switch self {
            case .label, .smallLabel: .quietMedium
            case .note: .quiet
            case .small: .axisCaption
            }
        }
    }

    let surface: LaunchMode.Surface
    /// The strip's, the pill's and the list's ground, and its edge.
    let ground: Color
    let edge: Color
    /// An entry, a row or the pill under the pointer.
    let hoverFill: Color
    /// The list's Limits group, a background step below the rows (LC-R6).
    let wellFill: Color
    /// The faint SpaceVibe mark with no live session (GW11).
    let markInk: Color
    /// The countdown ring's empty track.
    let ringTrack: Color
    /// The hovered row's destination icon.
    let hintInk: Color
    /// A drop slot while the widget is dragged, the slot a release picks, and their edges (GW13).
    let slotFill: Color
    let slotTargetFill: Color
    let slotTargetEdge: Color
    let slotEdge: Color
    /// The text inks: title, secondary, quiet.
    let primaryInk: Color
    let secondaryInk: Color
    let tertiaryInk: Color

    static let redesign = GlanceTokens(
        surface: .redesign,
        ground: ColorRole.groupSurface, edge: ColorRole.hairline,
        hoverFill: ColorRole.selectionFill, wellFill: ColorRole.hoverFill,
        markInk: ColorRole.ink, ringTrack: ColorRole.faint, hintInk: ColorRole.ink3,
        slotFill: ColorRole.selectionFill, slotTargetFill: ColorRole.controlHoverFill,
        slotTargetEdge: ColorRole.ink, slotEdge: ColorRole.ink3,
        primaryInk: ColorRole.ink, secondaryInk: ColorRole.ink2, tertiaryInk: ColorRole.ink3)

    /// The set for the window root the app draws: the redesign's only with its switch on.
    static func forSurface(_ surface: LaunchMode.Surface) -> GlanceTokens {
        switch surface {
        case .v5: .v5
        case .redesign: .redesign
        }
    }
}

private struct GlanceTokensKey: EnvironmentKey {
    static let defaultValue = GlanceTokens.v5
}

// Written out: the `@Entry` macro needs SwiftUI's macro plugin, which the Command Line Tools do not ship.
extension EnvironmentValues {
    /// The widget's tokens; a view outside the widget's roots reads the shipped set.
    var glanceTokens: GlanceTokens {
        get { self[GlanceTokensKey.self] }
        set { self[GlanceTokensKey.self] = newValue }
    }
}
