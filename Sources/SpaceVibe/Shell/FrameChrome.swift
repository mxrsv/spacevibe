import Observation
import SwiftUI

/// Where the trailing inspector is drawn (RD-R13, DS-R10).
enum InspectorPresentation: Equatable, Sendable {
    /// The page has none, or it is closed.
    case hidden
    /// A column beside the list, at `SpaceRole.inspectorOverlayBelowWindowWidth` and wider.
    case docked
    /// Narrower: over the list, opened by the toolbar button, a row click, Return or ⌘I.
    case overlay
}

/// The inspector's open state. Pure: every answer is a function of the window width, so the 1100 pt rule is tested alone.
///
/// - At 1100 pt and wider the inspector is docked and shown; ⌘I and the toolbar button hide and show it.
/// - Below, it starts closed and opens as an overlay; Esc closes it. Arrows never open it (RD-R16).
/// - Another page closes the overlay (its selection starts empty, RD41).
struct FrameInspectorState: Equatable, Sendable {
    var isDockedHidden = false
    var isOverlayOpen = false

    static func isOverlayWidth(_ windowWidth: CGFloat) -> Bool {
        windowWidth < SpaceRole.inspectorOverlayBelowWindowWidth
    }

    func presentation(windowWidth: CGFloat, pageHasInspector: Bool) -> InspectorPresentation {
        guard pageHasInspector else { return .hidden }
        if Self.isOverlayWidth(windowWidth) { return isOverlayOpen ? .overlay : .hidden }
        return isDockedHidden ? .hidden : .docked
    }

    /// The toolbar button and ⌘I.
    func toggled(windowWidth: CGFloat) -> FrameInspectorState {
        Self.isOverlayWidth(windowWidth)
            ? FrameInspectorState(isDockedHidden: isDockedHidden, isOverlayOpen: !isOverlayOpen)
            : FrameInspectorState(isDockedHidden: !isDockedHidden, isOverlayOpen: false)
    }

    /// A row click or Return on a selected row: shows the inspector at any width.
    func opened(windowWidth: CGFloat) -> FrameInspectorState {
        Self.isOverlayWidth(windowWidth)
            ? FrameInspectorState(isDockedHidden: isDockedHidden, isOverlayOpen: true)
            : FrameInspectorState(isDockedHidden: false, isOverlayOpen: false)
    }

    /// Esc, the overlay's close button, or the window growing past 1100 pt: the overlay closes; a docked one stays.
    func closingOverlay() -> FrameInspectorState {
        FrameInspectorState(isDockedHidden: isDockedHidden, isOverlayOpen: false)
    }
}

/// Where the frame's regions go for one page (RB-F4: page switching holds still). Pure: every value is a function of the
/// look, the window width, Hide Sidebar and the inspector's presentation, so the test can ask it for every page and see that
/// only the inspector's own column changes, as DS2 sets its width per page.
///
/// - The sidebar, the toolbar's leading group (Hide Sidebar, the title) and the content's top-left corner (where the hero
///   and the first group head start) are the same on every page.
/// - A docked inspector is 336 on Skills, Subagents and Inbox and 308 elsewhere (DS2), and Clean and Limits have none
///   (the mock's `hasIns`): the main column's trailing edge, with the toolbar's trailing group in it, follows that column,
///   as in the mock, where the toolbar is the main column's (`.mn .tb`).
struct FrameRegionLayout: Equatable, Sendable {
    /// The sidebar column, the floating sidebar's inset included; 0 while it is hidden.
    let sidebarWidth: CGFloat
    /// The toolbar's leading padding inside the main column: after the traffic lights while the sidebar is hidden.
    let toolbarLeading: CGFloat
    /// The page's content inside the main column: under the toolbar (DS-R3 clearance) and off the column's edges.
    let contentInsets: EdgeInsets
    let presentation: InspectorPresentation
    /// The inspector's width wherever it is drawn (docked or overlay); 0 while it is hidden or the page has none.
    let inspectorWidth: CGFloat
    /// The main column: the window less the sidebar and a docked inspector (the mock's `mw`).
    let mainColumnWidth: CGFloat

