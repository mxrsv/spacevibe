import Foundation

/// The redesign frame's shared parts, made once by the app (`SpaceVibeFrameApp`) and only while the switch is on: the store
/// (AR2), the write service (AR4), the route (AR5), the toolbar's search and every page's own view state. The main window,
/// the Settings window and the Journal window read the same one, so they cannot disagree. The derivations (AR3) are
/// `store.world(now:)`. Pages take what they need from here; none calls `CoreService` itself.
@MainActor
final class FrameModel {
    let store: FrameStore
    let writes: FrameWrites
    let router: FrameRouter
    /// The search field of the page showing (⌘F): its text filters that page's list, never its hero (AR3).
    let search = FrameSearch()

    /// Each page's view state (AR3: never in the store), made the first time the page draws and kept as long as this model.
    private var pageStates: [PageStateKey: AnyObject] = [:]

    private struct PageStateKey: Hashable {
        let type: ObjectIdentifier
        let page: FramePage?
    }

    /// `cliPreferences`: Settings › CLIs; nil is the app's own (`CLIPreferences.shared`, in memory under `SPACEVIBE_TEST=1`).
    init(core: any CoreService, toasts: ToastCenter, route: FrameRoute = FrameRoute(), cliPreferences: CLIPreferences? = nil) {
        store = FrameStore(core: core, cliPreferences: cliPreferences ?? .shared)
        // RB-R5: `clean.scan` through the store's on-demand hook (Clean opening, Scan Again, ⌘R, after a write).
        store.cleanScanner = { try await core.cleanScan() }
        writes = FrameWrites(core: core, store: store, toasts: toasts)
        router = FrameRouter(route)
    }

    /// The one page state of type `State` (for `page` when one type serves two pages, as Skills and Subagents), made by
    /// `make` on first use. `FramePageContent.region` is rebuilt on every render, so a page state that must outlive a render
    /// (ticks, an open sheet, the tab) lives here. A state that needs the model holds it weakly, so nothing leaks.
    func pageState<State: AnyObject>(_ type: State.Type, page: FramePage? = nil, make: () -> State) -> State {
        let key = PageStateKey(type: ObjectIdentifier(type), page: page)
        if let found = pageStates[key] as? State { return found }
        let state = make()
        pageStates[key] = state
        return state
    }
}
