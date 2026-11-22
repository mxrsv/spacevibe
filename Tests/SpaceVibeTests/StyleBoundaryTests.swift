import Foundation
import Testing

/// Screens compose base components; they never style themselves (spec `docs/specs/2026-11-03-spacevibe-design-language.md`,
/// "Component base", DL3). A restyle then means editing `Sources/SpaceVibe/Tokens` or `Sources/SpaceVibe/Components` only.
///
/// This reads source text: every forbidden pattern is lexical. `allowed` was a ratchet while the screens moved onto components;
/// it is now empty, so any literal in a screen folder fails. A count that differs from an entry in either direction fails too.
/// DS-R12 adds `.opacity(` with a fraction, `.tracking(`, `.kerning(` and ideal frame sizes to the forbidden list.
///
/// AR6 (redesign build plan): a new-frame view uses only the design-system tokens (`ColorRole`, `TypeRole`, `SpaceRole`,
/// `RadiusRole`, `SizeRole`, `OpacityRole`, `ShadowRole`, `MotionRole`), never a v5 token. How a file is told apart:
/// `v5Files` (at the end of this file) is the frozen list of every screen and component file that existed when
/// the redesign started (2026-11-21). Every other `.swift` file in a screen folder or in `Components/` is a new-frame file,
/// so a new file is checked from the day it appears and nobody has to remember to mark it. The list only shrinks: RB-X1
/// deletes the v5 files, and `v5FilesExist` then asks for the entry to go. Adding a name to it needs a reviewer's yes.
@Suite("Style boundary: screens compose components")
struct StyleBoundaryTests {
    /// Folders that are screens. A listed folder need not exist yet: `measured()` skips a missing one and checks it the day it
    /// appears.
    static let screenFolders = [
        "Rules", "Activity", "Shell", "Limits", "Settings",
        "Agents", "Skills", "Subagents", "Hooks", "Glance",
        "Inbox", "Clean",
    ]

    /// Folders under `Sources/SpaceVibe` that are not screens: tokens and components own the look, `Gallery/` lays out specimens,
    /// `App/` is the entry point, `Core/` is the engine seam (DTOs and the `CoreService` adapters, no views).
    static let exemptFolders = ["Tokens", "Components", "Gallery", "App", "Core"]

    /// New v5 screen folders (V5-A3): none of them may ever sit in `allowed`.
    static let v5Folders = ["Agents", "Skills", "Subagents", "Hooks", "Glance"]

