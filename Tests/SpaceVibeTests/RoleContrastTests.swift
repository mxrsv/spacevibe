import Testing
@testable import SpaceVibe

/// RD-R7, RD-R12, RD-R16 and DS-R1: every text and mark pair of the design-system tokens on the grounds the reference mock
/// draws it on, in all four variants (dark, light, and each with Increase Contrast): text 4.5:1, marks (state glyphs and
/// fills, category and session icons, logos, the checkbox, the focus bar) 3:1. Increase Contrast must bring tracks,
/// hairlines and data steps to 3:1 on the group surface.
///
/// Every pair passes: the 2026-11-21 gaps were closed by the owner's pick of the least value change ("Nhận hết"). A miss is
/// fixed in `ColorRoleValues` with the owner's yes, never exempted here.
@Suite("Contrast: design-system roles on their grounds")
struct RoleContrastTests {
    private typealias V = ColorRoleValues

    /// A ground: an opaque surface with translucent layers over it (a fill's own alpha, or `share` of an opaque role).
    struct Ground: Sendable {
        let name: String
        let base: ColorRoleValue
        var tops: [(ColorRoleValue, Double?)] = []

        func rgb(_ variant: ColorRoleVariant) -> RGB {
            let appearance: Appearance = variant.isDark ? .dark : .light
            let layers = [Layer(Self.fixed(base, variant))] + tops.map { Layer(Self.fixed($0.0, variant), alpha: $0.1) }
            return ColorMath.composite(layers, appearance)
        }

        /// One variant as a v5 `ColorValue`, so `ColorMath` composites it unchanged.
        static func fixed(_ value: ColorRoleValue, _ variant: ColorRoleVariant) -> ColorValue {
            let swatch = value.swatch(variant)
            return ColorValue(light: swatch.hex, dark: swatch.hex, lightAlpha: swatch.alpha, darkAlpha: swatch.alpha)
        }
    }

    struct Pair: Sendable, CustomTestStringConvertible {
        let ink: String
        let value: ColorRoleValue
        let ground: Ground
        let minimum: Double
        var variants: [ColorRoleVariant] = ColorRoleVariant.allCases
        var testDescription: String { "\(ink) on \(ground.name)" }
    }

    private static func ground(_ name: String, _ base: ColorRoleValue, _ tops: (ColorRoleValue, Double?)...) -> Ground {
        Ground(name: name, base: base, tops: tops)
    }

    // Grounds, named as the mock draws them.
    static let canvas = ground("canvas", V.canvasSurface)
    static let group = ground("group", V.groupSurface)
    static let side = ground("side (Solid sidebar)", V.sidebarSurface)
    static let zebraRow = ground("zebra row", V.groupSurface, (V.zebraFill, nil))
    static let hoveredRow = ground("hovered row", V.groupSurface, (V.hoverFill, nil))
    static let selectedRow = ground("selected row", V.groupSurface, (V.selectionFill, nil))
    static let hoveredSidebarItem = ground("hovered sidebar item", V.sidebarSurface, (V.hoverFill, nil))
    static let selectedSidebarItem = ground("selected sidebar item", V.sidebarSurface, (V.selectionFill, nil))
    static let toolbarControl = ground("toolbar control (Solid, on canvas)", V.canvasSurface, (V.controlFill, nil))
    static let toolbarControlHovered = ground("hovered toolbar control", V.canvasSurface, (V.controlHoverFill, nil))
    static let toolbarControlPressed = ground("pressed toolbar control", V.canvasSurface, (V.controlPressedFill, nil))
    static let rowButton = ground("small button in a row", V.groupSurface, (V.controlFill, nil))
    static let rowButtonHovered = ground("hovered small button", V.groupSurface, (V.controlHoverFill, nil))
    static let rowButtonPressed = ground("pressed small button", V.groupSurface, (V.controlPressedFill, nil))
    static let selectedSegment = ground("selected segment", V.canvasSurface, (V.controlFill, nil), (V.selectionFill, nil))
    static let hoveredSegment = ground("hovered segment (toolbar)", V.canvasSurface, (V.controlFill, nil), (V.hoverFill, nil))
    static let hoveredSmallSegment = ground("hovered small segment (age, dial)", V.groupSurface, (V.controlFill, nil), (V.hoverFill, nil))
    static let chosenSmallSegment = ground("chosen small segment", V.groupSurface, (V.controlFill, nil), (V.chosenSegmentFill, nil))
    static let chosenToolbarSegment = ground("chosen toolbar segment", V.canvasSurface, (V.controlFill, nil), (V.chosenSegmentFill, nil))
    static let destructiveOnGroup = ground("destructive tint on group", V.groupSurface, (V.stateCritical, V.destructiveTintShare))
    static let destructiveHovered = ground("hovered destructive tint on group", V.groupSurface,
                                           (V.stateCritical, V.destructiveTintHoverShare))
    static let destructiveOnCanvas = ground("destructive tint on canvas", V.canvasSurface, (V.stateCritical, V.destructiveTintShare))

