import Foundation
import Observation

/// Where the frame is: the page, the selected id on it and the scope (plan AR5). One value, so every way in sets the
/// same thing. Selecting a row never changes the page (FE7).
struct FrameRoute: Equatable, Sendable {
    var page: FramePage
    /// The selected row's id on `page`, in that page's terms: a row key, an Activity item id (`cli:sessionID`), a Limits
    /// Window id (`cli:windowID`), an Inbox finding id.
    var selection: String?
    /// The Claude Code permission file Rules shows; global elsewhere.
    var scope: FrameScope

    init(page: FramePage = .inbox, selection: String? = nil, scope: FrameScope = .global) {
        self.page = page
        self.selection = selection
        self.scope = scope
    }

    /// Another page: its own selection starts empty (RD41: nothing is pre-selected); the scope stays.
    func opening(_ next: FramePage) -> FrameRoute {
        next == page ? self : FrameRoute(page: next, selection: nil, scope: scope)
    }

    /// A row on the same page; the page never changes.
    func selecting(_ id: String?) -> FrameRoute { FrameRoute(page: page, selection: id, scope: scope) }

    /// Another file on Rules: the old selection named a rule of the old file.
    func scoped(_ next: FrameScope) -> FrameRoute { FrameRoute(page: page, selection: next == scope ? selection : nil, scope: next) }

    /// ⌘1 to ⌘8 in sidebar order (RD39): 1 is Inbox, 7 Limits, 8 Activity. Nil outside 1...8.
    static func page(forShortcut number: Int) -> FramePage? {
        let pages = FramePage.allCases
        return (1...pages.count).contains(number) ? pages[number - 1] : nil
    }

    /// The glance widget's fallback (GW6): Activity with that session selected. `itemID` is `cli:sessionID`.
    static func session(_ itemID: String) -> FrameRoute { FrameRoute(page: .activity, selection: itemID) }

    /// The countdown pill and its popover (LC-R7): Limits with that Window selected. `windowID` is `cli:windowID`.
    static func window(_ windowID: String) -> FrameRoute { FrameRoute(page: .limits, selection: windowID) }
}

/// The holder of the one route value, for everything that sets it from outside a page: the sidebar, the menu bar and its
/// ⌘1 to ⌘8, the glance widget and the countdown pill.
///
/// Wired: the sidebar (`AppFrame`), the menu bar with ⌘1 to ⌘8 (`FrameCommands`, installed in place of the v5
/// `ShellCommands` while the switch is on), and the glance widget with its countdown pill (`GlanceController.frame`, set by
/// `AppFrame`), which call `go(to:)` with `FrameRoute.session` or `FrameRoute.window`.
@MainActor
@Observable
final class FrameRouter {
    private(set) var route: FrameRoute {
        didSet { if route != oldValue { revision += 1 } }
    }
    /// Counts route changes. A page's dialog records it when it opens and is closed by any change after (the glance widget
    /// routes from outside the window while the dialog covers it), so it never comes back over another page or selection.
    private(set) var revision = 0

    init(_ route: FrameRoute = FrameRoute()) {
        self.route = route
    }

    func open(_ page: FramePage) { route = route.opening(page) }

    /// False for a number outside 1...8.
    @discardableResult
    func open(shortcut number: Int) -> Bool {
        guard let page = FrameRoute.page(forShortcut: number) else { return false }
        open(page)
        return true
    }

    func select(_ id: String?) { route = route.selecting(id) }

    func setScope(_ scope: FrameScope) { route = route.scoped(scope) }

    func go(to next: FrameRoute) { route = next }
}
