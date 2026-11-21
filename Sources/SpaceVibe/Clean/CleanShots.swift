import SwiftUI

/// The redesign's Clean shots (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=clean`): every page state of RD-R13 from the
/// in-memory readings of `CleanSynthetic`, at 2 and 10 CLIs, in both looks and appearances, beside the mock's same state
/// (`mock.html?page=clean&state=<state>&nclis=<n>`; preset "Clean · Claude có session đang chạy" is `normal-2`, "Clean · đang
/// chuyển" is `moving-2`, "6 CLI · Clean" is near `normal-10`). Files are `frame-clean-<shot>-<look>-<appearance>.png`:
///
/// - `normal-2`, `normal-10`, `normal-1000`, `normal-1600` (Claude Code's logs and caches locked by its waiting session,
///   Codex's caches by an unmeasurable one, Codex logs open); `lock-2` (the lock popover open); `ticked-2` (every section's
///   `Select N Suggested` pressed: `Remove …` carries the bytes); `age-2` (Codex logs at 30 days);
/// - `empty-2` (Tidy), `scanning-2` (the first scan: `…`, `Measuring…`, skeleton rows), `error-2` (Codex folder and logs
///   unreadable), `worst-2`, `worst-10` (huge counts, long and right-to-left names, a long cache path, an unreadable usage
///   archive and a stranded move);
/// - `moving-2` (progress at the control, Cancel), `write-2` (the toast with Undo), `partial-2` (the mock's "Moved 2 of 3"),
///   `refused-2` (every row locked: nothing moved), `dialog-10` (a shared `~/.agents/skills` file: the confirmation names
///   every reader). At 2 CLIs no file is shared, so Clean never asks (mock `MOCK.na`).
@MainActor
enum CleanShots {
    struct Shot {
        let name: String
        let state: CleanSynthetic.State
        var clis = 2
        var width: CGFloat = 1280
        var move: CleanMoveRun.Snapshot?
        var prepare: @MainActor (CleanPageState, FrameWorld, ToastCenter) -> Void = { _, _, _ in }
    }

    static let suggested: @MainActor (CleanPageState, FrameWorld, ToastCenter) -> Void = { state, world, _ in
        state.ticked = Set(world.clean.suggestedAgents + world.clean.suggestedLogs + world.clean.suggestedCaches)
    }

    static let shots: [Shot] = [
        Shot(name: "normal-2", state: .normal),
        Shot(name: "normal-10", state: .normal, clis: 10),
        Shot(name: "normal-1000", state: .normal, width: 1000),
        Shot(name: "normal-1600", state: .normal, width: 1600),
        Shot(name: "lock-2", state: .normal) { state, _, _ in state.openLock = "logs:claude" },
        Shot(name: "ticked-2", state: .normal, prepare: suggested),
        Shot(name: "age-2", state: .normal) { state, _, _ in state.ticked = ["logs:codex"] },
        Shot(name: "empty-2", state: .empty),
        Shot(name: "scanning-2", state: .scanning),
        Shot(name: "error-2", state: .error),
        Shot(name: "worst-2", state: .worst, prepare: suggested),
        Shot(name: "worst-10", state: .worst, clis: 10),
        Shot(name: "moving-2", state: .normal,
             move: CleanMoveRun.Snapshot(isRunning: true, progress: CoreCleanProgress(phase: "moving", done: 760, total: 1_310, bytes: 452_000_000)),
             prepare: suggested),
        Shot(name: "write-2", state: .normal) { _, _, toasts in
            toasts.show("Removed 3 Skills and Subagent release-captain to SpaceVibe's trash and moved 780 MB of logs and caches to the macOS Trash",
                        asyncUndo: {})
        },
        Shot(name: "partial-2", state: .normal) { _, _, toasts in
            toasts.show("Moved 2 of 3. ~/.codex/cache stayed in place: Codex has 1 open session, so its caches are in use. Undo puts back what moved.",
                        tone: .partial, asyncUndo: {})
        },
        Shot(name: "refused-2", state: .normal) { _, _, toasts in
            toasts.show("Claude Code has 1 running session, so its logs stay until it ends. Nothing was moved.", tone: .danger)
        },
        Shot(name: "dialog-10", state: .normal, clis: 10) { state, world, _ in
            state.ticked = Set(world.clean.suggestedAgents)
            let page = CleanPage(CleanSynthetic.inputs(.normal, clis: 10), ticked: state.ticked)
            let wording = InboxWording(world: world, now: CleanSynthetic.now)
            let request = page.request(world)
            state.confirming = CleanConfirmation(items: request.rows.map { InboxActions.item($0, losers: wording.losers($0).map(wording.name)) },
                                                 request: request)
        },
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
        let inputs = CleanSynthetic.inputs(shot.state, clis: shot.clis, move: shot.move)
        let toasts = ToastCenter(announce: false)
        let state = CleanPageState()
        shot.prepare(state, inputs.world, toasts)
        let fixed = shot.name == "age-2" ? aged(inputs) : inputs
        let env = AppEnvironment.shared
        let view = AppFrame(page: .clean, env: env, look: look, sidebarValues: InboxShots.sidebar(fixed.world)) { page, model in
            page == .clean ? .clean(model: model, fixed: fixed, state: state) : .notBuilt(page)
        }
        .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)), toasts: toasts, env: env)
        .frame(width: shot.width, height: ShotRenderer.size.height)
        try ShotRenderer.write(view, name: "frame-clean-\(shot.name)-\(look)", choice: choice, to: directory)
    }

    /// Codex logs at 30 days: the age is a fact of the store, so the world is built again with it.
    private static func aged(_ inputs: CleanInputs) -> CleanInputs {
        var facts = inputs.world.facts
        facts.cleanLogAges = ["codex": 30]
        let world = FrameWorld(snapshot: inputs.world.snapshot, facts: facts, now: CleanSynthetic.now)
        return CleanInputs(world: world, figure: world.figure(for: .clean, loading: [], failed: []), now: CleanSynthetic.now)
    }
}