    static let surfaces = [canvas, group, side]
    static let rowGrounds = [canvas, group, side, zebraRow, hoveredRow, selectedRow]
    static let markGrounds = [canvas, group, hoveredRow, selectedRow]

    private static func text(_ ink: String, _ value: ColorRoleValue, on grounds: [Ground]) -> [Pair] {
        grounds.map { Pair(ink: ink, value: value, ground: $0, minimum: 4.5) }
    }

    private static func marks(_ ink: String, _ value: ColorRoleValue, on grounds: [Ground]) -> [Pair] {
        grounds.map { Pair(ink: ink, value: value, ground: $0, minimum: 3) }
    }

    private static let increasedOnly: [ColorRoleVariant] = [.darkIncreased, .lightIncreased]

    static var pairs: [Pair] {
        var all: [Pair] = []
        // Text on every surface and row state.
        all += text("ink", V.ink, on: rowGrounds) + text("ink2", V.ink2, on: rowGrounds) + text("ink3", V.ink3, on: rowGrounds)
        // Sidebar items: label ink2 and value ink3 at rest and hovered; ink and ink2 when selected.
        all += text("ink2", V.ink2, on: [hoveredSidebarItem]) + text("ink3", V.ink3, on: [hoveredSidebarItem])
            + text("ink", V.ink, on: [selectedSidebarItem]) + text("ink2", V.ink2, on: [selectedSidebarItem])
        // State text sits on surfaces (a Hooks node's count); in rows a state is a glyph and the text is ink2 (the mock's `.st`).
        all += text("stateOk", V.stateOk, on: surfaces) + text("stateAttention", V.stateAttention, on: surfaces)
            + text("stateCritical", V.stateCritical, on: surfaces)
        all += text("link", V.link, on: [canvas, group])
        all += text("criticalInk", V.criticalInk, on: [destructiveOnGroup, destructiveHovered, destructiveOnCanvas])
        // The primary button's label at rest, hovered and pressed.
        all += text("onPrimaryAction", V.onPrimaryAction, on: [
            ground("primary", V.primaryAction), ground("primary hovered", V.primaryActionHover),
            ground("primary pressed", V.primaryActionPressed),
        ])
        // Controls: labels, secondary labels and the search placeholder, segments.
        let controls = [toolbarControl, toolbarControlHovered, toolbarControlPressed, rowButton, rowButtonHovered, rowButtonPressed]
        all += text("ink", V.ink, on: controls + [selectedSegment, chosenSmallSegment, chosenToolbarSegment])
        // RB-F3: every label the blocks draw on a control fill. `controlSecondaryInk`: an unchosen segment (toolbar and small
        // segmented, the permission dial), a chip's word, the count in a chosen segment. `controlQuietInk`: the search
        // placeholder and its ⌘F hint, the count in an unchosen segment.
        all += text("controlSecondaryInk", V.controlSecondaryInk, on: controls + [hoveredSegment, hoveredSmallSegment, selectedSegment,
                                                                                   chosenSmallSegment])
            + text("controlQuietInk", V.controlQuietInk, on: [toolbarControl, toolbarControlHovered, rowButton, hoveredSegment,
                                                              hoveredSmallSegment])
        // Marks on a control fill (3:1): the menu caret, the search glass, a chip's default glyph.
        all += marks("controlQuietInk", V.controlQuietInk, on: [toolbarControl, toolbarControlHovered, toolbarControlPressed, rowButton,
                                                                 rowButtonHovered])
        // Tile heat (RD-R12), and the CLI logos on it (RD48).
        all += tileText() + tileLogos()
        // Marks.
        all += marks("stateOk", V.stateOk, on: markGrounds) + marks("stateAttention", V.stateAttention, on: markGrounds)
            + marks("stateCritical", V.stateCritical, on: markGrounds)
        // A meter's fill on its group, and the sidebar Inbox dot on the sidebar item at rest, hovered and selected.
        let sidebarItem = [side, hoveredSidebarItem, selectedSidebarItem]
        all += marks("attentionBar", V.attentionBar, on: [group] + sidebarItem)
            + marks("criticalBar", V.criticalBar, on: [group] + sidebarItem) + marks("dataBar", V.dataBar, on: [group])
        let iconGrounds = [canvas, group, side, selectedRow, selectedSidebarItem]
        for (name, value) in [("toneSkills", V.toneSkills), ("toneSubagents", V.toneSubagents), ("toneHooks", V.toneHooks),
                              ("toneRules", V.toneRules), ("logoClaude", V.logoClaude), ("logoCodex", V.logoCodex)] {
            all += marks(name, value, on: iconGrounds)
        }
        for (name, value) in [("sessionWork", V.sessionWork), ("sessionWait", V.sessionWait), ("sessionDone", V.sessionDone)] {
            all += marks(name, value, on: markGrounds)
        }
        all += marks("primaryAction", V.primaryAction, on: [canvas, group])
        all += marks("onPrimaryAction", V.onPrimaryAction, on: [ground("checkbox on", V.primaryAction)])
        // The focus bar (RD29): ink on the row and field it sits in.
        all += marks("focus bar (ink)", V.ink, on: [group, hoveredRow, selectedRow, toolbarControl])
        // Increase Contrast: tracks, hairlines, data steps and control fills reach 3:1 on the group surface (DS-R1).
        for (name, value) in [("faint", V.faint), ("hairline", V.hairline), ("data1", V.data1), ("data2", V.data2),
                              ("data3", V.data3), ("data4", V.data4), ("dataBar", V.dataBar), ("controlFill", V.controlFill),
                              ("controlHoverFill", V.controlHoverFill), ("controlPressedFill", V.controlPressedFill),
                              ("controlEdge", V.controlEdge), ("offTileEdge", V.offTileEdge)] {
            all.append(Pair(ink: name, value: value, ground: group, minimum: 3, variants: increasedOnly))
        }
        return all
    }

