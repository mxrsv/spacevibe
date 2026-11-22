import Foundation
import Testing

/// Two source rules of the new frame that neither a unit test nor a headless shot can see (RB-F1, the owner's look of
/// 2026-11-22). Read from source text, as `StyleBoundaryTests` does, with string literals and comments blanked.
///
/// 1. Focus (RD29): a block draws the focus bar for its own focus only. `@Environment(\.isFocused)` reports the nearest
///    focusable ancestor, which in the frame is the content area, a list, the overlay inspector or a dialog, so a block that
///    read it lit with its whole region. Only `PushButtonStyle` may still read it, gated by keyboard navigation
///    (`FocusBarRule.buttonOwnsFocus`); every other new-frame block binds an own `@FocusState`. v5 files are left as they are.
/// 2. Shots: a screen scrolls in `SpaceVibeScrollView`, never a bare `ScrollView`, which `ImageRenderer` draws blank (the
///    Limits and Journal shots of the 2026-11-22 review).
@Suite("Frame policy: own focus, drawable scroll views")
struct FramePolicyTests {
    static let ancestorFocus: [(name: String, pattern: String)] = [("ancestor focus", #"@Environment\(\\\.isFocused\)"#)]
    /// The one block that keeps it, behind the keyboard-navigation gate.
    static let ancestorFocusAllowed: Set<String> = ["Components/PushButtonStyle.swift"]

    static let bareScrollView: [(name: String, pattern: String)] = [("bare ScrollView", #"(?<![A-Za-z])ScrollView\s*(\{|\()"#)]

    private static func newFrameSources(in folders: [String]) -> [(path: String, text: String)] {
        folders.flatMap { folder -> [(path: String, text: String)] in
            let directory = StyleBoundaryTests.appSources.appendingPathComponent(folder)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            return names.sorted().filter { $0.hasSuffix(".swift") && StyleBoundaryTests.isNewFrame(folder: folder, file: $0) }.compactMap { name in
                guard let text = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else { return nil }
                return ("\(folder)/\(name)", text)
            }
        }
    }

    @Test("no new-frame block reads the ancestor's focus for its bar, except PushButtonStyle behind its gate")
    func ownFocusOnly() {
        let sources = Self.newFrameSources(in: StyleBoundaryTests.frameFolders)
        #expect(!sources.isEmpty)
        var offenders: [String] = []
        for source in sources where !Self.ancestorFocusAllowed.contains(source.path) {
            let found = StyleBoundaryTests.matches(of: Self.ancestorFocus, in: source.text)
            if !found.isEmpty { offenders.append(source.path) }
        }
        #expect(offenders.isEmpty, "read an own @FocusState instead: \(offenders)")
        let push = sources.first { $0.path == "Components/PushButtonStyle.swift" }
        #expect(push?.text.contains("FocusBarRule.buttonOwnsFocus") == true, "PushButtonStyle trusts it only with keyboard navigation on")
    }

    @Test("no screen scrolls in a bare ScrollView, which a headless shot draws blank")
    func drawableScrollViews() {
        let sources = Self.newFrameSources(in: StyleBoundaryTests.screenFolders)
        let offenders = sources.filter { !StyleBoundaryTests.matches(of: Self.bareScrollView, in: $0.text).isEmpty }.map(\.path)
        #expect(offenders.isEmpty, "use SpaceVibeScrollView: \(offenders)")
    }

    @Test("the patterns catch what they name and skip comments, strings and SpaceVibeScrollView")
    func patterns() {
        #expect(StyleBoundaryTests.matches(of: Self.ancestorFocus, in: "    @Environment(\\.isFocused) private var isFocused").count == 1)
        #expect(StyleBoundaryTests.matches(of: Self.ancestorFocus, in: "    // @Environment(\\.isFocused) is the ancestor's").isEmpty)
        #expect(StyleBoundaryTests.matches(of: Self.bareScrollView, in: "        ScrollView(.vertical) {").count == 1)
        #expect(StyleBoundaryTests.matches(of: Self.bareScrollView, in: "        ScrollView {").count == 1)
        #expect(StyleBoundaryTests.matches(of: Self.bareScrollView, in: "        SpaceVibeScrollView {").isEmpty)
        #expect(StyleBoundaryTests.matches(of: Self.bareScrollView, in: "        Text(\"ScrollView {\")").isEmpty)
    }
}
