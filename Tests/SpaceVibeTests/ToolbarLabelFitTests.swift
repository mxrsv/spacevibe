import AppKit
import SwiftUI
import Testing
@testable import SpaceVibe

/// RD52: the toolbar's primary or destructive label is short enough never to be cut in its 196 slot, at worst-case counts,
/// on the pages of group PAGES-A (Activity's Stop, Hooks' and Rules' Remove). Measured as drawn: the button at its ideal width.
@Suite("Toolbar labels fit the slot")
@MainActor
struct ToolbarLabelFitTests {
    @Test("Stop and Remove at four-digit counts fit the 196 pt slot", arguments: [1_006, 99_999])
    func fits(count: Int) throws {
        let ticked = (0..<count).map { "claude:s\($0)" }
        let stop = try #require(stopTitle(ticked: ticked))
        let labels: [(String, FrameIcon)] = [
            (stop, .stopCircle),
            (HooksFrame.removeSelectedTitle(count), .trash),
            (RulesFrame.removeSelectedTitle(count), .trash),
        ]
        for (title, icon) in labels {
            let width = try idealWidth(title, icon: icon)
            #expect(width <= FrameRole.toolbarSlotWidth, "\(title) is \(width) pt wide")
        }
    }

    @Test("the whole sentence moves to the tooltip and VoiceOver")
    func help() {
        #expect(HooksFrame.removeSelectedHelp(104) == "Remove 104 selected Hooks" && HooksFrame.removeSelectedHelp(1) == "Remove 1 selected Hook")
        #expect(RulesFrame.removeSelectedHelp(1_006) == "Remove 1,006 selected rules")
        #expect(RulesFrame.removeSelectedTitle(1_006) == "Remove 1,006" && HooksFrame.removeSelectedTitle(104) == "Remove 104")
    }

    /// Activity's `primaryTitle` with `ticked` sessions running.
    private func stopTitle(ticked: [String]) -> String? {
        let sessions = ticked.map { id in
            var session = FrameTestData.session(String(id.dropFirst("claude:".count)), cli: .claude, state: .running)
            session.pid = 100
            return session
        }
        var snapshot = FrameTestData.snapshot(FrameTestData.loadout())
        snapshot.activity = CoreActivityReport(sessions: sessions, failures: [], files: [], unmeasurable: [],
                                               stats: CoreActivityStats(logs: 1, truncated: 0))
        let world = FrameWorld(snapshot: snapshot, now: FrameTestData.now)
        var input = ActivityPageInput(clis: world.clis, sessions: world.sessions, failures: [], hasReport: true, source: .ready,
                                      figure: world.figure(for: .activity, loading: [], failed: []), now: FrameTestData.now,
                                      calendar: Calendar(identifier: .gregorian))
        input.ticked = Set(ticked)
        let data = ActivityPageData(input)
        #expect(data.picks.count == ticked.count, "every ticked session is stoppable")
        return data.primaryTitle
    }

    private func idealWidth(_ title: String, icon: FrameIcon) throws -> CGFloat {
        let button = Button {} label: { PushButtonLabel(title, icon: icon).lineLimit(1) }
            .buttonStyle(PushButtonStyle(.destructive))
            .fixedSize()
        let renderer = ImageRenderer(content: button.environment(\.isShotRendering, true))
        renderer.scale = 1
        return CGFloat(try #require(renderer.cgImage).width)
    }
}
