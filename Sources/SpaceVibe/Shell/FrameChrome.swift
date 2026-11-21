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

/// The frame's own view state, beside the route (`FrameRouter`): the inspector, the page help, the window width and whether
/// the keyboard is moving the selection (the RD29 focus bar shows only then, as the mock's `kbd`). It is not the store
/// (AR3): nothing here is data. `AppFrame` owns it; regions read it from the environment and the menu bar from the focused
/// scene.
@MainActor
@Observable
final class FrameChrome {
    private(set) var inspector = FrameInspectorState()
    private(set) var windowWidth: CGFloat = 0
    /// Whether the page showing has an inspector (its region gave one).
    var pageHasInspector = false
    var isHelpOpen = false
    /// True after an arrow key moved the selection, false after a pointer click: rows draw the focus bar on the selected
    /// row only while it is true.
    private(set) var showsFocusBar = false

    var presentation: InspectorPresentation {
        inspector.presentation(windowWidth: windowWidth, pageHasInspector: pageHasInspector)
    }

    var isInspectorShown: Bool { presentation != .hidden }

    func setWindowWidth(_ width: CGFloat) {
        let wasOverlayWidth = FrameInspectorState.isOverlayWidth(windowWidth)
        windowWidth = width
        if wasOverlayWidth != FrameInspectorState.isOverlayWidth(width) { inspector = inspector.closingOverlay() }
    }

    func toggleInspector() { inspector = inspector.toggled(windowWidth: windowWidth) }

    /// A row click (regions call it) or Return on a selected row.
    func openInspector() { inspector = inspector.opened(windowWidth: windowWidth) }

    func markKeyboardSelection(_ isKeyboard: Bool) { showsFocusBar = isKeyboard }

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
        showsFocusBar = false
    }
}

/// One step of arrow-key selection (RD39: ↑↓ and j/k) over the rows a page shows, in order. Nothing selected: down picks the
/// first row, up the last; the ends hold. A selection that is no longer shown starts again from the edge.
enum FrameSelectionStep {
    static func next(from current: String?, in rows: [String], by offset: Int) -> String? {
        guard !rows.isEmpty else { return nil }
        guard let current, let index = rows.firstIndex(of: current) else { return offset >= 0 ? rows.first : rows.last }
        return rows[min(max(index + offset, 0), rows.count - 1)]
    }
}

extension View {
    /// The list keys of a page (RD39, RD-R16): ↑↓ and j/k move the selection over `rows` and show the RD29 focus bar; Return
    /// opens the inspector on the selected row. Arrows never open it. A region applies it on its list; a native `Table` keeps
    /// its own arrows.
    func frameListKeys(rows: [String], router: FrameRouter, chrome: FrameChrome) -> some View {
        modifier(FrameListKeys(rows: rows, router: router, chrome: chrome))
    }
}

private struct FrameListKeys: ViewModifier {
    let rows: [String]
    let router: FrameRouter
    let chrome: FrameChrome

    func body(content: Content) -> some View {
        content
            .onKeyPress(keys: [.upArrow, .downArrow, "j", "k"]) { press in
                guard press.modifiers.isEmpty else { return .ignored }
                let offset = press.key == .upArrow || press.key == "k" ? -1 : 1
                guard let next = FrameSelectionStep.next(from: router.route.selection, in: rows, by: offset) else { return .ignored }
                router.select(next)
                chrome.markKeyboardSelection(true)
                return .handled
            }
            .onKeyPress(.return) {
                guard router.route.selection != nil else { return .ignored }
                chrome.openInspector()
                return .handled
            }
    }
}
