import AppKit
import SwiftUI

/// Which of a colour role's four values is showing: the theme, and whether macOS Increase Contrast is on.
enum ColorRoleVariant: CaseIterable, Sendable {
    case dark, light, darkIncreased, lightIncreased

    var isDark: Bool { self == .dark || self == .darkIncreased }
    var isIncreased: Bool { self == .darkIncreased || self == .lightIncreased }

    init(dark: Bool, increased: Bool) {
        switch (dark, increased) {
        case (true, false): self = .dark
        case (false, false): self = .light
        case (true, true): self = .darkIncreased
        case (false, true): self = .lightIncreased
        }
    }

    /// The four appearance names AppKit resolves a dynamic colour against. With Increase Contrast on, macOS hands views the
    /// high-contrast twin of the theme.
    static let appearanceNames: [NSAppearance.Name] = [
        .darkAqua, .aqua, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastAqua,
    ]

    /// The variant for the appearance a view is drawn in. `systemIncreasesContrast` also counts, because the shell fixes the
    /// theme by setting `NSApp.appearance` to plain `darkAqua` or `aqua` (`AppearanceStore`); reading the setting itself keeps
    /// Increase Contrast working under a fixed theme as well as under System.
    init(appearanceName: NSAppearance.Name?, systemIncreasesContrast: Bool) {
        let dark = appearanceName == .darkAqua || appearanceName == .accessibilityHighContrastDarkAqua
        let highContrastName = appearanceName == .accessibilityHighContrastDarkAqua || appearanceName == .accessibilityHighContrastAqua
        self.init(dark: dark, increased: highContrastName || systemIncreasesContrast)
    }
}

/// One colour role's value in each variant: sRGB `0xRRGGBB` and an alpha. `ColorRole` builds every colour from one of
/// these, and `RoleContrastTests` reads the same values, so a test checks the token and not a copy.
struct ColorRoleValue: Sendable, Equatable {
    struct Swatch: Sendable, Equatable {
        let hex: UInt32
        var alpha: Double = 1
    }

    let dark: Swatch
    let light: Swatch
    let darkIncreased: Swatch
    let lightIncreased: Swatch

    init(dark: Swatch, light: Swatch, darkIncreased: Swatch? = nil, lightIncreased: Swatch? = nil) {
        self.dark = dark
        self.light = light
        self.darkIncreased = darkIncreased ?? dark
        self.lightIncreased = lightIncreased ?? light
    }

    /// An opaque role; `increased` gives its Increase Contrast values (dark, light), otherwise it keeps its own.
    init(dark: UInt32, light: UInt32, increased: (dark: UInt32, light: UInt32)? = nil) {
        self.init(dark: Swatch(hex: dark), light: Swatch(hex: light),
                  darkIncreased: increased.map { Swatch(hex: $0.dark) }, lightIncreased: increased.map { Swatch(hex: $0.light) })
    }

    /// A translucent fill: white at `dark / 255` in dark, black at `light / 255` in light (the mock writes these as
    /// `#ffffff14`, `#00000017`). `increased` gives the Increase Contrast alphas the same way.
    static func translucent(dark: UInt8, light: UInt8, increased: (dark: UInt8, light: UInt8)? = nil) -> ColorRoleValue {
        func white(_ byte: UInt8) -> Swatch { Swatch(hex: 0xFFFFFF, alpha: Double(byte) / 255) }
        func black(_ byte: UInt8) -> Swatch { Swatch(hex: 0x000000, alpha: Double(byte) / 255) }
        return ColorRoleValue(dark: white(dark), light: black(light),
                              darkIncreased: increased.map { white($0.dark) }, lightIncreased: increased.map { black($0.light) })
    }

