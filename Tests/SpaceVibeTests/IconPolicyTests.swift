import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// Every icon comes from a generated set or from SpaceVibe's own verdict glyphs (V5-A4; the v3 rule DL7 it extends): category
/// glyphs from MingCute Line, sidebar, content and Settings glyphs from Phosphor Duotone, the glance widget's session state
/// glyphs from Phosphor Bold, the CLI marks from `CLIMark`; no SF Symbol outside `Gallery/`, no size under 12, and a credit
/// for every set in use. Solar went with the old Settings blocks (2026-11-16). The checks read `allCases`, so a glyph added to a set needs no edit here.
/// The new frame (RD23, RD37, RD38) draws through `FrameIcon`: page icons from SpaceVibe's own set, content glyphs from Phosphor
/// Bold, state glyphs from Phosphor Fill; `FrameIconPolicyTests` below holds the reference mock's names.
@Suite("Icon policy: generated sets")
struct IconPolicyTests {
    static var appSources: URL { StyleBoundaryTests.appSources }

    /// One generated set: the type that holds it, the file the generator writes, what its icon names end with, the credit the
    /// About panel must carry (nil for SpaceVibe's own drawing) and the licence the generator checked.
    struct GlyphSet {
        let glyphs: [any GlyphSource]
        let file: String
        let package: String
        let suffix: String
        let layers: Int
        let credit: String?
        let licence: String
        /// Whether the set strokes lines (SpaceVibe's own page set only).
        var lines = false
    }

    static let sets: [GlyphSet] = [
        GlyphSet(glyphs: CategoryGlyph.allCases, file: "CategoryIconData.swift", package: "@iconify-json/mingcute", suffix: "-line", layers: 1,
                 credit: "MingCute by MingCute Design", licence: "Apache-2.0"),
        GlyphSet(glyphs: ContentGlyph.allCases, file: "ContentIconData.swift", package: "@iconify-json/ph", suffix: "-duotone", layers: 2,
                 credit: "Phosphor Icons", licence: "MIT"),
        GlyphSet(glyphs: StateGlyph.allCases, file: "StateIconData.swift", package: "@iconify-json/ph", suffix: "-bold", layers: 1,
                 credit: "Phosphor Icons", licence: "MIT"),
        GlyphSet(glyphs: InterfaceGlyph.allCases, file: "InterfaceIconData.swift", package: "@iconify-json/ph", suffix: "-bold", layers: 1,
                 credit: "Phosphor Icons", licence: "MIT"),
        GlyphSet(glyphs: SeverityGlyph.allCases, file: "SeverityIconData.swift", package: "@iconify-json/ph", suffix: "-fill", layers: 1,
                 credit: "Phosphor Icons", licence: "MIT"),
        GlyphSet(glyphs: PageGlyph.allCases, file: "PageIconData.swift", package: "Resources/PageIcons.json", suffix: "", layers: 1,
                 credit: nil, licence: "none", lines: true),
    ]

