import AppKit
import SwiftUI
import Testing
@testable import SpaceVibe

/// The Hooks lifecycle strip's break-ui fixes (RB-F3): names that do not fit fade out at the trailing edge instead of being
/// cut mid-glyph, and a count of 100 or more grows its disc instead of spilling out of it.
@Suite("Lifecycle strip")
@MainActor
struct LifecycleStripTests {
    /// Every Claude Code event: far wider than the strip beside the hero at 1000 pt.
    static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse",
                         "PostToolUseFailure", "Notification", "SubagentStart", "SubagentStop", "PreCompact", "Stop", "SessionEnd"]

    @Test("a strip whose names do not fit fades to nothing at its trailing edge; one that fits is not faded")
    func trailingFade() throws {
        let wide = Self.events.map { LifecycleNode(event: $0, count: 3, mark: .plain) }
        let cut = try pixels(LifecycleStrip(nodes: wide, chosen: nil) { _ in }, width: 400)
        // The line through the nodes runs to the edge when the row overflows: at the last column it is faded out.
        #expect(maxAlpha(cut, column: cut.pixelsWide - 1) < 0.05, "the trailing column is faded out")
        #expect(maxAlpha(cut, column: cut.pixelsWide / 2) > 0.3, "the middle is drawn")

        let fits = Self.events.prefix(2).map { LifecycleNode(event: $0, count: 3, mark: .plain) }
        let whole = try pixels(LifecycleStrip(nodes: Array(fits), chosen: nil) { _ in }, width: 400)
        let lastName = (whole.pixelsWide * 3 / 4)
        #expect(maxAlpha(whole, column: lastName) > 0.3, "a strip that fits keeps its last node unfaded")
    }

    @Test("the trailing fade is only on when the row runs past the strip")
    func overflowRule() {
        #expect(LifecycleStrip.overflows(lineWidth: 900, room: 600))
        #expect(!LifecycleStrip.overflows(lineWidth: 600, room: 600))
        #expect(!LifecycleStrip.overflows(lineWidth: 600.4, room: 600))
        #expect(!LifecycleStrip.overflows(lineWidth: 900, room: 0), "not measured yet")
    }

    @Test("from 100 Hooks the disc grows around the whole count; up to 99 it stays the 22 pt disc")
    func threeDigitCounts() throws {
        #expect(!LifecycleNode(event: "Stop", count: 99, mark: .plain).growsDisc)
        #expect(LifecycleNode(event: "Stop", count: 100, mark: .plain).growsDisc)
        #expect(LifecycleNode(event: "Stop", count: 1_006, mark: .critical).growsDisc)
        // Drawn: the ring of a 1,006 node spans wider than the 22 pt disc of a 9 node.
        let small = try pixels(LifecycleStrip(nodes: [LifecycleNode(event: "Stop", count: 9, mark: .critical)], chosen: nil) { _ in }, width: 200)
        let large = try pixels(LifecycleStrip(nodes: [LifecycleNode(event: "Stop", count: 1_006, mark: .critical)], chosen: nil) { _ in }, width: 200)
        #expect(ringSpan(large) > ringSpan(small) + 8, "the 1,006 disc is wider than the 9 disc")
    }

    private func pixels<V: View>(_ view: V, width: CGFloat) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view.frame(width: width)
            .environment(\.colorScheme, .light)
            .environment(\.isShotRendering, true))
        renderer.scale = 1
        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    private func maxAlpha(_ image: NSBitmapImageRep, column: Int) -> CGFloat {
        (0..<image.pixelsHigh).map { image.colorAt(x: column, y: $0)?.alphaComponent ?? 0 }.max() ?? 0
    }

    /// How wide the disc row is drawn: the columns with a pixel on the disc's middle line.
    private func ringSpan(_ image: NSBitmapImageRep) -> Int {
        // The disc's centre line: 2 pt padding plus half the 22 pt disc.
        let y = 13
        let drawn = (0..<image.pixelsWide).filter { (image.colorAt(x: $0, y: y)?.alphaComponent ?? 0) > 0.3 }
        guard let first = drawn.first, let last = drawn.last else { return 0 }
        return last - first
    }
}
