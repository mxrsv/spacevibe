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

    /// Another page: its own selection starts empty, and the page's first row is selected once its rows are known (RD44,
    /// `FrameRouter.keepSelection`; RD41's "nothing is pre-selected" is about ticks); the scope stays.
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
///
/// Two steps run before the route changes, so the new page's first-row rule (RD44) never judges with what the old page
/// left: another page clears the toolbar's search (`search`), and an outside route (`go(to:)`) first asks the page's
/// revealer (`setRevealer`) to clear whatever of its own view state would hide the row it names (Activity's tab and CLI
/// menu).
@MainActor
@Observable
final class FrameRouter {
    private(set) var route: FrameRoute
    /// Counts page changes and outside routes (`go(to:)`), never a selection or a scope. A page's dialog records it when it
    /// opens and is closed by any change after (the glance widget routes from outside the window while the dialog covers
    /// it), so it never comes back over another page; the automatic first-row selection (RD44) never closes it.
    private(set) var revision = 0

    /// The toolbar's search: cleared when another page opens, before that page's rows are first judged.
    @ObservationIgnored weak var search: FrameSearch?
    @ObservationIgnored private var revealers: [FramePage: @MainActor (String) -> Void] = [:]

    init(_ route: FrameRoute = FrameRoute(), search: FrameSearch? = nil) {
        self.route = route
        self.search = search
    }

    func open(_ page: FramePage) { change(to: route.opening(page)) }

    /// False for a number outside 1...8.
    @discardableResult
    func open(shortcut number: Int) -> Bool {
        guard let page = FrameRoute.page(forShortcut: number) else { return false }
        open(page)
        return true
    }

    func select(_ id: String?) { route = route.selecting(id) }

    func setScope(_ scope: FrameScope) { route = route.scoped(scope) }

    /// An outside route (the glance widget, the countdown pill): that page with that row, revealed. The scope stays the
    /// current one (a widget click never resets Rules to Global); the search is cleared and the page's revealer clears what
    /// would hide the row, so the first-row rule keeps it selected. Always counts as a change (`revision`), even to the
    /// route already showing: a dialog open over it closes.
    func go(to next: FrameRoute) {
        search?.clear()
        if let id = next.selection { revealers[next.page]?(id) }
        revision += 1
        route = FrameRoute(page: next.page, selection: next.selection, scope: route.scope)
    }

    /// `reveal` runs before `go(to:)` routes to a row of `page`: it clears the page's own filters that would hide that row.
    /// One per page; a later one replaces it.
    func setRevealer(for page: FramePage, _ reveal: @escaping @MainActor (String) -> Void) {
        revealers[page] = reveal
    }

    private func change(to next: FrameRoute) {
        guard next != route else { return }
        if next.page != route.page {
            search?.clear()
            revision += 1
        }
        route = next
    }

    /// RD44: `page` shows `rows`, in order. While it is the page showing and its selection is none of them (the page just
    /// opened, or a filter, the scope or the search hid the selected row), the first row is selected, so the inspector shows
    /// it; with no rows, nothing is. `select` is the page's own way to select (it may reset view state); the router's by
    /// default. A page that is not showing changes nothing, so a list leaving the screen never selects on the next page.
    func keepSelection(onPage page: FramePage, among rows: [String], select: ((String?) -> Void)? = nil) {
        guard route.page == page else { return }
        let next = FrameFirstRow.selection(current: route.selection, rows: rows)
        guard next != route.selection else { return }
        if let select { select(next) } else { self.select(next) }
    }
}

/// The first-row rule of RD44, pure: a selection among `rows` stays; any other (none, or a row now hidden) becomes the first
/// row; no rows, no selection.
enum FrameFirstRow {
    static func selection(current: String?, rows: [String]) -> String? {
        if let current, rows.contains(current) { return current }
        return rows.first
    }
}
