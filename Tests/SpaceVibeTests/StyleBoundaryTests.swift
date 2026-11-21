import Foundation
import Testing

/// Screens compose base components; they never style themselves (spec `docs/specs/2026-11-03-reins-design-language.md`,
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
    ]

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

    /// Forbidden matches in one file. Whole-line comments are skipped; a trailing comment is skipped when the line has no
    /// string literal (so `//` inside a string never hides code).
    static func violations(in source: String) -> Int {
        let expressions = forbidden.map { try! NSRegularExpression(pattern: $0.pattern) }
        var count = 0
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            var code = line
            if !line.contains("\""), let comment = line.range(of: "//") { code = String(line[..<comment.lowerBound]) }
            let range = NSRange(code.startIndex..., in: code)
            for expression in expressions { count += expression.numberOfMatches(in: code, range: range) }
        }
        return count
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
        #expect(Self.violations(in: "x.background(Color.red)") == 1)
        #expect(Self.violations(in: "x.background(.red)") == 1)
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
        ("v5 token type", #"\b(Palette|PaletteValue|ColorValue|TabChipAlpha|Metrics|Space|Rhythm|SpaceVibeType|TextTone|TypeScale|InterFont)\b"#),
        ("v5 text modifier", #"\.(spaceVibeText|lineBox)\("#),
        ("v5 colour initializer", #"\bColor\(light:"#),
    ]

    /// In a new-frame screen file the type comes from `TypeRole` only: no weight, design or digit style of its own (RD23 keeps
    /// 600 for sidebar labels, RD6 keeps Rounded for figures).
    static let newFrameScreenOnly: [(name: String, pattern: String)] = [
        ("font styling", #"\.(fontWeight|fontDesign|fontWidth|monospacedDigit|bold|italic)\("#),
    ]

    /// True unless the file is in the frozen `v5Files` list.
    static func isNewFrame(folder: String, file: String) -> Bool {
        !(v5Files[folder]?.contains((file as NSString).deletingPathExtension) ?? false)
    }

    /// Matches of `patterns` in code: string literals blanked first (an interpolation inside one is blanked with it), then
    /// whole-line and trailing comments skipped.
    static func matches(of patterns: [(name: String, pattern: String)], in source: String) -> [String] {
        let expressions = patterns.map { ($0.name, try! NSRegularExpression(pattern: $0.pattern)) }
        let literal = try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#)
        var found: [String] = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            let blanked = literal.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: #""""#)
            var code = blanked
            if let comment = blanked.range(of: "//") { code = String(blanked[..<comment.lowerBound]) }
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
