import AppKit
import Foundation
import Testing
@testable import SpaceVibe

/// The design-system tokens (DS-R1 to DS-R9) hold the spec's values under names that never reuse a v5 token name with
/// another value (AR6). Contrast lives in `RoleContrastTests`.
@Suite("Design-system tokens: values and names")
struct RoleTokenTests {
    private typealias V = ColorRoleValues

    /// DS-R1's opaque roles by spec name: dark, light, and the Increase Contrast pair where the spec gives one.
    private static let specOpaque: [String: (dark: UInt32, light: UInt32, increased: (UInt32, UInt32)?)] = [
        "canvas": (0x111214, 0xF4F4F5, nil), "group": (0x191A1D, 0xFFFFFF, nil), "side": (0x141518, 0xE9E9EB, nil),
        "ink": (0xF5F6F8, 0x14171D, nil), "ink2": (0xD6D9DF, 0x434955, nil), "ink3": (0xA9AEB8, 0x616775, (0xBCC1CA, 0x4E5462)),
        "faint": (0x3A404C, 0xC9CFDA, (0x6B717D, 0x8A909C)),
        "ok": (0x4CC38A, 0x17784C, nil), "warn": (0xE8B33A, 0x8A6200, nil), "crit": (0xEF6B5E, 0xC42F1D, nil),
        "warn-bar": (0xE8B33A, 0xB07E00, nil), "crit-bar": (0xEF6B5E, 0xD9402F, nil), "crit-ink": (0xFF8A7D, 0x9E1D0F, nil),
        "primary": (0x0B6FE4, 0x0B6FE4, nil), "on-primary": (0xFFFFFF, 0xFFFFFF, nil), "link": (0x5AA2FF, 0x0A64D0, nil),
        "clay": (0xE08463, 0xAD4A28, nil), "logo-codex": (0xE9E9ED, 0x2A2B30, nil),
        "c-skills": (0xA38BF5, 0x6A4FD8, nil), "c-subs": (0x7BDEE0, 0x178082, nil), "c-hooks": (0xCF84E0, 0x9A3FB0, nil),
        "c-rules": (0x9AA3B5, 0x586273, nil),
        "s-work": (0xE1B236, 0x9C7802, nil), "s-wait": (0xEB871B, 0xAF6005, nil), "s-done": (0x6FBE94, 0x27885D, nil),
    ]

    /// DS-R1's translucent roles: white (dark; black for `scrim`) and black (light) at these percentages, and the Increase
    /// Contrast pair.
    private static let specTranslucent: [String: (dark: Double, light: Double, increased: (Double, Double)?)] = [
        "hair": (8, 9, nil), "alt": (3, 2, nil), "hover": (6, 5, nil), "sel": (9, 7, nil),
        "ctl": (9, 5, (20, 15)), "ctl-h": (15, 9, (27, 20)), "ctl-a": (20, 13, nil), "scrim": (50, 30, nil),
    ]

    private static func role(_ specName: String) -> ColorRoleValue? {
        V.all.first { $0.specName == specName }?.value
    }

    @Test("every opaque role holds DS-R1's values, Increase Contrast included")
    func opaqueValues() throws {
        for (name, spec) in Self.specOpaque.sorted(by: { $0.key < $1.key }) {
            let value = try #require(Self.role(name), "no role for \(name)")
            #expect(value.dark == .init(hex: spec.dark) && value.light == .init(hex: spec.light), "\(name)")
            let increased = spec.increased ?? (spec.dark, spec.light)
            #expect(value.darkIncreased == .init(hex: increased.0) && value.lightIncreased == .init(hex: increased.1), "\(name) IC")
        }
    }