    /// Tile heat (RD-R12): on each step its ink (a count, a name on steps 3 and 4) and its secondary ink (a name), and the zero
    /// count's ink on step 1.
    private static func tileText() -> [Pair] {
        let steps = [("data1", V.data1, V.dataInk1, V.dataSecondaryInk1), ("data2", V.data2, V.dataInk2, V.dataSecondaryInk2),
                     ("data3", V.data3, V.dataInk3, V.dataSecondaryInk3), ("data4", V.data4, V.dataInk4, V.dataSecondaryInk4)]
        var pairs: [Pair] = []
        for (name, fill, ink, secondary) in steps {
            let tile = ground("tile on \(name)", fill)
            pairs += text("dataInk", ink, on: [tile]) + text("dataSecondaryInk", secondary, on: [tile])
        }
        return pairs + text("dataZeroInk", V.dataZeroInk, on: [ground("tile on data1", V.data1)])
    }

    /// RD48: each CLI logo on each heat step, over the disc the tile draws there (the group surface on the two hottest steps
    /// and on every step under Increase Contrast, clear elsewhere), reads 3:1 in every variant.
    private static func tileLogos() -> [Pair] {
        let steps = [("data1", V.data1, V.tileLogoDisc1), ("data2", V.data2, V.tileLogoDisc2), ("data3", V.data3, V.tileLogoDisc3),
                     ("data4", V.data4, V.tileLogoDisc4)]
        var pairs: [Pair] = []
        for (name, fill, disc) in steps {
            let ground = ground("logo on \(name), over its disc", fill, (disc, nil))
            pairs += marks("logoClaude", V.logoClaude, on: [ground]) + marks("logoCodex", V.logoCodex, on: [ground])
        }
        return pairs
    }

