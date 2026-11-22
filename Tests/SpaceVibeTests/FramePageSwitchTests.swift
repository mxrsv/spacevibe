import AppKit
import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// RB-F4, page switching holds still: every frame region keeps its place when the page changes, the first render of a new
/// page already has that page's inspector, and the traffic lights sit where the mock draws them.
@Suite("Frame page switching")
@MainActor
struct FramePageSwitchTests {
    private static let widths: [CGFloat] = [1000, 1280, 1600]

    /// The layout of every page as the frame draws it after the page settled.
    private static func settled(_ page: FramePage, look: MaterialLook, width: CGFloat, sidebarHidden: Bool) -> FrameRegionLayout {
        let chrome = FrameChrome(page: page)
        chrome.setWindowWidth(width)
        chrome.isSidebarHidden = sidebarHidden
        chrome.pageHasInspector = page.hasInspector
        return chrome.layout(on: page, hasInspector: page.hasInspector, look: look)
    }

    @Test("the sidebar, the toolbar's leading group and the content's top-left are the same on every page")
    func sharedChromeHoldsStill() {
        for look in [MaterialLook.glass, .solid] {
            for width in Self.widths {
                for hidden in [false, true] {
                    let layouts = FramePage.allCases.map { Self.settled($0, look: look, width: width, sidebarHidden: hidden) }
                    #expect(Set(layouts.map(\.sidebarWidth)).count == 1, "sidebar, \(look) \(width)")
                    #expect(Set(layouts.map(\.toolbarLeading)).count == 1, "toolbar leading group, \(look) \(width)")
                    #expect(Set(layouts.map { [$0.contentInsets.top, $0.contentInsets.leading] }).count == 1,
                            "content top-left (hero, first group head), \(look) \(width)")
                }
            }
        }
    }

    @Test("only the inspector's own column differs by page: 336 on Skills, Subagents and Inbox, 308 elsewhere, none on Clean and Limits (DS2)")
    func inspectorColumnPerPage() {
        for look in [MaterialLook.glass, .solid] {
            for width in Self.widths {
                for page in FramePage.allCases {
                    let layout = Self.settled(page, look: look, width: width, sidebarHidden: false)
                    let docked = layout.presentation == .docked ? layout.inspectorWidth : 0
                    #expect(layout.mainColumnWidth + docked + layout.sidebarWidth == width, "\(page) \(look) \(width)")
                    switch (page.hasInspector, width >= SpaceRole.inspectorOverlayBelowWindowWidth) {
                    case (false, _): #expect(layout.presentation == .hidden && layout.inspectorWidth == 0, "\(page)")
                    case (true, false): #expect(layout.presentation == .hidden, "below 1100 the inspector starts closed, \(page)")
                    case (true, true):
                        #expect(layout.presentation == .docked, "\(page)")
                        #expect(layout.inspectorWidth == ([.skills, .subagents, .inbox].contains(page) ? 336 : 308), "\(page)")
                    }
                }
            }
        }
    }

    @Test("the first render of a page already has that page's inspector, not the page before's")
    func firstRenderAfterPageChange() {
        // Clean was shown, so the chrome still says the page has no inspector when Skills renders for the first time.
        let chrome = FrameChrome(page: .clean)
        chrome.setWindowWidth(1280)
        chrome.pageHasInspector = false
        let first = chrome.layout(on: .skills, hasInspector: true, look: .glass)
        let settled = Self.settled(.skills, look: .glass, width: 1280, sidebarHidden: false)
        #expect(first == settled, "the list is not drawn full width for one render and then narrowed by the inspector")
        // A region measuring its columns in that render (Inbox evidence, Hooks status, Activity columns).
        let inspector = FramePage.inbox.inspectorWidth.points
        let stale = chrome.listWidth(sidebar: FrameRole.sidebarWidth(.glass), inspector: inspector)
        chrome.pageHasInspector = true
        #expect(stale == chrome.listWidth(sidebar: FrameRole.sidebarWidth(.glass), inspector: inspector))
        // And the other way: from Skills to Clean, Clean's list is never narrowed by the inspector Skills had.
        let back = chrome.layout(on: .clean, hasInspector: false, look: .glass)
        #expect(back == Self.settled(.clean, look: .glass, width: 1280, sidebarHidden: false))
    }

    @Test("an overlay inspector opened on one page is never drawn on the next one, not even before the page change closes it")
    func overlayStaysOnItsPage() {
        let chrome = FrameChrome(page: .skills)
        chrome.setWindowWidth(1000)
        chrome.pageHasInspector = true
        chrome.openInspector()
        #expect(chrome.layout(on: .skills, hasInspector: true, look: .glass).presentation == .overlay)
        #expect(chrome.layout(on: .hooks, hasInspector: true, look: .glass).presentation == .hidden)
        chrome.pageChanged(to: .hooks)
        #expect(chrome.presentation == .hidden && chrome.shownPage == .hooks)
        chrome.toggleInspector()
        #expect(chrome.layout(on: .hooks, hasInspector: true, look: .glass).presentation == .overlay)
    }

    // MARK: The window's top-left (the mock's `.lights`)

    @Test("the traffic lights' first centre is the mock's: 34 from the window's left and top in Glass, 26 in Solid")
    func trafficLightPlacement() {
        let size = CGSize(width: 14, height: 14)
        let glass = FrameWindowButtonsPlacement.make(look: .glass, buttonSize: size, pitch: 23)
        #expect(glass.titlebarHeight == 68)
        #expect(glass.origins == [CGPoint(x: 27, y: 27), CGPoint(x: 50, y: 27), CGPoint(x: 73, y: 27)])
        // `.sb{margin:8px;padding:0 8px}` + `.lights{height:52px;padding:0 12px}` + half a 12 pt dot.
        #expect(FrameRole.trafficLightCenter(.glass) == RadiusRole.sidebarInset(.glass) + FrameRole.trafficLightClearance / 2)
        let solid = FrameWindowButtonsPlacement.make(look: .solid, buttonSize: size, pitch: 23)
        #expect(solid.titlebarHeight == 52 && solid.origins.first == CGPoint(x: 19, y: 19))
        for (look, placement) in [(MaterialLook.glass, glass), (.solid, solid)] {
            // With the sidebar hidden the toolbar starts at least 12 pt after the last light.
            #expect(placement.trailingEdge(buttonWidth: size.width) + SpaceRole.step12 <= FrameRole.trafficLightsWidth(look))
            // The lights sit inside the sidebar's light strip, clear of its rounded corner.
            #expect(placement.origins[0].y >= RadiusRole.sidebarInset(look))
        }
    }

    @Test("the real buttons of a window (never shown) move there and stay there through a resize")
    func windowButtonsFollowTheMock() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        let anchor = FrameWindowButtonsView()
        anchor.look = .glass
        window.contentView?.addSubview(anchor)
        let topLeft = { () -> CGPoint in
            let close = window.standardWindowButton(.closeButton)!
            let frame = close.convert(close.bounds, to: nil)
            return CGPoint(x: frame.minX, y: window.frame.height - frame.maxY)
        }
        #expect(topLeft() == CGPoint(x: 27, y: 27))
        window.setContentSize(NSSize(width: 1000, height: 700))
        window.layoutIfNeeded()
        // AppKit lays the title bar out again after the resize; the view's second pass runs on the next turn of the loop.
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        #expect(topLeft() == CGPoint(x: 27, y: 27), "AppKit's own relayout after a resize is undone")
        anchor.look = .solid
        #expect(topLeft() == CGPoint(x: 19, y: 19))
        anchor.removeFromSuperview()
    }
}
