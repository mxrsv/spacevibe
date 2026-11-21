import Foundation

/// The redesign frame's shared parts, made once by `AppFrame` and only while the switch is on: the store (AR2), the write
/// service (AR4) and the route (AR5). The derivations (AR3) are `store.world(now:)`. Pages take what they need from here;
/// none calls `CoreService` itself.
@MainActor
final class FrameModel {
    let store: FrameStore
    let writes: FrameWrites
    let router: FrameRouter

    /// `cliPreferences`: Settings › CLIs; nil is the app's own (`CLIPreferences.shared`, in memory under `SPACEVIBE_TEST=1`).
    init(core: any CoreService, toasts: ToastCenter, route: FrameRoute = FrameRoute(), cliPreferences: CLIPreferences? = nil) {
        store = FrameStore(core: core, cliPreferences: cliPreferences ?? .shared)
        writes = FrameWrites(core: core, store: store, toasts: toasts)
        router = FrameRouter(route)
    }
}