    /// What only `Tokens/` and `Components/` may contain.
    static let forbidden: [(name: String, pattern: String)] = [
        ("system font", #"Font\.system|\.system\(size"#),
        ("raw font", #"\.font\("#),
        ("palette colour", #"Palette\."#),
        ("colour literal", #"\bColor\("#),
        ("radius literal", #"cornerRadius:\s*[0-9]"#),
        // Zero is structure, not a design value, so `spacing: 0` and `.padding(.top, 0)` pass.
        ("padding literal", #"\.padding\([^)]*?\b[1-9][0-9]*(\.[0-9]+)?\s*\)"#),
        ("spacing literal", #"spacing:\s*[1-9]"#),
        ("frame literal", #"\.frame\([^)]*?\b(width|height|minWidth|minHeight|idealWidth|idealHeight|maxWidth|maxHeight):\s*[1-9]"#),
        // DS-R12. Opacity 0 and 1 show and hide (structure); a fraction is a design value (`OpacityRole`). Letter-spacing is
        // never changed (RD-R5), so any tracking or kerning fails.
        ("opacity literal", #"\.opacity\([^)]*?(?<![A-Za-z0-9_.])0?\.[0-9]*[1-9]"#),
        ("tracking", #"\.(tracking|kerning)\("#),
        // V5-R8: a screen never paints its own ground, edge, shadow, gradient or looping motion; a component does.
        ("background", #"\.background\s*(\{|\([^)]*?(Color|Rectangle|Capsule|Circle|Ellipse|\.fill|Material|\.(clear|white|black|gray|red|green|blue|orange|yellow|primary|secondary)\b))"#),
        ("border", #"\.border\("#),
        ("shadow", #"\.shadow\("#),
        ("overlay shape", #"\.overlay\s*(\{|\([^)]*?(Rectangle|Capsule|Circle|Ellipse|stroke|\.fill|Color|Gradient))"#),
        ("gradient", #"\b(Linear|Radial|Angular|Elliptical)Gradient\b"#),
        ("looping animation", #"repeatForever"#),
        // A screen draws no shape and paints none, wherever the shape sits (one line or a trailing closure). `contentShape(`
        // sets a hit area, draws nothing, and is allowed.
        ("shape", #"(?<!contentShape\()\b(Rectangle|RoundedRectangle|UnevenRoundedRectangle|Capsule|Circle|Ellipse)\s*\("#),
        ("shape paint", #"\.(stroke|strokeBorder|fill|clipShape)\s*\("#),
        // RB-F3: colour by name and the deprecated radius modifier. `Color.clear` is structure (a spacer), not a colour.
        ("radius modifier", #"\.cornerRadius\("#),
        ("named colour", #"\bColor\.(?!clear\b)[a-z]\w*"#),
        ("AppKit colour", #"\bNSColor\b"#),
        ("system colour", systemColourPattern),
        ("foreground colour", #"\.foregroundColor\("#),
    ]

    /// A colour the system names (`.red`, `.secondary`, `.accentColor`) handed to a style modifier.
    static let systemColourPattern = #"\.(foregroundStyle|tint|fill|stroke|strokeBorder|background|border)\(\s*\.(red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|white|gray|black|primary|secondary|tertiary|quaternary|accentColor)\b"#

    /// Empty since 2026-11-03 (design-language plan T6): no screen file may hold a style literal. A file that truly needs an
    /// exception gets an entry here with a comment saying why, and a reviewer has to agree. An old screen file that hits only
    /// a V5-R8 pattern may sit here marked "removed at X1"; a file in `v5Folders` never does (V5-A3). Measured on 2026-11-07:
    /// the V5-R8 patterns hit no file in today's screen folders, so nothing was needed.
    static let allowed: [String: Int] = [:]

    static var appSources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SpaceVibeTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // checkout
            .appendingPathComponent("Sources/SpaceVibe")
    }

    /// Forbidden matches in one file, over its logical lines (`logicalLines`).
    static func violations(in source: String) -> Int {
        let expressions = forbidden.map { try! NSRegularExpression(pattern: $0.pattern) }
        var count = 0
        for code in logicalLines(source) {
            let range = NSRange(code.startIndex..., in: code)
            for expression in expressions { count += expression.numberOfMatches(in: code, range: range) }
        }
        return count
    }

    /// The code of a file as logical lines: string literals blanked (an interpolation inside one is blanked with it, so a
    /// word in a label never counts), whole-line and trailing comments dropped, and a call whose parentheses stay open
    /// joined with the lines that close it, so a literal on a continuation line (`.frame(\n width: 20)`) is judged with its
    /// modifier (RB-F3).
    static func logicalLines(_ source: String) -> [String] {
        let literal = try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#)
        var lines: [String] = []
        var pending = ""
        var depth = 0
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            var code = literal.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: #""""#)
            if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
            pending += pending.isEmpty ? code : " " + code
            depth += code.filter { $0 == "(" }.count - code.filter { $0 == ")" }.count
            if depth <= 0 {
                lines.append(pending)
                pending = ""
                depth = 0
            }
        }
        if !pending.isEmpty { lines.append(pending) }
        return lines
    }

    static func measured() throws -> [String: Int] {
        var result: [String: Int] = [:]
        let fileManager = FileManager.default
        for folder in screenFolders {
            let directory = appSources.appendingPathComponent(folder)
            guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { continue }
            for name in names where name.hasSuffix(".swift") {
                let source = try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
                let count = violations(in: source)
                if count > 0 { result["\(folder)/\(name)"] = count }
            }
        }
        return result
    }

    @Test("no screen file gains a style literal, and every removed one is written down")
    func ratchet() throws {
        let now = try Self.measured()
        #expect(!now.isEmpty || Self.allowed.isEmpty, "found no screen sources under \(Self.appSources.path)")
        var problems: [String] = []
        for file in Set(now.keys).union(Self.allowed.keys).sorted() {
            let found = now[file] ?? 0, allowed = Self.allowed[file] ?? 0
            if found > allowed { problems.append("\(file): \(found) style literals, \(allowed) allowed. Use a component or token.") }
            if found < allowed { problems.append("\(file): \(found) style literals, the list says \(allowed). Lower its entry.") }
        }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test("every folder under Sources/SpaceVibe is a listed screen folder or exempt")
    func everyFolderIsKnown() throws {
        let entries = try FileManager.default.contentsOfDirectory(atPath: Self.appSources.path)
        var isDirectory: ObjCBool = false
        let folders = entries.filter {
            FileManager.default.fileExists(atPath: Self.appSources.appendingPathComponent($0).path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
        #expect(folders.contains("Components"), "found no folders under \(Self.appSources.path)")
        let unknown = folders.filter { !Self.screenFolders.contains($0) && !Self.exemptFolders.contains($0) }.sorted()
        #expect(unknown.isEmpty, "unknown folders \(unknown): list each in screenFolders (a screen) or exemptFolders (not a screen)")
    }

    @Test("a folder is a screen or exempt, never both, and v5 folders have no allowlist entry")
    func listsAreConsistent() {
        #expect(Set(Self.screenFolders).isDisjoint(with: Self.exemptFolders))
        #expect(Set(Self.v5Folders).isSubset(of: Self.screenFolders))
        let v5Entries = Self.allowed.keys.filter { key in Self.v5Folders.contains { key.hasPrefix($0 + "/") } }
        #expect(v5Entries.isEmpty, "v5 folders get no allowlist entry: \(v5Entries)")
    }

    /// One line can match several patterns (a shape inside `.background(` is a background and a shape), so a must-fail case
    /// checks `>= 1`, not an exact count.
    @Test("the V5-R8 patterns catch a screen that paints itself")
    func paintPatterns() {
        #expect(Self.violations(in: "x.background(Color.red)") >= 1)
        #expect(Self.violations(in: "x.background(.red)") >= 1)
        #expect(Self.violations(in: "x.background(.regularMaterial)") == 1)
        #expect(Self.violations(in: "x.background(RoundedRectangle(cornerRadius: Metrics.groupRadius).fill(tone))") >= 1)
        #expect(Self.violations(in: "x.background {") == 1)
        #expect(Self.violations(in: "x.background(model.ground)") == 0)
        #expect(Self.violations(in: "x.border(tone, width: 1)") == 1)
        #expect(Self.violations(in: "x.shadow(radius: 4)") == 1)
        #expect(Self.violations(in: "x.overlay(Circle().stroke(tone))") >= 1)
        #expect(Self.violations(in: "x.overlay(RoundedRectangle(cornerRadius: Metrics.row).strokeBorder(tone))") >= 1)
        #expect(Self.violations(in: "x.overlay(alignment: .top) { Hairline() }") == 0)
        #expect(Self.violations(in: "let g = LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)") == 1)
        #expect(Self.violations(in: "RadialGradient(") == 1)
        #expect(Self.violations(in: "withAnimation(.linear.repeatForever()) { on = true }") == 1)
        #expect(Self.violations(in: "// .shadow(radius: 4) in a comment") == 0)
        // One-line trailing closures: the first `)` of the call must not hide the shape.
        #expect(Self.violations(in: "x.overlay(alignment: .top) { Rectangle().stroke(tone) }") >= 1)
        #expect(Self.violations(in: "x.background(alignment: .leading) { Capsule().fill(.secondary) }") >= 1)
        // A closure that spans lines: each line is judged alone, so the shape line fails.
        #expect(Self.violations(in: "x.overlay(alignment: .trailing) {\n    Circle().strokeBorder(tone)\n}") >= 1)
        #expect(Self.violations(in: "x.background {\n    Color.clear\n}") >= 1)
        #expect(Self.violations(in: "x.clipShape(shape)") == 1)
        // A hit area is not a drawing.
        #expect(Self.violations(in: "x.contentShape(Rectangle())") == 0)
    }

    @Test("the patterns catch what they name and skip comments")
    func patterns() {
        #expect(Self.violations(in: #"Text("a").font(.system(size: 13))"#) == 2)
        #expect(Self.violations(in: "x.foregroundStyle(Palette.text)") == 1)
        #expect(Self.violations(in: "x.padding(.horizontal, 10)") == 1)
        #expect(Self.violations(in: "x.padding(.horizontal, Metrics.pagePadding)") == 0)
        #expect(Self.violations(in: "HStack(spacing: 8) {") == 1)
        #expect(Self.violations(in: "HStack(spacing: Space.s8) {") == 0)
        #expect(Self.violations(in: "VStack(spacing: 0) {") == 0)
        #expect(Self.violations(in: "x.frame(width: 58, alignment: .trailing)") == 1)
        #expect(Self.violations(in: "x.frame(maxWidth: .infinity)") == 0)
        #expect(Self.violations(in: "RoundedRectangle(cornerRadius: 6)") >= 1)
        #expect(Self.violations(in: "// .font(SpaceVibeFont.body) in a comment") == 0)
        #expect(Self.violations(in: "x.spaceVibeText(.caption, tone: .tertiary)") == 0)
    }

    @Test("the DS-R12 patterns catch opacity fractions, tracking, kerning and ideal sizes")
    func designSystemPatterns() {
        #expect(Self.violations(in: "x.opacity(0.42)") == 1)
        #expect(Self.violations(in: "x.opacity(.5)") == 1)
        #expect(Self.violations(in: "x.opacity(isOn ? 1 : 0.55)") == 1)
        #expect(Self.violations(in: "x.opacity(isActive ? 1 : 0)") == 0)
        #expect(Self.violations(in: "x.opacity(0)") == 0)
        #expect(Self.violations(in: "x.opacity(1.0)") == 0)
        #expect(Self.violations(in: "x.opacity(OpacityRole.disabled)") == 0)
        #expect(Self.violations(in: "Text(name).tracking(0.2)") == 1)
        #expect(Self.violations(in: "Text(name).kerning(role.kerning)") == 1)
        #expect(Self.violations(in: "x.frame(idealWidth: 308)") == 1)
        #expect(Self.violations(in: "x.frame(width: SizeRole.hitCell, height: SizeRole.hitCell)") == 0)
    }

    @Test("the RB-F3 patterns catch colours by name, the radius modifier and literals on continuation lines")
    func namedColourPatterns() {
        #expect(Self.violations(in: "x.foregroundStyle(Color.red)") == 1)
        #expect(Self.violations(in: "x.foregroundStyle(.secondary)") == 1)
        #expect(Self.violations(in: "x.tint(.accentColor)") == 1)
        #expect(Self.violations(in: "x.foregroundColor(tone)") == 1)
        #expect(Self.violations(in: "let c = NSColor.systemRed") == 1)
        #expect(Self.violations(in: "x.cornerRadius(6)") == 1)
        #expect(Self.violations(in: "Color.clear.frame(width: TableColumnWidth.glyph)") == 0)
        #expect(Self.violations(in: "x.foregroundStyle(ColorRole.ink2)") == 0)
        #expect(Self.violations(in: #"Text("Color.red")"#) == 0, "a word in a label never counts")
        // A literal on a continuation line is judged with its modifier.
        #expect(Self.violations(in: "x.frame(\n    width: 20,\n    alignment: .leading\n)") == 1)
        #expect(Self.violations(in: "x.padding(\n    .horizontal, 12\n)") == 1)
        #expect(Self.violations(in: "x.frame(\n    width: SizeRole.hitCell\n)") == 0)
        #expect(Self.logicalLines("a(\n b,\n c)\nd()") == ["a( b, c)", "d()"])
    }

    @Test("the RB-F3 new-frame screen patterns catch motion, line spacing, layout arithmetic and figures through typeRole")
    func newFrameScreenPatterns() {
        func count(_ line: String) -> Int { Self.matches(of: Self.newFrameScreenOnly, in: line).count }
        #expect(count("x.offset(x: 3)") == 1)
        #expect(count("x.scaleEffect(MotionRole.pressScale)") == 1)
        #expect(count("x.blur(radius: 2)") == 1)
        #expect(count("x.rotationEffect(.degrees(90))") == 1)
        #expect(count("Text(a).lineSpacing(4)") == 1)
        #expect(count("x.frame(width: SpaceRole.step12 * 2)") == 1)
        #expect(count("x.padding(4 + SpaceRole.step8)") == 1)
        #expect(count("x.frame(height: FrameRole.toolbarHeight(look) - topInset)") == 1)
        #expect(count("HStack(spacing: SpaceRole.step4 + SpaceRole.step2) {") == 1)
        #expect(count("Text(n).typeRole(.quiet.figures)") == 1)
        #expect(count("x.frame(width: CLIToggleStrip.width(list.clis.count), alignment: .leading)") == 0)
        #expect(count("x.padding(.top, -SpaceRole.step2)") == 0)
        #expect(count("HStack(spacing: SpaceRole.step4) {") == 0)
        #expect(count("FigureText(n, role: .quiet)") == 0)
        #expect(count("SpaceVibeIcon(frame: .x, size: IconSize.control)") == 0, "IconSize is an AR6 token, checked in v5Tokens")
        #expect(Self.matches(of: Self.v5Tokens, in: "SpaceVibeIcon(frame: .x, size: IconSize.control)").count == 1)
    }

    @Test("the RB-F3 block patterns catch every style literal and pass tokens, halves and doubles")
    func componentPatterns() {
        func count(_ line: String) -> Int {
            Self.matches(of: Self.componentLiterals, in: line, transform: Self.blankingHalves).count
        }
        for failing in [
            "x.padding(.horizontal, 10)", "HStack(spacing: 8) {", "x.frame(width: 34, height: SizeRole.hitCell)",
            "x.frame(height: BlockRole.toastMinHeight - 4)", "RoundedRectangle(cornerRadius: 6)", "x.strokeBorder(tone, lineWidth: 1)",
            "StrokeStyle(lineWidth: StrokeRole.hairline, dash: [4, 2])", "x.opacity(0.55)", "x.offset(y: -1)", "x.scaleEffect(0.98)",
            "x.blur(radius: 2)", "x.rotationEffect(.degrees(-135))", "x.shadow(color: tone, radius: 17, y: 6)",
            "static let knob: CGFloat = 16", "let edge: CGFloat = 1.4", "let w = CGFloat(30)", "x.foregroundStyle(Color.red)",
            "x.foregroundStyle(.secondary)", "let c = NSColor.labelColor", "Text(a).font(.body)", "Text(a).fontWeight(.bold)",
            "x.cornerRadius(6)", "Text(a).lineSpacing(2)", "Text(a).tracking(0.2)", "x.frame(\n    width: 20\n)",
        ] {
            #expect(count(failing) >= 1, "\(failing)")
        }
        for passing in [
            "x.padding(.horizontal, SpaceRole.step10)", "HStack(spacing: 0) {", "x.frame(width: SizeRole.hitCell * 2)",
            "x.frame(height: BlockRole.toastMinHeight - 2 * SpaceRole.step8)", "x.padding(.top, discSide / 2 - ringWidth / 2)",
            "x.strokeBorder(tone, lineWidth: StrokeRole.hairline)", "x.opacity(isOn ? 1 : 0)", "x.opacity(OpacityRole.dim)",
            "x.offset(y: -MotionRole.lift(reduceMotion: reduce))", "x.shadow(color: c, radius: ShadowRole.floatRadius, y: ShadowRole.floatY)",
            "static let knob = BlockRole.switchKnob", "Color.clear.frame(width: SizeRole.hitCell)", "Color(nsColor: tone)",
            "x.trim(from: 0, to: 0.25)", "x.lineLimit(2)", #"Text("16 pt")"#,
        ] {
            #expect(count(passing) == 0, "\(passing)")
        }
    }
}

// MARK: - AR6: a new-frame view uses no v5 token

extension StyleBoundaryTests {
    /// Where AR6 applies: every screen folder and `Components/` (new blocks sit beside the v5 ones there, RB-S4).
    static var frameFolders: [String] { screenFolders + ["Components"] }

    /// Folders that hold only new-frame code: no file in them may ever be listed in `v5Files`.
    static let newFrameOnlyFolders = ["Inbox", "Clean"]

    /// The v5 tokens: the types in `Tokens/` that v5 screens style themselves with, `Rhythm` (`Components/PageLayout.swift`),
    /// and the v5 text modifiers. Appearance plumbing (`AppearanceStore`, `ThemeSetting`, `AppearanceChoice`,
    /// `FontSizeChoice`) is not a token. Matched in code with string literals blanked, so a word in a label never counts.
    static let v5Tokens: [(name: String, pattern: String)] = [
        // `IconSize` is v5's icon scale (RB-F3): a new-frame icon takes `SizeRole.Icon` or `FrameGlyph(side:)`.
        ("v5 token type", #"\b(Palette|PaletteValue|ColorValue|TabChipAlpha|Metrics|Space|Rhythm|SpaceVibeType|TextTone|TypeScale|InterFont|IconSize)\b"#),
        ("v5 text modifier", #"\.(spaceVibeText|lineBox)\("#),
        ("v5 colour initializer", #"\bColor\(light:"#),
    ]

    /// In a new-frame screen file the type comes from `TypeRole` only: no weight, design or digit style of its own (RD23 keeps
    /// 600 for sidebar labels, RD6 keeps Rounded for figures).
    ///
    /// RB-F3: no motion or line spacing of its own (`MotionRole` and `TypeRole` belong to blocks), no arithmetic inside a
    /// layout modifier (a computed metric is a token or a block's function), and a figure goes through `FigureText`, never
    /// `.typeRole(<role>.figures)`, which would round no digit (RD51).
    static let newFrameScreenOnly: [(name: String, pattern: String)] = [
        ("font styling", #"\.(fontWeight|fontDesign|fontWidth|monospacedDigit|bold|italic)\("#),
        ("motion or line spacing", #"\.(offset|scaleEffect|blur|rotationEffect|lineSpacing)\("#),
        ("layout arithmetic", #"\.(padding|frame|offset)\((?:[^()]|\([^()]*\))*?(?:[\w\]]|\([^()]*\))\s*(?:[*/+]|-(?!>))\s*[\w(.]"#),
        ("spacing arithmetic", #"spacing:\s*[^,(){}]*?[\w)\]]\s*(?:[*/+]|-(?!>))\s*[\w(.]"#),
        ("figure through typeRole", #"\.typeRole\([^)]*\.figures"#),
    ]

    /// RB-F3: what a new-frame block in `Components/` may not hold either. Blocks compose the design system's tokens; a
    /// number that sizes, spaces, rounds, strokes, fades, moves or shadows something is a token in `Tokens/` (`SizeRole`,
    /// `BlockRole`, `StrokeRole`, `TableColumnWidth`…). Halving and doubling (`/ 2`, `2 *`) are geometry, not values, and
    /// pass. The generated icon data (`*IconData.swift`) is the generator's and is skipped.
    static let componentLiterals: [(name: String, pattern: String)] = {
        let number = #"(?<![\w.])(?:0?\.[0-9]*[1-9][0-9]*|[1-9][0-9]*(?:\.[0-9]+)?)(?![\w.])"#
        // Whole nested calls are stepped over, and the number may sit inside the last one (`.degrees(-135)`).
        let args = #"(?:[^()]|\([^()]*\))*?(?:\([^()]*?)?"#
        return [
            ("system font", #"Font\.system|\.system\(size"#),
            ("raw font", #"\.font\("#),
            ("font styling", #"\.(fontWeight|fontDesign|fontWidth|bold|italic)\("#),
            ("colour literal", #"\bColor\((?!nsColor:)"#),
            ("named colour", #"\bColor\.(?!clear\b)[a-z]\w*"#),
            ("AppKit colour", #"\bNSColor\b"#),
            ("system colour", systemColourPattern),
            ("radius modifier", #"\.cornerRadius\("#),
            ("line spacing", #"\.lineSpacing\("#),
            ("tracking", #"\.(tracking|kerning)\("#),
            ("padding literal", #"\.padding\("# + args + number),
            ("spacing literal", #"spacing:\s*"# + number),
            ("frame literal", #"\.frame\("# + args + #"\b(width|height|minWidth|minHeight|idealWidth|idealHeight|maxWidth|maxHeight):\s*"# + number),
            ("layout arithmetic literal", #"\.(padding|frame|offset)\("# + args + #"[*+\-]\s*"# + number),
            ("radius literal", #"cornerRadius:\s*"# + number),
            ("stroke literal", #"lineWidth:\s*"# + number),
            ("dash literal", #"dash:\s*\[[^\]]*?"# + number),
            ("opacity literal", #"\.opacity\([^)]*?(?<![A-Za-z0-9_.])0?\.[0-9]*[1-9]"#),
            ("motion literal", #"\.(offset|scaleEffect|blur|rotationEffect)\("# + args + number),
            ("shadow literal", #"\.shadow\("# + args + number),
            ("size constant", #":\s*(CGFloat|Double|TimeInterval)\s*=\s*-?"# + number),
            ("CGFloat literal", #"CGFloat\(\s*-?"# + number + #"\s*\)"#),
        ]
    }()

    /// Halving and doubling are geometry: blanked before `componentLiterals` run.
    static func blankingHalves(_ code: String) -> String {
        code.replacingOccurrences(of: #"(/\s*2|\b2\s*\*|\*\s*2)(?![\w.])"#, with: " ", options: .regularExpression)
    }

    /// True unless the file is in the frozen `v5Files` list.
    static func isNewFrame(folder: String, file: String) -> Bool {
        !(v5Files[folder]?.contains((file as NSString).deletingPathExtension) ?? false)
    }

    /// Matches of `patterns` in code, over its logical lines (`logicalLines`: literals blanked, comments dropped,
    /// continuation lines joined). `transform` rewrites each line first (`blankingHalves` for blocks).
    static func matches(of patterns: [(name: String, pattern: String)], in source: String,
                        transform: (String) -> String = { $0 }) -> [String] {
        let expressions = patterns.map { ($0.name, try! NSRegularExpression(pattern: $0.pattern)) }
        var found: [String] = []
        for line in logicalLines(source) {
            let code = transform(line)
            let range = NSRange(code.startIndex..., in: code)
            for (name, expression) in expressions {
                for match in expression.matches(in: code, range: range) {
                    found.append("\(name) `\((code as NSString).substring(with: match.range))`")
                }
            }
        }
        return found
    }

    @Test("a new-frame file uses no v5 token (AR6)")
    func newFrameFilesUseNoV5Token() throws {
        var problems: [String] = []
        for folder in Self.frameFolders {
            let directory = Self.appSources.appendingPathComponent(folder)
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { continue }
            for name in names.sorted() where name.hasSuffix(".swift") && Self.isNewFrame(folder: folder, file: name) {
                let source = try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
                let patterns = Self.v5Tokens + (folder == "Components" ? [] : Self.newFrameScreenOnly)
                let uses = Self.matches(of: patterns, in: source)
                if !uses.isEmpty {
                    problems.append("\(folder)/\(name) is a new-frame file (not in the frozen v5Files) and uses "
                        + "\(uses.joined(separator: ", ")). Use ColorRole, TypeRole, SpaceRole, RadiusRole, SizeRole, OpacityRole, "
                        + "ShadowRole or MotionRole instead (AR6).")
                }
            }
        }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test("a new-frame block holds no style literal (RB-F3)")
    func newFrameComponentsHoldNoLiterals() throws {
        let directory = Self.appSources.appendingPathComponent("Components")
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(names.contains("PushButtonStyle.swift"), "found no block sources under \(directory.path)")
        var problems: [String] = []
        for name in names where name.hasSuffix(".swift") && !name.hasSuffix("IconData.swift")
            && Self.isNewFrame(folder: "Components", file: name) {
            let source = try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
            let uses = Self.matches(of: Self.componentLiterals, in: source, transform: Self.blankingHalves)
            if !uses.isEmpty {
                problems.append("Components/\(name) is a new-frame block and holds \(uses.joined(separator: ", ")). Name the value in "
                    + "Tokens/ (SizeRole, BlockRole, StrokeRole, TableColumnWidth…) and use the name.")
            }
        }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test("every file in the frozen v5 list still exists, and none sits in a new-frame-only folder")
    func v5FilesExist() {
        var problems: [String] = []
        for (folder, files) in Self.v5Files.sorted(by: { $0.key < $1.key }) {
            if !Self.frameFolders.contains(folder) { problems.append("v5Files lists \(folder), which is not a screen folder or Components") }
            if Self.newFrameOnlyFolders.contains(folder) { problems.append("v5Files lists \(folder), which holds new-frame code only") }
            for file in files.sorted() {
                let path = Self.appSources.appendingPathComponent("\(folder)/\(file).swift").path
                if !FileManager.default.fileExists(atPath: path) {
                    problems.append("\(folder)/\(file).swift is gone: remove it from v5Files (the list only shrinks)")
                }
            }
        }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
        #expect(Set(Self.newFrameOnlyFolders).isSubset(of: Self.screenFolders))
    }

    @Test("the classifier: listed files are v5, every other file is new-frame")
    func classifierSelfTest() {
        #expect(!Self.isNewFrame(folder: "Skills", file: "SkillsList.swift"))
        #expect(!Self.isNewFrame(folder: "Components", file: "ListRow.swift"))
        #expect(Self.isNewFrame(folder: "Skills", file: "SkillsInspector.swift"))
        #expect(Self.isNewFrame(folder: "Shell", file: "AppFrame.swift"))
        #expect(Self.isNewFrame(folder: "Inbox", file: "InboxList.swift"))
        #expect(Self.isNewFrame(folder: "Components", file: "MiddleTruncatedText.swift"))
    }

    @Test("the AR6 patterns catch v5 tokens and skip new tokens, labels and comments")
    func v5TokenPatterns() {
        func count(_ line: String, screen: Bool = true) -> Int {
            Self.matches(of: Self.v5Tokens + (screen ? Self.newFrameScreenOnly : []), in: line).count
        }
        #expect(count("x.foregroundStyle(Palette.fg)") == 1)
        #expect(count("VStack(spacing: Space.s8) {") == 1)
        #expect(count("x.padding(Rhythm.edge)") == 1)
        #expect(count("x.frame(width: Metrics.iconControl)") == 1)
        #expect(count("Text(name).spaceVibeText(.rowName, tone: .primary)") == 1)
        #expect(count("let role: SpaceVibeType = .body") == 1)
        #expect(count("x.background(Color(light: 0xFFFFFF, dark: 0x000000))") == 1)
        #expect(count("Text(count).fontWeight(.semibold)") == 1)
        #expect(count("Text(count).fontWeight(.semibold)", screen: false) == 0)
        #expect(count(#"Text("Open Palette").typeRole(.bodyText)"#) == 0)
        #expect(count("x.foregroundStyle(ColorRole.ink).padding(SpaceRole.step8)") == 0)
        #expect(count("let search = PaletteSearch(query)") == 0)
        #expect(count("// Palette.fg was the v5 ink") == 0)
        #expect(count("x.frame(height: SizeRole.tableRow) // not Metrics.ListRow") == 0)
    }

    /// Every screen and component file that existed when the redesign build started (2026-11-21, `main` at 35ffb9d), without
    /// `.swift`. These keep the v5 tokens until RB-X1 deletes them. Frozen: a new file is never added here.
    static let v5Files: [String: Set<String>] = [
        "Activity": [
            "ActivityAnswers", "ActivityCanvas", "ActivityCards", "ActivityFormat", "ActivityModel", "ActivityQuery",
            "ActivityStopConfirmation", "ActivityTab", "ActivityTabShots",
        ],
        "Agents": [
            "AgentsCategory", "AgentsCounts", "AgentsPage", "LoadoutFormat", "LoadoutModel", "LoadoutRow", "LoadoutRows",
            "PickFilter",
        ],
        "Components": [
            "ActionButtonStyle", "AnswerCard", "Band", "BlockSurface", "BulkBar", "CategoryIconData", "Cells", "CLIMark",
            "CLIStyle", "ConfirmationDialog", "ContentIconData", "DetailPane", "EmptyState", "FilterChip", "FocusFill",
            "GlanceCountdownParts", "GlanceDropSlots", "GlanceListParts", "GlanceStripParts", "KeyCap", "ListPaneLayout",
            "ListRow", "LogoToggle", "MenuNavigator", "OverlayHost", "PageKeys", "PageLayout", "PaletteParts",
            "PointerCursor", "PopoverSurface", "RailTab", "SegmentedControl", "SessionStateGlyph", "ShotRendering",
            "SidebarBlocks", "SpaceVibeIcon", "SpaceVibeMark", "SpaceVibeSwitch", "SpecimenInteraction", "SplitCanvas",
            "StateIconData", "StateMark", "StatFigures", "StatusBar", "TabChips", "ThemeTile", "Tile", "Toast",
            "ToolbarMenu", "VerdictGlyph", "WarningSlot",
        ],
        "Glance": [
            "GlanceClickRoute", "GlanceController", "GlanceCountdown", "GlanceDrag", "GlanceEntries", "GlanceFeed",
            "GlanceLimitsFeed", "GlancePanel", "GlancePreferences", "GlanceShots", "GlanceSlots", "GlanceStrip",
            "GlanceViews", "GlanceWording", "HostAppResolver",
        ],
        "Hooks": ["HooksModel", "HooksQuery", "HooksShots", "HooksSynthetic", "HooksTab", "HooksWording"],
        "Limits": [
            "LimitsAnswer", "LimitsCanvas", "LimitsCountdown", "LimitsCountdownPreferences", "LimitsModel", "LimitsShots",
            "LimitsWording",
        ],
        "Rules": [
            "CodexWording", "RuleFamilies", "RulesCanvas", "RulesModel", "RulesPage", "RulesScopes", "RulesSnapshot",
            "RulesSynthetic", "RulesTabShots", "RulesWording",
        ],
        "Settings": [
            "AppearanceSettings", "GlanceSettings", "LimitsSettings", "SettingsScreen", "SettingsShots", "SettingsWording",
            "UpdateSettings",
        ],
        "Shell": [
            "AppCommandPalette", "AppShell", "AppSidebar", "CLIStatusDerivation", "PaletteSearch", "ShellCommands",
            "ShellModel", "ShellShots", "SpaceVibeTab", "TabRegistry", "ThemeToggle", "ToastCenter", "ToastHost",
        ],
        "Skills": ["SkillsList", "SkillsModel", "SkillsPane", "SkillsQuery", "SkillsShots", "SkillsTab", "SkillsWording"],
        "Subagents": ["SubagentsModel", "SubagentsQuery", "SubagentsShots", "SubagentsTab", "SubagentsWording"],
    ]
}
