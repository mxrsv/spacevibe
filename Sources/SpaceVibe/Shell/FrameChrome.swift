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

    var presentation: InspectorPresentation {
        inspector.presentation(windowWidth: windowWidth, pageHasInspector: pageHasInspector)
    }

    var isInspectorShown: Bool { presentation != .hidden }

    /// The main column's width: the window less the sidebar and a docked inspector (the mock's `mw`).
    func listWidth(sidebar: CGFloat, inspector: CGFloat) -> CGFloat {
        max(0, windowWidth - sidebar - (presentation == .docked ? inspector : 0))
    }

    func setWindowWidth(_ width: CGFloat) {
        let wasOverlayWidth = FrameInspectorState.isOverlayWidth(windowWidth)
        windowWidth = width
        if wasOverlayWidth != FrameInspectorState.isOverlayWidth(width) { inspector = inspector.closingOverlay() }
    }

    func toggleInspector() { inspector = inspector.toggled(windowWidth: windowWidth) }

    /// A row click (regions call it) or Return on a selected row.
    func openInspector() { inspector = inspector.opened(windowWidth: windowWidth) }

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

    func pageChanged() {
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
}