    static func make(page: FramePage, presentation: InspectorPresentation, look: MaterialLook, windowWidth: CGFloat,
                     isSidebarHidden: Bool) -> FrameRegionLayout {
        let sidebar = isSidebarHidden ? 0 : FrameRole.sidebarWidth(look)
        let inspector = presentation == .hidden ? 0 : page.inspectorWidth.points
        let docked = presentation == .docked ? inspector : 0
        return FrameRegionLayout(
            sidebarWidth: sidebar,
            toolbarLeading: isSidebarHidden ? FrameRole.trafficLightsWidth(look) : SpaceRole.step12,
            contentInsets: EdgeInsets(top: SpaceRole.toolbarClearance(look), leading: SpaceRole.step12,
                                      bottom: SpaceRole.step24, trailing: SpaceRole.step20),
            presentation: presentation,
            inspectorWidth: inspector,
            mainColumnWidth: max(0, windowWidth - sidebar - docked))
    }
}

/// The frame's own view state, beside the route (`FrameRouter`): the inspector, the page help, the window width and the row
/// the keyboard moved the selection to (the RD29 focus bar shows only there, as the mock's `kbdId`). It is not the store
/// (AR3): nothing here is data. `AppFrame` owns it; regions read it from the environment and the menu bar from the focused
/// scene.
@MainActor
@Observable
final class FrameChrome {
    private(set) var inspector = FrameInspectorState()
    private(set) var windowWidth: CGFloat = 0
    /// Whether the page showing has an inspector (its region gave one).
    var pageHasInspector = false
    /// Whether the page showing has a search field (its region named what it finds), so ⌘F has something to focus.
    var pageHasSearch = false
    /// Whether a page's dialog covers the window (`FramePageContent.dialog`): the menu bar's commands wait for it.
    var isDialogOpen = false
    var isHelpOpen = false
    /// The row an arrow key moved the selection to (`frameListKeys`); nil after a pointer click, on another page and when the
    /// list loses focus. Only that row draws the focus bar.
    var keyboardRow: String?
    /// Hide Sidebar (RD47): the toolbar's first button and ⌃⌘S fold the sidebar away and bring it back. The window keeps the
    /// choice across launches (`AppFrame` stores it per window with `@SceneStorage`).
    var isSidebarHidden = false
    /// The page the frame shows, set when the route's page changes (`pageChanged(to:)`).
    private(set) var shownPage: FramePage?
    /// The page the overlay inspector was opened on: another page never draws it, not even in the first render after the
    /// page changed, before `pageChanged(to:)` closes it (RB-F4).
    private var overlayPage: FramePage?

    init(page: FramePage? = nil) {
        shownPage = page
    }

    /// The menu bar's view of the inspector: the page showing, with what its region last gave.
    var presentation: InspectorPresentation {
        presentation(on: shownPage, hasInspector: pageHasInspector)
    }

    /// Where `page`'s inspector is drawn, from what the page gives in this very render (`hasInspector`). The frame asks this
    /// instead of `presentation`, whose `pageHasInspector` follows a page change one render late: the page before's answer
    /// would draw the new page for one render without its docked inspector, or with the page before's overlay (RB-F4).
    func presentation(on page: FramePage?, hasInspector: Bool) -> InspectorPresentation {
        let shown = inspector.presentation(windowWidth: windowWidth, pageHasInspector: hasInspector)
        guard shown == .overlay, let overlayPage, overlayPage != page else { return shown }
        return .hidden
    }

    var isInspectorShown: Bool { presentation != .hidden }

    /// The frame's regions for `page` in this render (`FrameRegionLayout`), from what the page gives now (`hasInspector`).
    func layout(on page: FramePage, hasInspector: Bool, look: MaterialLook) -> FrameRegionLayout {
        FrameRegionLayout.make(page: page, presentation: presentation(on: page, hasInspector: hasInspector), look: look,
                               windowWidth: windowWidth, isSidebarHidden: isSidebarHidden)
    }

