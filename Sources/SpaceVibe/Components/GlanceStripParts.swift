import SwiftUI

/// The collapsed glance widget's ground (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW14, GW20): a capsule on
/// the set's ground (`bgPop` in v5) with its edge (`hair2`), holding its parts in a row or, on a left or right edge middle,
/// in a column. The window around it draws the drop shadow, so the capsule adds none and the window stays exactly its size.
/// `isStale` fades the parts (not the ground) while they show the last read of a feed that has failed.
struct GlanceCapsule<Content: View>: View {
    let axis: GlanceAxis
    var isStale = false
    @ViewBuilder var content: Content

    @Environment(\.glanceTokens) private var tokens

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: Metrics.Glance.entrySpacing))
            : AnyLayout(VStackLayout(spacing: Metrics.Glance.entrySpacing))
        layout { content }
            .opacity(isStale ? Metrics.Glance.staleOpacity : 1)
            .padding(Metrics.Glance.stripPadding)
            .blockSurface(tokens.ground, edge: tokens.edge, radius: Metrics.Glance.stripRadius)
            .fixedSize()
    }
}

/// One live session in the strip (GW3, GW20 form A): the state glyph, then the CLI logo, in a capsule that fills on hover.
/// The whole capsule takes the click.
struct GlanceEntryButton: View {
    let state: GlanceState
    let cli: CoreCLI
    let axis: GlanceAxis
    /// False while the widget is not on screen: the working ring stops.
    var isAnimating = true
    /// What VoiceOver reads: the CLI, the title and the state.
    let accessibilityName: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.glanceTokens) private var tokens
    @State private var hovering = false

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: Metrics.Glance.entryInnerSpacing))
            : AnyLayout(VStackLayout(spacing: Metrics.Glance.entryInnerSpacing))
        Button(action: action) {
            layout {
                SessionStateGlyph(state: state, isAnimating: isAnimating)
                // `CLIMark` is the only file that may draw an image (`IconPolicyTests`); its smallest bare size is 14, the mock's 12.
                CLIMark(cli, size: .glyph)
            }
            .padding(axis == .horizontal ? .horizontal : .vertical, Metrics.Glance.entryPadding)
            .frame(minWidth: Metrics.Glance.entrySide, minHeight: Metrics.Glance.entrySide)
            .background(Capsule().fill(hovering ? tokens.hoverFill : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: Metrics.Motion.quick), value: hovering)
        .accessibilityLabel(accessibilityName)
    }
}

/// `+N` after the sixth entry (GW12): quiet, tabular, never a control (hovering the strip already lists every session). Its
/// padding runs along the strip, so a column keeps the entries' width.
struct GlanceOverflowCount: View {
    let text: String
    let axis: GlanceAxis
    let accessibilityName: String

    @Environment(\.glanceTokens) private var tokens

    var body: some View {
        Text(text)
            .glanceText(.smallLabel, tone: .secondary, tokens: tokens)
            .glanceLineBox(.smallLabel, tokens: tokens)
            .padding(axis == .horizontal ? .horizontal : .vertical, Metrics.Glance.overflowPadding)
            .frame(minWidth: Metrics.Glance.entrySide, minHeight: Metrics.Glance.entrySide)
            .accessibilityLabel(accessibilityName)
    }
}

/// The strip with no live session (GW11, GW-R4): the glyph of the SpaceVibe mark (`Resources/AppIcon.svg`) without its dark
/// square, in the text ink and faint, as the mock draws it. The parts are flattened before the fade, so where the bars
/// cross the ring the glyph is not darker.
struct GlanceEmptyMark: View {
    let accessibilityName: String

    @Environment(\.glanceTokens) private var tokens

    var body: some View {
        ZStack {
            ForEach(MarkPart.allCases, id: \.self) { part in
                MarkShape(part: part, scale: MarkShape.glyphScale).fill(tokens.markInk)
            }
        }
        .frame(width: Metrics.Glance.markSize, height: Metrics.Glance.markSize)
        .compositingGroup()
        .opacity(Metrics.Glance.markOpacity)
        .padding(Metrics.Glance.markPadding)
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
    }
}

// MARK: - The shipped token set and the text seam (RD34)

extension GlanceTokens {
    /// What the widget drew before the redesign's seam, value for value: the shipped app keeps this look (FE-P9).
    static let v5 = GlanceTokens(
        surface: .v5,
        ground: Palette.bgPop, edge: Palette.hair2,
        hoverFill: Palette.sel, wellFill: Palette.hover,
        markInk: Palette.fg, ringTrack: Palette.fg4, hintInk: Palette.fg3,
        slotFill: Palette.sel, slotTargetFill: Palette.trackHi,
        slotTargetEdge: Palette.fg, slotEdge: Palette.fg.opacity(Metrics.Glance.slotEdgeOpacity),
        primaryInk: TextTone.primary.color, secondaryInk: TextTone.secondary.color, tertiaryInk: TextTone.tertiary.color)
}

extension GlanceTokens.TextRole {
    /// The v5 role each one stands for.
    var v5: SpaceVibeType {
        switch self {
        case .label: .metaLabel
        case .note: .meta
        case .small: .small
        case .smallLabel: .smallLabel
        }
    }
}

extension GlanceTokens {
    /// A text tone's ink in this set. The state tones (a counting window's `warn` and `danger` clock, LC9) keep their own
    /// colour in both sets (GW22); only the neutral inks change.
    func ink(_ tone: TextTone) -> Color {
        switch tone {
        case .primary: primaryInk
        case .secondary: secondaryInk
        case .tertiary: tertiaryInk
        default: tone.color
        }
    }
}

extension Text {
    /// The widget's text: in `.v5` exactly `spaceVibeText(role.v5, tone:)`, as before the seam; in `.redesign` the
    /// design-system role and the set's ink.
    func glanceText(_ role: GlanceTokens.TextRole, tone: TextTone, tokens: GlanceTokens) -> Text {
        switch tokens.surface {
        case .v5: spaceVibeText(role.v5, tone: tone)
        case .redesign: typeRole(role.typeRole).foregroundStyle(tokens.ink(tone))
        }
    }
}

extension View {
    /// The role's whole line box: `lineBox(role.v5)` in `.v5`, the design-system role's half leading in `.redesign`.
    @ViewBuilder
    func glanceLineBox(_ role: GlanceTokens.TextRole, tokens: GlanceTokens) -> some View {
        switch tokens.surface {
        case .v5: lineBox(role.v5)
        case .redesign: padding(.vertical, role.typeRole.halfLeading)
        }
    }
}