    @Test("every translucent role is white or black at DS-R1's share, to the nearest 8-bit step")
    func translucentValues() throws {
        for (name, spec) in Self.specTranslucent.sorted(by: { $0.key < $1.key }) {
            let value = try #require(Self.role(name), "no role for \(name)")
            #expect(value.dark.hex == (name == "scrim" ? 0x000000 : 0xFFFFFF) && value.light.hex == 0x000000, "\(name)")
            #expect(abs(value.dark.alpha * 100 - spec.dark) < 0.6 && abs(value.light.alpha * 100 - spec.light) < 0.6, "\(name)")
            if let increased = spec.increased {
                #expect(abs(value.darkIncreased.alpha * 100 - increased.0) < 0.6, "\(name) IC dark")
                #expect(abs(value.lightIncreased.alpha * 100 - increased.1) < 0.6, "\(name) IC light")
            }
        }
        // The Increase Contrast hairline is `faint`'s opaque grey.
        #expect(V.hairline.darkIncreased == V.faint.darkIncreased && V.hairline.lightIncreased == V.faint.lightIncreased)
    }

    @Test("the data steps are ink mixed into the group surface (RD-R8), with DS-R1's Increase Contrast greys")
    func dataSteps() {
        let shares: [(ColorRoleValue, Double, Double)] = [
            (V.data1, 0.08, 0.08), (V.data2, 0.16, 0.16), (V.data3, 0.28, 0.28), (V.data4, 0.38, 0.44), (V.dataBar, 0.55, 0.55),
        ]
        for (value, dark, light) in shares {
            #expect(value.dark.hex == ColorRoleValue.mixHex(V.ink.dark.hex, dark, V.groupSurface.dark.hex))
            #expect(value.light.hex == ColorRoleValue.mixHex(V.ink.light.hex, light, V.groupSurface.light.hex))
        }
        // The mock's own result for the darkest dark step: `color-mix(in srgb, #F5F6F8 38%, #191A1D)`.
        #expect(V.data4.dark.hex == 0x6D6E70)
        #expect(shares.map { $0.0.darkIncreased.hex } == [0x6B717D, 0x858B96, 0xA3A8B1, 0xC4C8CE, 0xE3E5E8])
        #expect(shares.map { $0.0.lightIncreased.hex } == [0x8A909C, 0x6E7480, 0x545A66, 0x3B404B, 0x22262E])
    }

    @Test("the primary's hover and pressed steps are 14% white and 16% black (RD-R9)")
    func primarySteps() {
        #expect(V.primaryActionHover.dark.hex == 0x2D83E8 && V.primaryActionHover.light.hex == 0x2D83E8)
        #expect(V.primaryActionPressed.dark.hex == 0x095DC0 && V.primaryActionPressed.light.hex == 0x095DC0)
    }

    @Test("Increase Contrast changes exactly the rows DS-R1 marks")
    func increasedContrastRows() {
        let changed = Set(V.all.filter { $0.value.changesWithIncreasedContrast }.map(\.specName))
        #expect(changed == ["ink3", "faint", "data-1", "data-2", "data-3", "data-4", "data-bar", "hair", "ctl", "ctl-h"])
    }

