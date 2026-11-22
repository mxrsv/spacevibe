import SwiftUI

/// The redesign's Hooks shots (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=hooks`): every page state of RD-R13 from the
/// in-memory engine `HooksShotCore`, in both looks and appearances, beside the mock's same state
/// (`mock.html?page=hooks&state=<state>`). Files are `frame-hooks-<state>-<look>-<appearance>.png`:
///
/// - `normal`, `normal-1000`, `normal-1600` (window widths), `selected` (a dead Hook selected, its inspector and row action),
///   `ticked` (Select N Suggested pressed), `event` (the strip filtered to PreToolUse), `many` (10 CLIs: same shape);
/// - `empty`, `scanning`, `error` (Codex folder unreadable), `failed` (nothing could be read), `worst` (break-ui data);
/// - `write` (a dead Hook removed: the toast with Undo), `refused` (the core's refusal toast), `copied` (Copy Command's toast).
///
/// Every shot first selects what the page selects on opening (RD44). `scanning` shows skeleton rows and no judged row;
/// `failed` has no strip and no search; `worst` draws the strip with every Claude Code event (17 nodes, names whole).
///
/// No confirmation state: Hooks never ask (mock `MOCK.na`), every removal has Undo.
@MainActor
enum HooksFrameShots {
    struct Shot {
        let name: String
        let scenario: HooksShotCore.Scenario
        var width: CGFloat = 1280
        /// A toast the page shows after `prepare` (one that is not a write's, so no core call makes it).
        var toast: String?
        var prepare: @MainActor (FrameModel, HooksPageState) async -> Void = { _, _ in }
    }

    static let deadHook = "hook::h1@claude"

    static let shots: [Shot] = [
        Shot(name: "normal", scenario: .normal),
        Shot(name: "normal-1000", scenario: .normal, width: 1000),
        Shot(name: "normal-1600", scenario: .normal, width: 1600),
        Shot(name: "selected", scenario: .normal) { model, _ in model.router.select(deadHook) },
        Shot(name: "ticked", scenario: .normal) { model, state in
            state.toggleAll(HooksListModel.from(model.store, view: state.view, query: model.search.query).suggested)
        },
        Shot(name: "event", scenario: .normal) { _, state in state.filter(event: "PreToolUse") },
        Shot(name: "many", scenario: .many),
        Shot(name: "empty", scenario: .empty),
        Shot(name: "scanning", scenario: .scanning),
        Shot(name: "error", scenario: .error),
        Shot(name: "failed", scenario: .failed),
        Shot(name: "worst", scenario: .worst),
        Shot(name: "write", scenario: .normal) { model, state in await remove(deadHook, model: model, state: state) },
        // Copy Command's toast (not a write: no Undo). The shot shows the page's own sentence without touching the clipboard.
        Shot(name: "copied", scenario: .normal, toast: HooksPageState.copiedToast) { model, _ in model.router.select(deadHook) },
        Shot(name: "refused", scenario: .refused) { model, state in await remove(deadHook, model: model, state: state) },
    ]

    static func run(into directory: URL) throws {
        for shot in shots {
            for choice in [AppearanceChoice.dark, .light] {
                for look in ShotRenderer.frameLooks {
                    try write(shot, look: look, choice: choice, into: directory)
                }
            }
        }
    }

    private static func write(_ shot: Shot, look: MaterialLook, choice: AppearanceChoice, into directory: URL) throws {
        let core = HooksShotCore(shot.scenario)
        let toasts = ToastCenter(announce: false)
        let env = AppEnvironment(toasts: toasts, makeCoreClient: { core })
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: .hooks))
        let state = HooksPageState.of(model)
        // `ImageRenderer` runs no `.task`: the store is started here and the run loop spun until it has read.
        var ready = false
        Task { @MainActor in
            Task { await model.store.start() }
            try? await Task.sleep(for: .milliseconds(1))
            try? await waitForReads(model)
            // What the page does on opening (RD44, `frameFirstRowSelection`), which `ImageRenderer` never runs.
            keepSelection(model, state)
            await shot.prepare(model, state)
            keepSelection(model, state)
            if let toast = shot.toast { toasts.show(toast) }
            ready = true
        }
        try ShotHarness.wait("the Hooks shot \(shot.name)") { ready }
        let view = AppFrame(model: model, look: look, sidebarValues: .from(model.store))
            .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)), toasts: toasts, env: env)
            .frame(width: shot.width, height: ShotRenderer.size.height)
        try ShotRenderer.write(view, name: "frame-hooks-\(shot.name)-\(look)", choice: choice, to: directory)
    }

    /// Until `loadout.rows` answered or failed (a scanning core never finishes its scan, so the scan is not waited for).
    private static func waitForReads(_ model: FrameModel) async throws {
        for _ in 0..<500 {
            if model.store.states[.loadout] != nil, model.store.states[.loadout] != .loading { return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private static func keepSelection(_ model: FrameModel, _ state: HooksPageState) {
        model.router.keepSelection(onPage: .hooks, among: HooksListModel.from(model.store, view: state.view, query: model.search.query).visible.map(\.id))
    }

    private static func remove(_ id: String, model: FrameModel, state: HooksPageState) async {
        model.router.select(id)
        guard let row = HooksListModel.from(model.store, view: state.view, query: model.search.query).row(id), let write = HooksRemoval.write([row], registry: model.store.snapshot.registry) else { return }
        await model.writes.perform(write)
    }
}
