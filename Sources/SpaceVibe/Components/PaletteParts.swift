import SwiftUI

/// The dimmed layer behind an overlay (the palette, a confirmation). A click on it runs `onTap`.
struct Scrim: View {
    let onTap: () -> Void

    var body: some View {
        Palette.overlay
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityHidden(true)
    }
}

// MARK: - Palette (V5-R37)

/// The v5 palette's card: 560 wide, at most 480 high, `bgPop` with a `hair2` edge, radius 8, the top-edge highlight and the
/// dialog shadow. The shell centres it 112 below the window's top on the scrim.
struct PalettePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(width: Metrics.CommandPalette.width)
            .frame(maxHeight: Metrics.CommandPalette.maxHeight, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .blockSurface(Palette.bgPop, edge: Palette.hair2)
            .overlayShadow(.dialog)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Command palette")
            .accessibilityAddTraits(.isModal)
    }
}

/// The palette's search line: 48 high, the search glyph (16, `fg3`) 12 before the field (14/20), padding 0 16, a `hair`
/// line under it. The shell passes the text field.
struct PaletteSearchLine<Field: View>: View {
    @ViewBuilder var field: Field

    var body: some View {
        HStack(spacing: Metrics.CommandPalette.fieldSpacing) {
            SpaceVibeIcon(content: .search, ink: Palette.fg3)
            field.spaceVibeText(.field, tone: .primary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Metrics.CommandPalette.fieldPadding)
        .frame(height: Metrics.CommandPalette.fieldHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hair).frame(height: Metrics.Radius.edge).accessibilityHidden(true) }
    }
}

/// A group title in the v5 palette list: 11/16 500 `fg3`, padding 8 12 4.
struct PaletteGroupTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .spaceVibeText(.smallLabel, tone: .tertiary)
            .padding(Metrics.CommandPalette.headingInsets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One command in the v5 palette: 32 high, radius 6, padding 0 12, the glyph (16, `fg3`) 12 before the title (13), the
/// key cap at the right; the selected one on `sel`. Only real commands are listed (V5-R37).
struct PaletteCommandRow: View {
    let title: String
    var glyph: (any GlyphSource)?
    var keyCap: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.control, style: Metrics.Radius.cornerStyle)
        Button(action: action) {
            HStack(spacing: Metrics.CommandPalette.rowSpacing) {
                if let glyph { SpaceVibeIcon(source: glyph, ink: Palette.fg3) }
                Text(title).spaceVibeText(.prose, tone: .primary).lineLimit(1)
                Spacer(minLength: 0)
                if let keyCap { KeyCap(keyCap) }
            }
            .padding(.horizontal, Metrics.CommandPalette.rowPadding)
            .frame(height: Metrics.CommandPalette.rowHeight)
            .background(shape.fill(isSelected ? Palette.sel : .clear))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .focusable(false)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Where the v5 palette stands: its card on the scrim, 112 below the window's top. A click on the scrim runs `onDismiss`.
struct PaletteStage<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            Scrim(onTap: onDismiss)
            content.padding(.top, Metrics.CommandPalette.topInset)
        }
    }
}

extension View {
    /// The scrolling list of the v5 palette takes what the card has left, at most (480 less the field and the footer).
    func paletteListHeight() -> some View {
        frame(maxHeight: Metrics.CommandPalette.listMaxHeight)
    }
}

/// The v5 palette's list: 4 inside the card's edge.
struct PaletteCommandList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }.padding(Metrics.CommandPalette.listPadding)
    }
}

/// "No command found" in the v5 palette: centred 13 pt `fg3`, 48 above and below.
struct PaletteNoMatch: View {
    var text = "No command found"

    var body: some View {
        Text(text)
            .spaceVibeText(.prose, tone: .tertiary)
            .padding(Metrics.CommandPalette.emptyInsets)
            .frame(maxWidth: .infinity)
    }
}

/// The v5 palette's footer: 32 high with a `hair` line above, padding 0 12, hints 16 apart, each its caps 6 before its word
/// (11 pt `fg3`). Keys are split at spaces into one cap each.
struct PaletteKeysFooter: View {
    let hints: [KeyHint]

    var body: some View {
        HStack(spacing: Metrics.CommandPalette.footerSpacing) {
            ForEach(hints, id: \.self) { hint in
                HStack(spacing: Metrics.KeyCap.spacing) {
                    ForEach(Array(hint.keys.split(separator: " ").enumerated()), id: \.offset) { _, key in KeyCap(String(key)) }
                    Text(hint.label)
                }
            }
            Spacer(minLength: 0)
        }
        .spaceVibeText(.small, tone: .tertiary)
        .padding(.horizontal, Metrics.CommandPalette.footerPadding)
        .frame(height: Metrics.CommandPalette.footerHeight)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hair).frame(height: Metrics.Radius.edge).accessibilityHidden(true) }
        .accessibilityHidden(true)
    }
}