    @Test("the session inks are v5's, unchanged (SessionStateGlyph)")
    func sessionInks() {
        let pairs: [(ColorRoleValue, ColorValue)] = [
            (V.sessionWork, PaletteValue.sessionWorking), (V.sessionWait, PaletteValue.sessionWaiting),
            (V.sessionDone, PaletteValue.sessionDone),
        ]
        for (new, old) in pairs { #expect(new.dark.hex == old.dark && new.light.hex == old.light) }
    }

    @Test("the appearance resolves to the right variant, with Increase Contrast from the name or the setting")
    func variantResolution() {
        #expect(ColorRoleVariant(appearanceName: .darkAqua, systemIncreasesContrast: false) == .dark)
        #expect(ColorRoleVariant(appearanceName: .aqua, systemIncreasesContrast: false) == .light)
        #expect(ColorRoleVariant(appearanceName: .accessibilityHighContrastDarkAqua, systemIncreasesContrast: false) == .darkIncreased)
        #expect(ColorRoleVariant(appearanceName: .accessibilityHighContrastAqua, systemIncreasesContrast: false) == .lightIncreased)
        #expect(ColorRoleVariant(appearanceName: .darkAqua, systemIncreasesContrast: true) == .darkIncreased)
        #expect(ColorRoleVariant(appearanceName: .aqua, systemIncreasesContrast: true) == .lightIncreased)
        #expect(ColorRoleVariant(appearanceName: nil, systemIncreasesContrast: false) == .light)
    }

    @Test("type roles: 11/12/13/15/22/40 pt, Rounded only on figures, SF Mono on mono, 600 only for sidebar labels")
    func typeRoles() {
        let roles = TypeRole.all
        #expect(Set(roles.map(\.role.size)) == [11, 12, 13, 15, 22, 40])
        let boxes = Dictionary(uniqueKeysWithValues: roles.map { ($0.specName, ($0.role.size, $0.role.lineHeight)) })
        #expect(boxes["hero"]! == (40, 44) && boxes["figure"]! == (22, 26) && boxes["title"]! == (15, 20))
        #expect(boxes["body"]! == (13, 18) && boxes["quiet"]! == (12, 16) && boxes["caption"]! == (11, 14) && boxes["mono"]! == (12, 16))
        #expect(roles.filter { $0.role.face == .figures }.map(\.name) == ["hero", "windowFigure"])
        #expect(roles.filter { $0.role.face == .mono }.map(\.name) == ["mono"])
        #expect(roles.filter { $0.role.weight == .sidebarLabel }.map(\.name) == ["sidebarLabel"])
        for (name, _, role) in roles {
            #expect(role.medium.weight != .regular, "\(name)")
            #expect(role.medium.weight == (role.weight == .sidebarLabel ? .sidebarLabel : .medium), "\(name)")
            #expect(role.figures.face == (role.face == .mono ? .mono : .figures), "\(name)")
            #expect(role.lineSpacing >= 0 && role.naturalLineHeight > role.size, "\(name)")
        }
        #expect(TypeRole.bodyText.nsFont.fontDescriptor.symbolicTraits.contains(.monoSpace) == false)
        #expect(TypeRole.mono.nsFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test("space, radius, sizes, meters, focus and opacity hold DS-R3 to DS-R7 and RD-R6, RD29")
    func layoutValues() {
        #expect(SpaceRole.steps == [2, 4, 6, 8, 10, 12, 16, 20, 24])
        #expect(SpaceRole.toolbarClearance(.glass) == 68 && SpaceRole.toolbarClearance(.solid) == 64)
        #expect(SpaceRole.titleBarClearance == 36 && SpaceRole.emptyStateTop == 72)
        #expect(SpaceRole.inspectorWidth == 308 && SpaceRole.inspectorWideWidth == 336)
        #expect(RadiusRole.steps == [.radius(4), .radius(6), .radius(8), .radius(10), .radius(14), .radius(18), .capsule])
        #expect(RadiusRole.windowCorner(.glass) == .radius(26) && RadiusRole.windowCorner(.solid) == .radius(12))
        #expect(RadiusRole.sidebarCorner(.glass) == .radius(18) && RadiusRole.sidebarCorner(.solid) == .radius(0))
        #expect(RadiusRole.sidebarInset(.glass) == 8 && RadiusRole.sidebarInset(.solid) == 0)
        #expect(RadiusRole.groupCorner(.glass) == .radius(14) && RadiusRole.groupCorner(.solid) == .radius(10))
        #expect(RadiusRole.controlCorner(.glass) == .capsule && RadiusRole.controlCorner(.solid) == .radius(6))
        #expect(RadiusRole.popoverCorner(.glass) == .radius(14) && RadiusRole.popoverCorner(.solid) == .radius(10))
        #expect([SizeRole.controlRegular, SizeRole.controlSmall, SizeRole.controlMini, SizeRole.hitCell] == [32, 26, 20, 28])
        #expect(SizeRole.minimumHitTarget == 24 && SizeRole.tableRow == 48 && SizeRole.tableRowWrapped == 60 && SizeRole.listRow == 44)
        #expect([SizeRole.segmentedRegular, SizeRole.segmentRegular, SizeRole.segmentedSmall, SizeRole.segmentSmall] == [32, 28, 26, 22])
        #expect([SizeRole.meterRow, SizeRole.meterHero, SizeRole.meterProgress, SizeRole.paceTickWidth] == [4, 6, 3, 2])
        #expect(SizeRole.focusBar == 3)
        #expect(SizeRole.icons == [12, 14, 16, 20, 40] && SizeRole.logo16 == 16 && SizeRole.logo20 == 20)
        #expect(OpacityRole.disabled == 0.42 && OpacityRole.dim == 0.55 && OpacityRole.ghost == 0.35)
        #expect(MotionRole.lift(reduceMotion: true) == 0 && MotionRole.lift(reduceMotion: false) == 1)
        #expect(MotionRole.scale(pressed: true, reduceMotion: true) == 1 && MotionRole.scale(pressed: true, reduceMotion: false) == 0.98)
    }

    // MARK: AR6 names

    private static var sources: URL { StyleBoundaryTests.appSources }

    /// The token names a file declares: every `static let`, `static var` and `static func`, comments skipped.
    private static func staticNames(in files: [String]) throws -> Set<String> {
        let expression = try NSRegularExpression(pattern: #"static (?:let|var|func) ([A-Za-z0-9_]+)"#)
        var names: Set<String> = []
        for file in files {
            let source = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            for line in source.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                let text = String(line)
                for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    names.insert((text as NSString).substring(with: match.range(at: 1)))
                }
            }
        }
        return names
    }

    /// v5's token files, and `TextTone`'s cases (a view writes `tone: .primary`, so those are token names too).
    static let v5TokenFiles = [
        "Tokens/Palette.swift", "Tokens/Metrics.swift", "Tokens/SpaceVibeType.swift", "Tokens/TypeScale.swift",
        "Tokens/InterFont.swift", "Components/PageLayout.swift",
    ]
    static let v5TextTones = ["primary", "secondary", "tertiary", "accent", "onAccent", "inverse", "danger", "warn", "success", "claude", "codex"]
    static let newTokenFiles = ["Tokens/ColorRole.swift", "Tokens/TypeRole.swift", "Tokens/LayoutRole.swift"]

    @Test("no new token reuses a v5 token name with another value (AR6)")
    func namesDoNotReuseV5Names() throws {
        let v5 = try Self.staticNames(in: Self.v5TokenFiles).union(Self.v5TextTones)
        let new = try Self.staticNames(in: Self.newTokenFiles)
        #expect(v5.contains("bgPanel") && new.contains("groupSurface"), "read no names from the token sources")
        // Shared with the same value: the session ink of a done session (checked in `sessionInks`).
        let sameValue: Set<String> = ["sessionDone"]
        let reused = new.intersection(v5).subtracting(sameValue).sorted()
        #expect(reused.isEmpty, "new token names that are v5 names: \(reused). Rename the new one (AR6).")
        #expect(Set(TextTone.allCasesForNameCheck.map { "\($0)" }) == Set(Self.v5TextTones), "TextTone gained a case: add it here")
    }
}

private extension TextTone {
    /// Every case, for the name check; a new case fails to compile here until it is listed.
    static var allCasesForNameCheck: [TextTone] {
        let all: [TextTone] = [.primary, .secondary, .tertiary, .accent, .onAccent, .inverse, .danger, .warn, .success, .claude, .codex]
        for tone in all {
            switch tone {
            case .primary, .secondary, .tertiary, .accent, .onAccent, .inverse, .danger, .warn, .success, .claude, .codex: break
            }
        }
        return all
    }
}
