import Testing
@testable import SpaceVibe

/// RD-R7, RD-R12, RD-R16 and DS-R1: every text and mark pair of the design-system tokens on the grounds the reference mock
/// draws it on, in all four variants (dark, light, and each with Increase Contrast): text 4.5:1, marks (state glyphs and
/// fills, category and session icons, logos, the checkbox, the focus bar) 3:1. Increase Contrast must bring tracks,
/// hairlines and data steps to 3:1 on the group surface.
///
/// A pair the values do not meet today is listed with `knownGap` and its reason: the test records it as a known issue, so the
/// suite stays green while the gap stays visible, and the day the values change it fails until the entry goes. A gap is a
/// decision for the owner (the values are owner-decided), never fixed here by editing a token.
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
        /// Variants that miss today, and why.
        var knownGap: (variants: Set<ColorRoleVariant>, reason: String)?
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
    static let selectedSegment = ground("selected segment", V.canvasSurface, (V.controlFill, nil), (V.selectionFill, nil))
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

    private static let lightOnly: Set<ColorRoleVariant> = [.light, .lightIncreased]
    private static let increasedOnly: [ColorRoleVariant] = [.darkIncreased, .lightIncreased]

    static var pairs: [Pair] {
        var all: [Pair] = []
        // Text on every surface and row state.
        all += text("ink", V.ink, on: rowGrounds) + text("ink2", V.ink2, on: rowGrounds) + text("ink3", V.ink3, on: rowGrounds)
        // Sidebar items: label ink2 and value ink3 at rest and hovered; ink and ink2 when selected.
        all += text("ink2", V.ink2, on: [hoveredSidebarItem]) + text("ink", V.ink, on: [selectedSidebarItem])
            + text("ink2", V.ink2, on: [selectedSidebarItem])
        all.append(Pair(ink: "ink3", value: V.ink3, ground: hoveredSidebarItem, minimum: 4.5,
                        knownGap: ([.light], "a hovered Solid sidebar item's value (`.nv:hover .tv`) reads 4.18:1 in light")))
        // State text, links, text on the destructive tint.
        // State text sits on surfaces (a Hooks node's count); in rows a state is a glyph and the text is ink2 (the mock's `.st`).
        all += text("stateOk", V.stateOk, on: surfaces) + text("stateAttention", V.stateAttention, on: surfaces)
            + text("stateCritical", V.stateCritical, on: surfaces)
        all += text("link", V.link, on: [canvas, group])
        all += text("criticalInk", V.criticalInk, on: [destructiveOnGroup, destructiveHovered, destructiveOnCanvas])
        // The primary button's label.
        all += text("onPrimaryAction", V.onPrimaryAction, on: [ground("primary", V.primaryAction), ground("primary pressed", V.primaryActionPressed)])
        all.append(Pair(ink: "onPrimaryAction", value: V.onPrimaryAction, ground: ground("primary hovered", V.primaryActionHover),
                        minimum: 4.5, knownGap: (Set(ColorRoleVariant.allCases),
                                                 "white on the hover step (14% white, RD-R9) reads 3.80:1")))
        // Controls: labels, the search placeholder, segments.
        all += text("ink", V.ink, on: [toolbarControl, toolbarControlHovered, toolbarControlPressed, rowButton, selectedSegment])
        all += text("ink2", V.ink2, on: [toolbarControl, rowButton]) + text("ink3", V.ink3, on: [toolbarControl])
        // Tile heat (RD-R12): name ink2 on the two lightest steps, ink on all, a zero count ink3 on the lightest.
        all += tileText()
        // Marks.
        all += marks("stateOk", V.stateOk, on: markGrounds) + marks("stateAttention", V.stateAttention, on: markGrounds)
            + marks("stateCritical", V.stateCritical, on: markGrounds)
        all += marks("attentionBar", V.attentionBar, on: [group]) + marks("criticalBar", V.criticalBar, on: [group, side])
            + marks("dataBar", V.dataBar, on: [group])
        all.append(Pair(ink: "attentionBar", value: V.attentionBar, ground: side, minimum: 3,
                        knownGap: (lightOnly, "the sidebar Inbox dot (`.nv .dot`) on the Solid sidebar reads 2.97:1 in light")))
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
        // Increase Contrast: tracks, hairlines and data steps reach 3:1 on the group surface (DS-R1).
        for (name, value) in [("faint", V.faint), ("hairline", V.hairline), ("data1", V.data1), ("data2", V.data2),
                              ("data3", V.data3), ("data4", V.data4), ("dataBar", V.dataBar)] {
            all.append(Pair(ink: name, value: value, ground: group, minimum: 3, variants: increasedOnly))
        }
        all.append(Pair(ink: "controlFill (IC)", value: V.controlFill, ground: group, minimum: 3, variants: increasedOnly,
                        knownGap: (Set(increasedOnly), "DS-R1 says control fills reach 3:1 under IC; the fill reads 1.90:1 (dark) and "
                            + "1.41:1 (light) on group, only its hairline edge reaches 3:1")))
        return all
    }

    private static func tileText() -> [Pair] {
        let steps = [("data1", V.data1), ("data2", V.data2), ("data3", V.data3), ("data4", V.data4)]
        var pairs: [Pair] = []
        let gap = "under IC the tile steps rise to 3:1 against group, so tile text in ink no longer reads 4.5:1 (RD-R12 vs DS-R1)"
        for (index, (name, value)) in steps.enumerated() {
            let tile = ground("tile on \(name)", value)
            // ink still reads 4.5:1 on the lightest IC step; from the second step on it does not.
            pairs.append(Pair(ink: "ink", value: V.ink, ground: tile, minimum: 4.5, knownGap: index == 0 ? nil : (Set(increasedOnly), gap)))
            if index < 2 {
                pairs.append(Pair(ink: "ink2", value: V.ink2, ground: tile, minimum: 4.5, knownGap: (Set(increasedOnly), gap)))
            }
        }
        pairs.append(Pair(ink: "ink3", value: V.ink3, ground: ground("tile on data1", V.data1), minimum: 4.5,
                          knownGap: (Set(increasedOnly), gap)))
        return pairs
    }

    @Test("each pair reads at its minimum in every variant", arguments: pairs)
    func pairReads(_ pair: Pair) {
        for variant in pair.variants {
            let ink = Ground(name: pair.ink, base: pair.ground.base, tops: pair.ground.tops + [(pair.value, nil)]).rgb(variant)
            let ratio = ColorMath.contrast(ink, pair.ground.rgb(variant))
            let check = {
                #expect(ratio >= pair.minimum,
                        "\(variant): \(pair.testDescription) reads \(String(format: "%.2f", ratio)):1, needs \(pair.minimum):1")
            }
            if let gap = pair.knownGap, gap.variants.contains(variant) {
                withKnownIssue("\(variant): \(gap.reason)") { check() }
            } else {
                check()
            }
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
