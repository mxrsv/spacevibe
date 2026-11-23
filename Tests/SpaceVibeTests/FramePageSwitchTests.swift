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

    @Test("the toolbar's trailing group (search, inspector button, 196 slot) has one frame on all 8 pages, at the window's right edge (RD57)")
    func trailingGroupHoldsStill() {
        for look in [MaterialLook.glass, .solid] {
            for width in Self.widths {
                for hidden in [false, true] {
                    let groups = FramePage.allCases.map { page in
                        let frame = Self.settled(page, look: look, width: width, sidebarHidden: hidden).toolbarTrailingGroup
                        return [frame.minX, frame.minY, frame.width, frame.height]
                    }
                    #expect(Set(groups).count == 1, "\(look) \(width) sidebar hidden \(hidden): \(groups)")
                    let frame = Self.settled(.clean, look: look, width: width, sidebarHidden: hidden).toolbarTrailingGroup
                    #expect(frame.maxX == width - SpaceRole.step12, "pinned to the window's right edge, \(look) \(width)")
                }
            }
        }
        // Opening the overlay below 1100 pt or hiding the docked inspector moves nothing either.
        for (width, look) in [(CGFloat(1000), MaterialLook.solid), (1280, .glass)] {
            let chrome = FrameChrome(page: .skills)
            chrome.setWindowWidth(width)
            chrome.pageHasInspector = true
            let before = chrome.layout(on: .skills, hasInspector: true, look: look).toolbarTrailingGroup
            chrome.toggleInspector()
            let after = chrome.layout(on: .skills, hasInspector: true, look: look)
            #expect(after.presentation != Self.settled(.skills, look: look, width: width, sidebarHidden: false).presentation)
            #expect(after.toolbarTrailingGroup == before, "\(width)")
        }
    }

    @Test("the toolbar runs from the sidebar to the window's right edge on every page, and the search folds by window, not by page (RD57)")
    func toolbarSpansTheWindow() {
        for look in [MaterialLook.glass, .solid] {
            for width in Self.widths {
                for page in FramePage.allCases {
                    let layout = Self.settled(page, look: look, width: width, sidebarHidden: false)
                    #expect(layout.toolbarWidth == width - layout.sidebarWidth, "\(page) \(look) \(width)")
                    #expect(layout.searchFolds == (width < 1100), "\(page) \(look) \(width)")
                }
            }
        }
    }

    @Test("the trailing group as drawn is as wide as the layout says, with or without search, inspector and button")
    func trailingGroupDrawnWidth() throws {
        let search = FrameSearch()
        for folds in [false, true] {
            let expected = FrameRole.toolbarTrailingGroupWidth(searchFolds: folds)
            for hasSearch in [false, true] {
                for hasInspector in [false, true] {
                    for primary in [nil, AnyView(Button("Remove 104") {}.buttonStyle(PushButtonStyle(.destructive)))] {
                        let group = FrameToolbarTrailingGroup(searchItems: hasSearch ? "skills" : nil, search: search, searchFolds: folds,
                                                              hasInspector: hasInspector, isInspectorShown: hasInspector,
                                                              pageTitle: "Clean", primary: primary) {}
                        let size = try Self.drawnSize(group.fixedSize())
                        #expect(size.width == expected, "folds \(folds) search \(hasSearch) inspector \(hasInspector) primary \(primary != nil)")
                    }
                }
            }
        }
    }

    // MARK: The hero (RD58)

    @Test("Clean's hero stays at the header's top at 1000 pt, where the note beside it wraps, as at 1280 and 1600 (RD58)")
    func cleanHeroHoldsAtNarrowWidth() throws {
        let page = CleanPage(CleanSynthetic.inputs(.normal, clis: 2))
        #expect(page.showsBand && page.moveBand == nil)
        let hero = try Self.drawnSize(PageHero(page.hero, label: page.heroLabel).fixedSize())
        var bandHeights: [CGFloat: CGFloat] = [:]
        for width in Self.widths {
            let layout = Self.settled(.clean, look: .solid, width: width, sidebarHidden: false)
            // The list's width less the content insets and the header's own 8 pt each side (`CleanList`).
            let header = layout.mainColumnWidth - layout.contentInsets.leading - layout.contentInsets.trailing - 2 * SpaceRole.step8
            let bandWidth = try #require(PageHeaderLayout.bandWidth(header: header, heroWidth: hero.width, spacing: SpaceRole.step24))
            let band = try Self.drawnSize(CleanBand(share: page.barShare, text: page.barText)
                .frame(width: bandWidth).fixedSize(horizontal: false, vertical: true))
            bandHeights[width] = band.height
            let placed = PageHeaderLayout.place(hero: hero, band: band, spacing: SpaceRole.step24, width: header)
            #expect(placed.hero.origin == .zero, "\(width): the hero at the header's top-left")
            #expect(placed.size.height == max(hero.height, band.height))
            if band.height <= hero.height {
                #expect(placed.band?.maxY == hero.height, "\(width): a band no taller than the hero sits on its bottom line")
            } else {
                #expect(placed.band?.minY == 0, "\(width): a taller band grows down from the hero's top")
            }
        }
        // The case itself: at 1000 the note wraps, so a bottom-aligned header would have pushed the hero down.
        let narrow = try #require(bandHeights[1000]), wide = try #require(bandHeights[1280])
        #expect(narrow > wide && narrow > hero.height, "the note wraps at 1000: \(narrow) against \(wide), hero \(hero.height)")
    }

    /// A view's size as `ImageRenderer` lays it out, at scale 1.
    private static func drawnSize<V: View>(_ view: V) throws -> CGSize {
        let renderer = ImageRenderer(content: view.environment(\.isShotRendering, true))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        return CGSize(width: image.width, height: image.height)
    }

    @Test("the inspector starts under the toolbar, docked from 1100 pt and as the overlay below (RD57)")
    func inspectorUnderToolbar() {
        for look in [MaterialLook.glass, .solid] {
            for page in FramePage.allCases where page.hasInspector {
                let docked = Self.settled(page, look: look, width: 1280, sidebarHidden: false)
                #expect(docked.presentation == .docked && docked.inspectorTop == FrameRole.toolbarHeight(look), "\(page) \(look)")
                let chrome = FrameChrome(page: page)
                chrome.setWindowWidth(1000)
                chrome.pageHasInspector = true
                chrome.openInspector()
                let overlay = chrome.layout(on: page, hasInspector: true, look: look)
                #expect(overlay.presentation == .overlay && overlay.inspectorTop == FrameRole.toolbarHeight(look), "\(page) \(look)")
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
        #expect(FrameRole.trafficLightCenter(.glass) == SpaceRole.sidebarInset(.glass) + FrameRole.trafficLightClearance / 2)
        let solid = FrameWindowButtonsPlacement.make(look: .solid, buttonSize: size, pitch: 23)
        #expect(solid.titlebarHeight == 52 && solid.origins.first == CGPoint(x: 19, y: 19))
        for (look, placement) in [(MaterialLook.glass, glass), (.solid, solid)] {
            // With the sidebar hidden the toolbar starts at least 12 pt after the last light.
            #expect(placement.trailingEdge(buttonWidth: size.width) + SpaceRole.step12 <= FrameRole.trafficLightsWidth(look))
            // The lights sit inside the sidebar's light strip, clear of its rounded corner.
            #expect(placement.origins[0].y >= SpaceRole.sidebarInset(look))
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