    /// `top` mixed into `bottom` at `share` (dark, light), like CSS `color-mix(in srgb, top share, bottom)`, rounded to 8 bits.
    /// Both must be opaque. `increased` replaces the result under Increase Contrast.
    static func mix(_ top: ColorRoleValue, share: (dark: Double, light: Double), into bottom: ColorRoleValue,
                    increased: (dark: UInt32, light: UInt32)? = nil) -> ColorRoleValue {
        ColorRoleValue(dark: mixHex(top.dark.hex, share.dark, bottom.dark.hex),
                       light: mixHex(top.light.hex, share.light, bottom.light.hex), increased: increased)
    }

    /// The same mix in every variant (the primary's hover and pressed steps).
    static func mix(_ top: UInt32, share: Double, into bottom: UInt32) -> ColorRoleValue {
        let hex = mixHex(top, share, bottom)
        return ColorRoleValue(dark: hex, light: hex)
    }

    static func mixHex(_ top: UInt32, _ share: Double, _ bottom: UInt32) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let t = Double((top >> shift) & 0xFF), b = Double((bottom >> shift) & 0xFF)
            return UInt32((t * share + b * (1 - share)).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    func swatch(_ variant: ColorRoleVariant) -> Swatch {
        switch variant {
        case .dark: dark
        case .light: light
        case .darkIncreased: darkIncreased
        case .lightIncreased: lightIncreased
        }
    }

    /// True when Increase Contrast changes this role in either theme.
    var changesWithIncreasedContrast: Bool { darkIncreased != dark || lightIncreased != light }

    /// The colour views use: it follows the appearance the view is drawn in, Increase Contrast included.
    var color: Color {
        let value = self
        return Color(nsColor: NSColor(name: nil) { appearance in
            let name = appearance.bestMatch(from: ColorRoleVariant.appearanceNames)
            let variant = ColorRoleVariant(appearanceName: name,
                                           systemIncreasesContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
            return value.swatch(variant).nsColor
        })
    }

    /// One variant, whatever the appearance: for the specimen, which shows every variant side by side.
    func color(_ variant: ColorRoleVariant) -> Color { Color(nsColor: swatch(variant).nsColor) }
}

extension ColorRoleValue.Swatch {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// The values behind `ColorRole`, one per role of the design-system spec (DS-R1,
/// `docs/specs/2026-11-21-spacevibe-design-system.md`), read from the reference mock's `src/style.css`.
///
/// Names (AR6): a role keeps its spec name unless that name is already a v5 token name with another value (`Palette`,
/// `TextTone`, `Rhythm`, `Metrics`); then it carries a longer name, and `specName` in `all` gives the spec's. So `ok` is
/// `stateOk`, `warn` `stateAttention`, `crit` `stateCritical`, `group` `groupSurface`, `side` `sidebarSurface`, `primary`
/// `primaryAction`, `hair` `hairline`, `hover` `hoverFill`, `sel` `selectionFill`, `scrim` `scrimFill`, and the category tones
/// (whose hues swap against v5's `catSkill`…`catRule`) are `toneSkills`…`toneRules`. `RoleTokenTests` checks the rule.
enum ColorRoleValues {
    // Surfaces (RD9: Graphite, no hue cast)
    /// The window.
    static let canvasSurface = ColorRoleValue(dark: 0x111214, light: 0xF4F4F5)
    /// Cards, the inspector, menus in Solid.
    static let groupSurface = ColorRoleValue(dark: 0x191A1D, light: 0xFFFFFF)
    /// The Solid sidebar.
    static let sidebarSurface = ColorRoleValue(dark: 0x141518, light: 0xE9E9EB)

    // Text
    static let ink = ColorRoleValue(dark: 0xF5F6F8, light: 0x14171D)
    static let ink2 = ColorRoleValue(dark: 0xD6D9DF, light: 0x434955)
    static let ink3 = ColorRoleValue(dark: 0xA9AEB8, light: 0x616775, increased: (0xBCC1CA, 0x4E5462))
    /// An empty track.
    static let faint = ColorRoleValue(dark: 0x3A404C, light: 0xC9CFDA, increased: (0x6B717D, 0x8A909C))

    // State only: text and glyphs, then the fills (meters, marks) that reach 3:1. `attentionBar` in light is the 3:1 amber
    // for small marks (RD-R16).
    static let stateOk = ColorRoleValue(dark: 0x4CC38A, light: 0x17784C)
    static let stateAttention = ColorRoleValue(dark: 0xE8B33A, light: 0x8A6200)
    static let stateCritical = ColorRoleValue(dark: 0xEF6B5E, light: 0xC42F1D)
    static let attentionBar = ColorRoleValue(dark: 0xE8B33A, light: 0xB07E00)
    static let criticalBar = ColorRoleValue(dark: 0xEF6B5E, light: 0xD9402F)
    /// Text on the destructive tint (`stateCritical` at `destructiveTintShare` over its ground).
    static let criticalInk = ColorRoleValue(dark: 0xFF8A7D, light: 0x9E1D0F)

    // The primary action (RD11, RD-R9): the one primary action of a surface, checkbox and switch on; flat, the same in both
    // themes.
    static let primaryAction = ColorRoleValue(dark: 0x0B6FE4, light: 0x0B6FE4)
    /// One step lighter: the primary with 14% white.
    static let primaryActionHover = ColorRoleValue.mix(0xFFFFFF, share: 0.14, into: 0x0B6FE4)
    /// One step darker: the primary with 16% black.
    static let primaryActionPressed = ColorRoleValue.mix(0x000000, share: 0.16, into: 0x0B6FE4)
    static let onPrimaryAction = ColorRoleValue(dark: 0xFFFFFF, light: 0xFFFFFF)
    static let link = ColorRoleValue(dark: 0x5AA2FF, light: 0x0A64D0)

    // The two CLI logos only
    static let logoClaude = ColorRoleValue(dark: 0xE08463, light: 0xAD4A28)
    static let logoCodex = ColorRoleValue(dark: 0xE9E9ED, light: 0x2A2B30)

    // One identity tone per category, icons only (RD12).
    static let toneSkills = ColorRoleValue(dark: 0xA38BF5, light: 0x6A4FD8)
    static let toneSubagents = ColorRoleValue(dark: 0x7BDEE0, light: 0x178082)
    static let toneHooks = ColorRoleValue(dark: 0xCF84E0, light: 0x9A3FB0)
    static let toneRules = ColorRoleValue(dark: 0x9AA3B5, light: 0x586273)

    // Session glyph inks (`SessionStateGlyph`, unchanged: the same values as v5's `sessionWorking`…`sessionDone`).
    static let sessionWork = ColorRoleValue(dark: 0xE1B236, light: 0x9C7802)
    static let sessionWait = ColorRoleValue(dark: 0xEB871B, light: 0xAF6005)
    static let sessionDone = ColorRoleValue(dark: 0x6FBE94, light: 0x27885D)

    // Data, never a state (RD-R8): `ink` mixed into `groupSurface`, dark 8/16/28/38/55%, light 8/16/28/44/55%. Increase
    // Contrast replaces each step with a grey that reaches 3:1 on `groupSurface`.
    static let data1 = ColorRoleValue.mix(ink, share: (0.08, 0.08), into: groupSurface, increased: (0x6B717D, 0x8A909C))
    static let data2 = ColorRoleValue.mix(ink, share: (0.16, 0.16), into: groupSurface, increased: (0x858B96, 0x6E7480))
    static let data3 = ColorRoleValue.mix(ink, share: (0.28, 0.28), into: groupSurface, increased: (0xA3A8B1, 0x545A66))
    static let data4 = ColorRoleValue.mix(ink, share: (0.38, 0.44), into: groupSurface, increased: (0xC4C8CE, 0x3B404B))
    static let dataBar = ColorRoleValue.mix(ink, share: (0.55, 0.55), into: groupSurface, increased: (0xE3E5E8, 0x22262E))

    // Lines and fills over a surface. Under Increase Contrast the hairline is `faint`'s opaque grey.
    static let hairline: ColorRoleValue = {
        let line = ColorRoleValue.translucent(dark: 0x14, light: 0x17)
        return ColorRoleValue(dark: line.dark, light: line.light, darkIncreased: faint.darkIncreased, lightIncreased: faint.lightIncreased)
    }()
    /// Zebra rows.
    static let zebraFill = ColorRoleValue.translucent(dark: 0x07, light: 0x06)
    static let hoverFill = ColorRoleValue.translucent(dark: 0x0F, light: 0x0D)
    /// The selected row, segment and sidebar item (neutral, never the primary).
    static let selectionFill = ColorRoleValue.translucent(dark: 0x17, light: 0x12)
    /// Control fills. Increase Contrast raises rest and hover and adds a `hairline` edge; neither the spec nor the mock gives
    /// a pressed value, so pressed keeps its own.
    static let controlFill = ColorRoleValue.translucent(dark: 0x17, light: 0x0D, increased: (0x33, 0x26))
    static let controlHoverFill = ColorRoleValue.translucent(dark: 0x26, light: 0x17, increased: (0x44, 0x33))
    static let controlPressedFill = ColorRoleValue.translucent(dark: 0x33, light: 0x22)
    /// Behind sheets and alerts.
    static let scrimFill = ColorRoleValue(dark: .init(hex: 0x000000, alpha: Double(0x80) / 255),
                                          light: .init(hex: 0x000000, alpha: Double(0x4D) / 255))
    /// The one `float` shadow of in-content popovers in Solid (DS-R8; `ShadowRole` holds its geometry).
    static let floatShadow = ColorRoleValue(dark: .init(hex: 0x000000, alpha: Double(0xAA) / 255),
                                            light: .init(hex: 0x000000, alpha: Double(0xAA) / 255))

    /// The share of `stateCritical` in the destructive tint at rest, hovered and pressed, and in its 1 pt edge (the mock's
    /// `.dst` and `.rb.d`).
    static let destructiveTintShare = 0.15
    static let destructiveTintHoverShare = 0.26
    static let destructiveTintPressedShare = 0.34
    static let destructiveTintEdgeShare = 0.38

    /// Every role: its name here, the spec's name, its value. In the spec's order; the specimen draws them, the tests walk them.
    static let all: [(name: String, specName: String, value: ColorRoleValue)] = [
        ("canvasSurface", "canvas", canvasSurface), ("groupSurface", "group", groupSurface),
        ("sidebarSurface", "side", sidebarSurface), ("ink", "ink", ink), ("ink2", "ink2", ink2), ("ink3", "ink3", ink3),
        ("faint", "faint", faint), ("stateOk", "ok", stateOk), ("stateAttention", "warn", stateAttention),
        ("stateCritical", "crit", stateCritical), ("attentionBar", "warn-bar", attentionBar),
        ("criticalBar", "crit-bar", criticalBar), ("criticalInk", "crit-ink", criticalInk),
        ("primaryAction", "primary", primaryAction), ("primaryActionHover", "primary-h", primaryActionHover),
        ("primaryActionPressed", "primary-p", primaryActionPressed), ("onPrimaryAction", "on-primary", onPrimaryAction),
        ("link", "link", link), ("logoClaude", "clay", logoClaude), ("logoCodex", "logo-codex", logoCodex),
        ("toneSkills", "c-skills", toneSkills), ("toneSubagents", "c-subs", toneSubagents),
        ("toneHooks", "c-hooks", toneHooks), ("toneRules", "c-rules", toneRules),
        ("sessionWork", "s-work", sessionWork), ("sessionWait", "s-wait", sessionWait), ("sessionDone", "s-done", sessionDone),
        ("data1", "data-1", data1), ("data2", "data-2", data2), ("data3", "data-3", data3), ("data4", "data-4", data4),
        ("dataBar", "data-bar", dataBar), ("hairline", "hair", hairline), ("zebraFill", "alt", zebraFill),
        ("hoverFill", "hover", hoverFill), ("selectionFill", "sel", selectionFill), ("controlFill", "ctl", controlFill),
        ("controlHoverFill", "ctl-h", controlHoverFill), ("controlPressedFill", "ctl-a", controlPressedFill),
        ("scrimFill", "scrim", scrimFill), ("floatShadow", "sh-float", floatShadow),
    ]
}

/// The colours new-frame views use (AR6: beside v5's `Palette`, never mixed with it). Each one follows the window's
/// appearance and Increase Contrast, so a view never branches on theme or contrast. Values live in `ColorRoleValues`.
enum ColorRole {
    static let canvasSurface = ColorRoleValues.canvasSurface.color
    static let groupSurface = ColorRoleValues.groupSurface.color
    static let sidebarSurface = ColorRoleValues.sidebarSurface.color
    static let ink = ColorRoleValues.ink.color
    static let ink2 = ColorRoleValues.ink2.color
    static let ink3 = ColorRoleValues.ink3.color
    static let faint = ColorRoleValues.faint.color
    static let stateOk = ColorRoleValues.stateOk.color
    static let stateAttention = ColorRoleValues.stateAttention.color
    static let stateCritical = ColorRoleValues.stateCritical.color
    static let attentionBar = ColorRoleValues.attentionBar.color
    static let criticalBar = ColorRoleValues.criticalBar.color
    static let criticalInk = ColorRoleValues.criticalInk.color
    static let primaryAction = ColorRoleValues.primaryAction.color
    static let primaryActionHover = ColorRoleValues.primaryActionHover.color
    static let primaryActionPressed = ColorRoleValues.primaryActionPressed.color
    static let onPrimaryAction = ColorRoleValues.onPrimaryAction.color
    static let link = ColorRoleValues.link.color
    static let logoClaude = ColorRoleValues.logoClaude.color
    static let logoCodex = ColorRoleValues.logoCodex.color
    static let toneSkills = ColorRoleValues.toneSkills.color
    static let toneSubagents = ColorRoleValues.toneSubagents.color
    static let toneHooks = ColorRoleValues.toneHooks.color
    static let toneRules = ColorRoleValues.toneRules.color
    static let sessionWork = ColorRoleValues.sessionWork.color
    static let sessionWait = ColorRoleValues.sessionWait.color
    static let sessionDone = ColorRoleValues.sessionDone.color
    static let data1 = ColorRoleValues.data1.color
    static let data2 = ColorRoleValues.data2.color
    static let data3 = ColorRoleValues.data3.color
    static let data4 = ColorRoleValues.data4.color
    static let dataBar = ColorRoleValues.dataBar.color
    static let hairline = ColorRoleValues.hairline.color
    static let zebraFill = ColorRoleValues.zebraFill.color
    static let hoverFill = ColorRoleValues.hoverFill.color
    static let selectionFill = ColorRoleValues.selectionFill.color
    static let controlFill = ColorRoleValues.controlFill.color
    static let controlHoverFill = ColorRoleValues.controlHoverFill.color
    static let controlPressedFill = ColorRoleValues.controlPressedFill.color
    static let scrimFill = ColorRoleValues.scrimFill.color
    static let floatShadow = ColorRoleValues.floatShadow.color
    /// The destructive button's ground and edge: `stateCritical` at its share, over whatever surface the button sits on.
    static let destructiveTint = stateCritical.opacity(ColorRoleValues.destructiveTintShare)
    static let destructiveTintHover = stateCritical.opacity(ColorRoleValues.destructiveTintHoverShare)
    static let destructiveTintPressed = stateCritical.opacity(ColorRoleValues.destructiveTintPressedShare)
    static let destructiveTintEdge = stateCritical.opacity(ColorRoleValues.destructiveTintEdgeShare)
}