    /// The main column's width: the window less the sidebar (none while it is hidden) and a docked inspector (the mock's `mw`).
    /// `inspector` is the width of the asking page's own inspector, 0 for a page without one. Whether it is docked depends on
    /// the window and the user's choice only, never on the page shown before (RB-F4): a region measuring its columns in the
    /// first render after a page change gets the same answer as in the next.
    func listWidth(sidebar: CGFloat, inspector: CGFloat) -> CGFloat {
        let docked = inspector > 0 && self.inspector.presentation(windowWidth: windowWidth, pageHasInspector: true) == .docked
        return max(0, windowWidth - (isSidebarHidden ? 0 : sidebar) - (docked ? inspector : 0))
    }

    /// The toolbar's Hide Sidebar button and ⌃⌘S.
    func toggleSidebar() { isSidebarHidden.toggle() }

    /// The button's and the menu item's title for the state now.
    var sidebarCommandTitle: String { Self.sidebarCommandTitle(hidden: isSidebarHidden) }

    static func sidebarCommandTitle(hidden: Bool) -> String { hidden ? "Show Sidebar" : "Hide Sidebar" }

    func setWindowWidth(_ width: CGFloat) {
        let wasOverlayWidth = FrameInspectorState.isOverlayWidth(windowWidth)
        windowWidth = width
        if wasOverlayWidth != FrameInspectorState.isOverlayWidth(width) { inspector = inspector.closingOverlay() }
    }

    func toggleInspector() {
        inspector = inspector.toggled(windowWidth: windowWidth)
        overlayPage = shownPage
    }

    /// A row click (regions call it) or Return on a selected row.
    func openInspector() {
        inspector = inspector.opened(windowWidth: windowWidth)
        overlayPage = shownPage
    }

    /// A row click: the selection moved by pointer, so no row shows the focus bar.
    func pointerSelected() { keyboardRow = nil }

    /// Esc: closes the overlay inspector and the page help. False when nothing was open, so the key goes on.
    @discardableResult
    func closeOverlays() -> Bool {
        let wasOpen = presentation == .overlay || isHelpOpen
        inspector = inspector.closingOverlay()
        isHelpOpen = false
        return wasOpen
    }

    func pageChanged(to page: FramePage? = nil) {
        if let page { shownPage = page }
        inspector = inspector.closingOverlay()
        isHelpOpen = false
        keyboardRow = nil
    }
}

extension View {
    /// The list keys of a page (RD39, RD-R16): ↑↓ and j/k move the route's selection over `rows` (the rows shown, in order)
    /// through the one selection rule, `ListSelection` with `listKeyboardSelection`, and the moved-to row shows the RD29
    /// focus bar (`chrome.keyboardRow`). Arrows never open the inspector; Return does, at the frame (`AppFrame`). A region
    /// applies it on its list and draws `ItemRow(isKeyboardFocused: chrome.keyboardRow == row.id)`; a click selects through the
    /// router and clears the bar (`chrome.pointerSelected()`).
    func frameListKeys(rows: [String], router: FrameRouter, chrome: FrameChrome) -> some View {
        listKeyboardSelection(ids: rows,
                              selection: Binding(get: { router.route.selection }, set: { router.select($0) }),
                              keyboardRow: Binding(get: { chrome.keyboardRow }, set: { chrome.keyboardRow = $0 }))
    }

    /// RD44 on a page's list: `rows` are the ids it shows, in order (the same list `frameListKeys` takes). When the page
    /// opens, and whenever its selection is not among them (a filter, the scope or the search hid it, or a write removed
    /// it), the router selects the first, so the inspector shows that row (`FrameRouter.keepSelection`). `select` is the
    /// page's own selection call when it does more than the router's.
    func frameFirstRowSelection(page: FramePage, rows: [String], router: FrameRouter,
                                select: ((String?) -> Void)? = nil) -> some View {
        onChange(of: FrameFirstRowInput(page: router.route.page, selection: router.route.selection, rows: rows), initial: true) {
            router.keepSelection(onPage: page, among: rows, select: select)
        }
    }
}

/// What the first-row rule watches: a change in any of these may leave the page without a selected row it shows.
private struct FrameFirstRowInput: Equatable {
    let page: FramePage
    let selection: String?
    let rows: [String]
}