    /// What only the generated sets may draw. `Image(` is allowed in `imageFiles`: the CLI marks are images, not icons, and the
    /// not-allowed pointer is the system cursor's picture.
    static let forbidden: [(name: String, pattern: String)] = [
        ("SF Symbol", #"systemName:|systemImage:|systemSymbolName"#),
        ("image", #"\bImage\("#),
    ]
    static let brandMarkFile = "Components/CLIMark.swift"
    static let imageFiles: Set = [brandMarkFile, "Components/PointerCursor.swift"]

    static func source(_ relative: String) throws -> String {
        try String(contentsOf: appSources.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Matches per file under `Sources/SpaceVibe`, `Gallery/` exempt. Whole-line comments are skipped.
    static func violations() throws -> [String: Int] {
        let expressions = forbidden.map { (name: $0.name, regex: try! NSRegularExpression(pattern: $0.pattern)) }
        var result: [String: Int] = [:]
        let root = appSources.path + "/"
        guard let walker = FileManager.default.enumerator(atPath: appSources.path) else { return result }
        for case let relative as String in walker where relative.hasSuffix(".swift") && !relative.hasPrefix("Gallery/") {
            let source = try String(contentsOfFile: root + relative, encoding: .utf8)
            var count = 0
            for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("//") { continue }
                let range = NSRange(line.startIndex..., in: line)
                for expression in expressions where !(expression.name == "image" && Self.imageFiles.contains(relative)) {
                    count += expression.regex.numberOfMatches(in: line, range: range)
                }
            }
            if count > 0 { result[relative] = count }
        }
        return result
    }

    @Test("no SF Symbol and no other image outside Gallery/")
    func generatedOnly() throws {
        let found = try Self.violations()
        #expect(found.isEmpty, "\(found.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))")
        // The walk itself found the sources: the brand marks file is there and holds its images.
        #expect(FileManager.default.fileExists(atPath: Self.appSources.appendingPathComponent(Self.brandMarkFile).path))
    }

    @Test("the pattern catches what it names")
    func patterns() throws {
        let symbol = try NSRegularExpression(pattern: Self.forbidden[0].pattern)
        let image = try NSRegularExpression(pattern: Self.forbidden[1].pattern)
        func count(_ regex: NSRegularExpression, _ text: String) -> Int { regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) }
        #expect(count(symbol, #"Image(systemName: "trash")"#) == 1)
        #expect(count(symbol, #"Label("Copy", systemImage: "doc.on.doc")"#) == 1)
        #expect(count(image, #"Image(systemName: "trash")"#) == 1)
        #expect(count(image, "SpaceVibeIcon(content: .trash)") == 0)
        #expect(count(image, "ImageRenderer(content: view)") == 0)
    }

    @Test("every glyph has its layers, inside its 24 pt box, from an icon of its set")
    func glyphs() {
        let box = CGRect(x: 0, y: 0, width: GlyphBox.side, height: GlyphBox.side).insetBy(dx: -0.5, dy: -0.5)
        for set in Self.sets {
            #expect(!set.glyphs.isEmpty, "\(set.file)")
            #expect(Set(set.glyphs.map(\.iconName)).count == set.glyphs.count, "\(set.file) names a glyph twice")
            for glyph in set.glyphs {
                #expect(glyph.iconName.hasSuffix(set.suffix), "\(glyph.iconName) is not a \(set.suffix) icon")
                #expect(glyph.hasLightLayer == (set.layers == 2), "\(glyph.iconName)")
                #expect(glyph.layerOpacity > 0 && glyph.layerOpacity <= 1, "\(glyph.iconName)")
                for layer in [GlyphLayer.solid] + (glyph.hasLightLayer ? [.light] : []) {
                    let path = glyph.path(layer)
                    // The own set's solid layer holds only its dots, so a glyph of lines alone has none.
                    if !set.lines { #expect(!path.isEmpty, "\(glyph.iconName) \(layer)") }
                    if !path.isEmpty { #expect(box.contains(path.boundingRect), "\(glyph.iconName) \(layer) leaves its box: \(path.boundingRect)") }
                }
                if !glyph.hasLightLayer { #expect(glyph.path(.light).isEmpty, "\(glyph.iconName) draws a light layer it does not have") }
                if set.lines {
                    // A stroke reaches half its width past the centre line, round caps included.
                    let lines = glyph.linePath()
                    #expect(!lines.isEmpty, "\(glyph.iconName) has no lines")
                    let stroked = lines.boundingRect.insetBy(dx: -glyph.lineWidth / 2, dy: -glyph.lineWidth / 2)
                    #expect(box.contains(stroked), "\(glyph.iconName) lines leave the box: \(stroked)")
                } else {
                    #expect(glyph.lineWidth == 0 && glyph.linePath().isEmpty, "\(glyph.iconName) strokes lines; only the own page set does")
                }
            }
        }
        // The light layer's opacity: the mock's 25% for Phosphor's (its set gives 20%).
        #expect(ContentGlyph.allCases.allSatisfy { $0.layerOpacity == 0.25 && $0.outlineWidth == 0.75 })
        #expect(CategoryGlyph.allCases.allSatisfy { $0.outlineWidth == 0 })
        #expect(StateGlyph.allCases.allSatisfy { $0.outlineWidth == 0 })
    }

    @Test("category glyphs are the three MingCute Line icons of V5-R10; the rest come from Phosphor")
    func categoryAndContent() {
        let category = Dictionary(uniqueKeysWithValues: CategoryGlyph.allCases.map { (String(describing: $0), $0.iconName) })
        #expect(category == ["skill": "flash-line", "subagent": "robot-line", "hook": "fish-symbol-line"])
        // Rules is the mock's checklist glyph, a Phosphor one (D32 names none); the sidebar glyphs are the mock's.
        let content = Dictionary(uniqueKeysWithValues: ContentGlyph.allCases.map { (String(describing: $0), $0.iconName) })
        #expect(content["rule"] == "list-checks-duotone")
        for (name, icon) in [("stack", "stack"), ("pulse", "pulse"), ("gauge", "gauge"), ("sliders", "sliders-horizontal"), ("search", "magnifying-glass"),
                             ("sun", "sun"), ("moon", "moon"), ("stop", "stop-circle"), ("copy", "copy"), ("bug", "bug")] {
            #expect(content[name] == icon + "-duotone", "\(name)")
        }
        // A name belongs to one family, so a category glyph is never picked from the content set by mistake.
        #expect(Set(content.values).isDisjoint(with: Set(category.values)))
    }

    @Test("state glyphs are the four Phosphor Bold icons of GW-R2")
    func stateGlyphs() {
        let state = Dictionary(uniqueKeysWithValues: StateGlyph.allCases.map { (String(describing: $0), $0.iconName) })
        #expect(state == ["circleNotch": "circle-notch-bold", "chatCircleDots": "chat-circle-dots-bold",
                          "checkCircle": "check-circle-bold", "circleDashed": "circle-dashed-bold"])
    }

    @Test("verdict glyphs are SpaceVibe's own: five shapes in fg2, in no generated set")
    func verdicts() throws {
        #expect(VerdictGlyph.Kind.allCases.map { String(describing: $0) } == ["heavy", "used", "never", "dead", "nm"])
        let generated = Set(Self.sets.flatMap { $0.glyphs.map { String(describing: $0) } })
        #expect(generated.isDisjoint(with: VerdictGlyph.Kind.allCases.map { String(describing: $0) }))
        let source = try Self.source("Components/VerdictGlyph.swift")
        #expect(!source.contains("SpaceVibeIcon(") && !source.contains("GlyphSource"), "the verdict glyphs are shapes, not generated paths")
        let palette = try NSRegularExpression(pattern: #"Palette\.(\w+)"#).matches(in: source, range: NSRange(source.startIndex..., in: source))
            .map { String(source[Range($0.range(at: 1), in: source)!]) }
        #expect(Set(palette) == ["fg2", "onVerdict"], "D58: one neutral colour, the cut-out in onVerdict; found \(Set(palette))")
    }

    @Test("icon sizes: 16, 14, 12, 24 and the verdict box's 20, never under 12")
    func sizes() {
        #expect(IconSize.control.points == 16 && IconSize.inline.points == 14 && IconSize.small.points == 12 && IconSize.large.points == 24)
        #expect(IconSize.row.points == 20)
        for size in IconSize.allCases { #expect(size.points >= 12, "\(size)") }
        #expect(IconSize.allCases.map(\.points).min() == 12)
    }

    @Test("every generated file says where it comes from, and the app credits every set in use")
    func attribution() throws {
        for set in Self.sets where !set.glyphs.isEmpty {
            let data = try Self.source("Components/" + set.file)
            #expect(data.hasPrefix("// Generated by scripts/generate-icons.mjs from \(set.package)"), "\(set.file)")
            if let credit = set.credit {
                #expect(data.contains(credit), "\(set.file) header")
                #expect(Credits.text.contains(credit), "the About panel credits \(credit)")
                // Section 4(b) of Apache-2.0 and the notices of the others: each header says the paths were changed.
                #expect(data.contains("Changed from the original"), "\(set.file)")
            } else {
                // SpaceVibe's own drawing has no third-party licence to show.
                #expect(data.contains("SpaceVibe's own drawing") && data.contains("no third-party licence"), "\(set.file)")
            }
        }
        #expect(Credits.text.contains("SIL Open Font License"))
    }

    @Test("each licence a set asks for is shown: MIT's notice and the Apache-2.0 text in the bundle")
    func licences() throws {
        #expect(Credits.text.contains("Copyright (c) 2023 Phosphor Icons"))
        #expect(Credits.text.contains("The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software."))
        // Apache-2.0 section 4(a): the text itself, in the About panel or as a file the credit names and the build copies.
        if !Credits.text.contains("Apache License\n") {
            let name = "MingCute-Apache-2.0.txt"
            #expect(Credits.text.contains("Licenses/" + name))
            let root = StyleBoundaryTests.appSources.deletingLastPathComponent().deletingLastPathComponent()
            let licence = try String(contentsOf: root.appendingPathComponent("Resources/Licenses/" + name), encoding: .utf8)
            #expect(licence.contains("Apache License") && licence.contains("Version 2.0, January 2004") && licence.contains("4. Redistribution."))
            let script = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
            #expect(script.contains("Resources/Licenses/*.txt"))
        }
    }

    /// A dependency the app ships needs a Credits notice and a licence file in `Resources/Licenses/` that `scripts/build-app.sh` copies into the bundle.
    /// `credit` is a phrase of its Credits notice, `file` its licence file, `phrase` what that file must say.
    struct ShippedDependency {
        let name: String
        let credit: String
        let file: String
        let phrase: String
    }

    static let shipped: [ShippedDependency] = [
        ShippedDependency(name: "Sparkle", credit: "Licenses/Sparkle-MIT.txt", file: "Sparkle-MIT.txt", phrase: "bspatch.c and bsdiff.c"),
        ShippedDependency(name: "Go", credit: "Copyright 2009 The Go Authors.", file: "Go-BSD-3-Clause.txt", phrase: "Neither the name of Google LLC"),
    ]

    @Test("every linked dependency has a Credits notice and a licence file: Sparkle, the Go runtime, each Go module")
    func linkedDependenciesAreCredited() throws {
        let root = StyleBoundaryTests.appSources.deletingLastPathComponent().deletingLastPathComponent()
        let manifest = try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)
        let goMod = try String(contentsOf: root.appendingPathComponent("core/go.mod"), encoding: .utf8)
        func matches(_ pattern: String, in text: String) -> [String] {
            let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
        }
        // Linked: each Swift package in the manifest, the Go toolchain of go.mod (the runtime is inside the core binary), each module it requires.
        let packages = matches(#"\.package\(url:\s*"[^"]*/([^"/]+?)(?:\.git)?""#, in: manifest)
        #expect(!packages.isEmpty && !matches(#"^go\s+(\S+)"#, in: goMod).isEmpty, "the manifest and go.mod were read")
        for package in packages {
            #expect(Self.shipped.contains { $0.name == package }, "Swift package \(package) has no entry in IconPolicyTests.shipped (add its Credits notice and licence file)")
        }
        // The line-initial `require x v` and the lines of a `require ( ... )` block, `// indirect` ones included.
        let modules = matches(#"^require\s+([^\s(]+)\s+v"#, in: goMod) + matches(#"^\t([^\s]+)\s+v[^\s]+(?:\s*//.*)?$"#, in: goMod)
        for module in modules {
            #expect(Credits.text.contains(module), "Go module \(module) is linked into the core but Credits does not name it")
        }
        let licences = root.appendingPathComponent("Resources/Licenses")
        let script = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        #expect(script.contains("Resources/Licenses/*.txt"))
        for dependency in Self.shipped {
            #expect(Credits.text.contains(dependency.credit), "Credits has no notice for \(dependency.name)")
            let licence = try? String(contentsOf: licences.appendingPathComponent(dependency.file), encoding: .utf8)
            #expect(licence?.contains(dependency.phrase) == true, "Resources/Licenses/\(dependency.file) is missing or is not the \(dependency.name) licence")
        }
    }
}

/// The new frame's icons (RD23, RD37, RD38): every name the reference mock draws resolves through `FrameIcon`, each from the set
/// its role names, and none from the v5 MingCute or Duotone sets.
@Suite("Icon policy: the new frame")
struct FrameIconPolicyTests {
    /// Every icon name the reference mock draws (`~/scratch/spacevibe-reins/2026-11-20-redesign-v2/mock.html`, 2026-11-21): the
    /// names its pages pass to `ic(…)` or list as a page, row, menu or capability icon; 49 of the 67 in its icon map.
    static let mockNames: Set<String> = [
        "anchor-simple", "arrow-clockwise", "arrow-counter-clockwise", "arrow-up", "book-open-text", "broom", "caret-down",
        "chat-circle-dots", "check", "check-circle", "check-circle-fill", "circle-dashed", "circle-notch", "clock",
        "clock-counter-clockwise", "copy", "eye", "file-text", "folder-open", "folder-simple", "gauge", "gear", "hard-drives",
        "info", "info-fill", "link", "lock-key", "lock-simple", "magnifying-glass", "minus", "plugs-connected", "plus", "prohibit",
        "pulse", "push-pin", "question", "shield-check", "shield-warning", "sidebar-simple", "sliders-horizontal", "stop-circle",
        "terminal-window", "trash", "tray", "users-three", "warning", "warning-fill", "x", "x-circle-fill",
    ]

    /// The mock stores its own page icons under the Phosphor names they replaced (its `apply-icon-set.py`).
    static let pageIcons: [String: PageGlyph] = [
        "tray": .inbox, "broom": .clean, "book-open-text": .skills, "users-three": .subagents,
        "anchor-simple": .hooks, "shield-check": .rules, "gauge": .limits, "pulse": .activity,
    ]

    @Test("every icon name the mock draws resolves, and the frame holds no other")
    func mockNamesResolve() {
        #expect(Self.mockNames.count == 49)
        for name in Self.mockNames.sorted() { #expect(FrameIcon(rawValue: name) != nil, "\(name) does not resolve") }
        let extra = Set(FrameIcon.allCases.map(\.rawValue)).subtracting(Self.mockNames)
        #expect(extra.isEmpty, "not drawn by the mock: \(extra.sorted())")
    }

    @Test("the 8 page icons come from SpaceVibe's own Bold set")
    func pages() {
        #expect(Set(PageGlyph.allCases) == Set(Self.pageIcons.values))
        for (name, page) in Self.pageIcons {
            #expect((FrameIcon(rawValue: name)?.glyph as? PageGlyph) == page, "\(name)")
        }
        // Bold is stroke 24 on the 256 grid: 2.25 in the 24 box, the mock's 1.875 pt at the sidebar's 20 pt.
        #expect(PageGlyph.allCases.allSatisfy { $0.lineWidth == 2.25 && $0.outlineWidth == 0 && !$0.hasLightLayer })
        // Only the page icons are the own set.
        let own = FrameIcon.allCases.filter { $0.glyph is PageGlyph }.map(\.rawValue)
        #expect(Set(own) == Set(Self.pageIcons.keys))
    }

    @Test("content glyphs are Phosphor Bold, state glyphs Phosphor Fill, none is MingCute or Duotone")
    func roles() {
        for icon in FrameIcon.allCases {
            let glyph = icon.glyph
            #expect(!(glyph is CategoryGlyph) && !(glyph is ContentGlyph), "\(icon) takes a v5 MingCute or Duotone glyph")
            if Self.pageIcons[icon.rawValue] != nil { continue }
            if icon.rawValue.hasSuffix("-fill") {
                #expect(glyph is SeverityGlyph && glyph.iconName == icon.rawValue, "\(icon) is \(glyph.iconName)")
            } else {
                // The session state glyphs are the ones `SessionStateGlyph` and the glance widget draw (`StateGlyph`).
                #expect((glyph is InterfaceGlyph || glyph is StateGlyph) && glyph.iconName == icon.rawValue + "-bold", "\(icon) is \(glyph.iconName)")
            }
        }
        #expect(Set(FrameIcon.allCases.compactMap { $0.glyph as? StateGlyph }) == Set(StateGlyph.allCases))
        // Every glyph generated for the frame is reachable from it.
        let reached = Set(FrameIcon.allCases.map { $0.glyph.iconName })
        let generated: [any GlyphSource] = InterfaceGlyph.allCases + SeverityGlyph.allCases + PageGlyph.allCases
        for glyph in generated { #expect(reached.contains(glyph.iconName), "\(glyph.iconName) is generated but no FrameIcon takes it") }
    }

    @Test("the own set's source is committed and holds exactly the page glyphs")
    func ownSource() throws {
        let root = StyleBoundaryTests.appSources.deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/PageIcons.json"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["grid"] as? Int == 256 && json["stroke"] as? Int == 24)
        let icons = try #require(json["icons"] as? [String: Any])
        #expect(Set(icons.keys) == Set(PageGlyph.allCases.map(\.iconName)))
    }
}
