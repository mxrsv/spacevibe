import Foundation
import Testing
@testable import SpaceVibe

/// `CLIRegistry` is the one table of per-CLI UI facts (MC-R1). Every CLI the wire can name has a complete entry, the entries
/// agree with the wire ids, and no CLI's colour reads as a state or as the accent (PRODUCT.md colour meanings, MC-R12).
@Suite("CLI registry: one complete entry per CLI")
struct CLIRegistryTests {
    private typealias P = PaletteValue

    static var entries: [CLIIdentity] { CLIRegistry.limitsCLIs.map(CLIRegistry.identity) }

    static var brandFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SpaceVibeTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // checkout
            .appendingPathComponent("Resources/Brand")
    }

    @Test("every CLI the wire names has an entry under its own id, in the wire's order")
    func entriesMatchTheWire() {
        #expect(CLIRegistry.limitsCLIs == CoreLimitsCLI.allCases)
        #expect(CLIRegistry.inventoryCLIs == CoreCLI.allCases)
        for cli in CoreLimitsCLI.allCases { #expect(CLIRegistry.identity(cli).id == cli.rawValue) }
        for cli in CoreCLI.allCases {
            #expect(CLIRegistry.identity(cli).id == cli.rawValue)
            #expect(CoreLimitsCLI(cli).rawValue == cli.rawValue)
            #expect(CoreCLI(CoreLimitsCLI(cli)) == cli)
        }
        // The inventory lists a subset of the CLIs the app shows, in the same order.
        #expect(CLIRegistry.limitsCLIs.compactMap { CoreCLI($0) } == CLIRegistry.inventoryCLIs)
    }

    @Test("every entry has a label, a mark that exists, and a full tone")
    func entriesAreComplete() {
        let entries = Self.entries
        #expect(!entries.isEmpty)
        for entry in entries {
            #expect(!entry.label.trimmingCharacters(in: .whitespaces).isEmpty, "\(entry.id) has no label")
            #expect(entry.mark.fileName.hasSuffix(".svg"), "\(entry.id): \(entry.mark.fileName)")
            let mark = Self.brandFolder.appendingPathComponent(entry.mark.fileName)
            #expect(FileManager.default.fileExists(atPath: mark.path), "\(entry.id): no mark at \(mark.path)")
            let fill = entry.tone.fillValue
            #expect(fill.lightAlpha == 1 && fill.darkAlpha == 1, "\(entry.id): the fill must be opaque")
            if let opacity = entry.tone.barOpacity { #expect(opacity > 0 && opacity < 1, "\(entry.id): bar opacity \(opacity)") }
        }
        #expect(Set(entries.map(\.id)).count == entries.count, "two entries share an id")
        #expect(Set(entries.map(\.label)).count == entries.count, "two entries share a label")
        #expect(Set(entries.map(\.mark.fileName)).count == entries.count, "two entries share a mark")
    }

    /// The colours that mean a state, and the accent's: a CLI tone is none of them.
    static let reserved: [(String, ColorValue)] = [
        ("ok", P.ok), ("warn", P.warn), ("bad", P.bad), ("badSolid", P.badSolid), ("badText", P.badText),
        ("successInk", P.successInk), ("warnInk", P.warnInk), ("dangerInk", P.dangerInk),
        ("accent", P.accent), ("accentText", P.accentText), ("accentSolid", P.accentSolid), ("accentBg", P.accentBg),
        ("accentInk", P.accentInk),
    ] + HuePolicyTests.sessionStates

    private static func same(_ a: ColorValue, _ b: ColorValue) -> Bool {
        a.light == b.light && a.dark == b.dark && a.lightAlpha == b.lightAlpha && a.darkAlpha == b.darkAlpha
    }

    /// A grey tone (Codex's text colour, Gemini CLI's neutral) has no hue to collide; a chromatic one keeps out of every state's
    /// hue family and the accent's, as `HuePolicyTests` measures them.
    @Test("no CLI tone is a state colour or the accent, nor sits in their hue family")
    func tonesKeepClearOfStatesAndAccent() {
        let hueFamilies = HuePolicyTests.states + [("accent", P.accent)]
        for entry in Self.entries {
            let tone = entry.tone.fillValue
            for (name, value) in Self.reserved {
                #expect(!Self.same(tone, value), "\(entry.id)'s tone is the \(name) token")
            }
            for appearance in Appearance.allCases {
                let lch = ColorMath.oklch(tone.rgb(appearance))
                guard lch.c >= HuePolicyTests.achromaticChroma else { continue }
                for (name, value) in hueFamilies {
                    let distance = ColorMath.hueDistance(lch.h, ColorMath.oklch(value.rgb(appearance)).h)
                    #expect(distance > HuePolicyTests.familyHalfWidth,
                            "\(appearance): \(entry.id)'s tone is \(String(format: "%.1f", distance))° from \(name)")
                }
            }
        }
    }

    /// An id the wire does not know never reaches the registry: decoding refuses it, so no CLI silently takes another's look.
    @Test("an unknown CLI id fails to decode instead of falling back to another CLI")
    func unknownIDFailsLoudly() {
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) { try decoder.decode(CoreCLI.self, from: Data(#""cursor""#.utf8)) }
        #expect(throws: DecodingError.self) { try decoder.decode(CoreLimitsCLI.self, from: Data(#""cursor""#.utf8)) }
        #expect(throws: DecodingError.self) { try decoder.decode(CoreCLI.self, from: Data(#""gemini""#.utf8)) }
        #expect(CoreCLI(CoreLimitsCLI.gemini) == nil, "Gemini CLI has no inventory, so it maps to no inventory CLI")
    }
}