    @Test("RD48: the logo disc is clear on the cool steps and the group surface where a logo would miss 3:1")
    func logoDiscs() {
        for variant in [ColorRoleVariant.dark, .light] {
            #expect(V.tileLogoDisc1.swatch(variant).alpha == 0 && V.tileLogoDisc2.swatch(variant).alpha == 0, "\(variant)")
            #expect(V.tileLogoDisc3.swatch(variant) == V.groupSurface.swatch(variant), "\(variant)")
            #expect(V.tileLogoDisc4.swatch(variant) == V.groupSurface.swatch(variant), "\(variant)")
        }
        for variant in Self.increasedOnly {
            for disc in [V.tileLogoDisc1, V.tileLogoDisc2, V.tileLogoDisc3, V.tileLogoDisc4] {
                #expect(disc.swatch(variant) == V.groupSurface.swatch(variant), "\(variant)")
            }
        }
        // Without the disc the hot steps miss 3:1 (the mock draws the logo bare): the disc is needed, not decoration.
        let bare = ColorMath.contrast(Ground(name: "", base: V.data4, tops: [(V.logoClaude, nil)]).rgb(.dark), Ground(name: "", base: V.data4).rgb(.dark))
        #expect(bare < 3)
    }

    @Test("each pair reads at its minimum in every variant", arguments: pairs)
    func pairReads(_ pair: Pair) {
        for variant in pair.variants {
            let ink = Ground(name: pair.ink, base: pair.ground.base, tops: pair.ground.tops + [(pair.value, nil)]).rgb(variant)
            let ratio = ColorMath.contrast(ink, pair.ground.rgb(variant))
            #expect(ratio >= pair.minimum,
                    "\(variant): \(pair.testDescription) reads \(String(format: "%.2f", ratio)):1, needs \(pair.minimum):1")
        }
    }

    @Test("under Increase Contrast the pressed control fill differs from rest and hover and is darker than hover")
    func pressedFillIsDistinct() {
        for variant in Self.increasedOnly {
            let rest = Self.rowButton.rgb(variant), hover = Self.rowButtonHovered.rgb(variant), pressed = Self.rowButtonPressed.rgb(variant)
            #expect(pressed != rest && pressed != hover, "\(variant)")
            #expect(ColorMath.luminance(pressed) < ColorMath.luminance(hover), "\(variant): pressed must be darker than hover")
            #expect(ColorMath.contrast(pressed, rest) > 1.03 && ColorMath.contrast(pressed, hover) > 1.03, "\(variant)")
        }
    }

    @Test("the IC data steps and faint span the measured range on group (DS-R1 acceptance: dark 3.55 to 13.79, light 3.21 to 15.17)")
    func increasedContrastRange() {
        let steps = [V.faint, V.data1, V.data2, V.data3, V.data4, V.dataBar]
        for (variant, low, high) in [(ColorRoleVariant.darkIncreased, 3.55, 13.79), (.lightIncreased, 3.21, 15.17)] {
            let ratios = steps.map { ColorMath.contrast(RGB(hex: $0.swatch(variant).hex), RGB(hex: V.groupSurface.swatch(variant).hex)) }
            #expect(abs(ratios.min()! - low) < 0.01 && abs(ratios.max()! - high) < 0.01, "\(variant): \(ratios)")
        }
    }

    @Test("white on the primary reads 4.76:1 (RD-R9)")
    func primaryLabel() {
        let ratio = ColorMath.contrast(RGB(hex: 0xFFFFFF), RGB(hex: V.primaryAction.dark.hex))
        #expect(abs(ratio - 4.76) < 0.01)
    }
}
