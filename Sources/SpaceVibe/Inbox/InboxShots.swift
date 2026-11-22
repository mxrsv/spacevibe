import SwiftUI

/// The redesign's Inbox shots (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=inbox`): every page state of RD-R13 from the
/// in-memory readings of `InboxSynthetic`, at 2 and 10 CLIs, in both looks and appearances, beside the mock's same state
/// (`mock.html?page=inbox&state=<state>&nclis=<n>`). Files are `frame-inbox-<shot>-<look>-<appearance>.png`:
///
/// A shot with no selection of its own selects the first row shown, as the page does on opening (RD44).
///
/// - `normal-2`, `normal-10`, `normal-1000` (window width: no evidence column, overlay inspector), `normal-1600`;
/// - `selected-2`, `selected-10` (a Never ran Skill selected: its row actions and the CLI tiles), `session-2` (the waiting
///   session: Show Terminal), `window-2` (the Window behind pace: Keep only), `rule-2` (the dial and the Capability), `hook-2`
///   (a failing Hook), `balance-2` (Claude Code and Codex pinned, the Balance finding selected: Add to Codex),
///   `balance-off-2` (fewer than two pins: "Balance is off"), `ticked-2` (`Select N Suggested` pressed: `Remove 6 selected`),
///   `kept-2` (Show Kept open);
/// - `empty-2` (Clear, one kept finding), `scanning-2`, `error-2` (Codex folder unreadable), `worst-2`, `worst-10` (break-ui
///   data: long and right-to-left names, huge counts, a Window over the limit, no host app);
/// - `write-2` (a removal's toast with Undo, in `FrameWrite.removedMany`'s words), `refused-2` (the core's 409 sentence in
///   `FrameWrites.showRefused`'s toast, with Reload), `dialog-10` (a shared `~/.agents/skills` file: the confirmation names
///   every reader). At 2 CLIs no file is shared, so removal never asks (mock `MOCK.na`).
@MainActor
enum InboxShots {
    struct Shot {
        let name: String
        let state: InboxSynthetic.State
        var clis = 2
        var width: CGFloat = 1280
        /// Claude Code and Codex pinned (Balance on).
        var pinned = true
        var selection: (FrameWorld) -> String? = { _ in nil }
        var prepare: @MainActor (InboxPageState, FrameWorld, ToastCenter) -> Void = { _, _, _ in }
    }

    static let skill = "skill::pdf-extract"

    static let shots: [Shot] = [
        Shot(name: "normal-2", state: .normal),
        Shot(name: "normal-10", state: .normal, clis: 10),
        Shot(name: "normal-1000", state: .normal, width: 1000, selection: { _ in skill }),
        Shot(name: "normal-1600", state: .normal, width: 1600),
        Shot(name: "selected-2", state: .normal, selection: { _ in skill }),
        Shot(name: "selected-10", state: .normal, clis: 10, selection: { _ in skill }),
        Shot(name: "session-2", state: .normal, selection: { _ in "S:claude:s-waiting" }),
        Shot(name: "window-2", state: .normal, selection: { world in world.findings.first { $0.job == .watch && $0.id.hasPrefix("W:") }?.id }),
        Shot(name: "rule-2", state: .normal, selection: { _ in "R::global:allow:Bash" }),
        Shot(name: "hook-2", state: .normal, selection: { _ in "hook::h4@claude:fail" }),
        Shot(name: "balance-2", state: .normal, selection: { world in world.findings.first { $0.job == .balance }?.id }),
        Shot(name: "balance-off-2", state: .normal, pinned: false),
        Shot(name: "ticked-2", state: .normal) { state, world, _ in
            state.pickSuggested(InboxPage(world: world, figure: figure(world), now: InboxSynthetic.now).groups.first?.suggested ?? [])
        },
        Shot(name: "kept-2", state: .empty) { state, _, _ in state.showsKept = true },
        Shot(name: "empty-2", state: .empty),
        Shot(name: "scanning-2", state: .scanning),
        Shot(name: "error-2", state: .error),
        Shot(name: "worst-2", state: .worst, selection: { _ in "S:claude:s-waiting" }),
        Shot(name: "worst-10", state: .worst, clis: 10),
        Shot(name: "write-2", state: .normal) { _, world, toasts in
            // What `FrameWrites` shows once the core removed the Hook from Claude Code (`removeMany`'s toast, with Undo).
            let rows = world.rows.filter { $0.id == "hook::h1@claude" }
            toasts.show(FrameWrite.removedMany(rows, lost: ["claude"], registry: world.snapshot.registry), journalEntries: ["shot"], asyncUndo: {})
        },
        Shot(name: "refused-2", state: .normal) { _, _, toasts in
            // The core's 409 when the file changed under the edit (`mutate/file-edit.go`), in the refused-write toast.
            FrameWrites.showRefused("~/.claude/settings.json changed while SpaceVibe was editing it, so it was left alone. Try again.",
                                    on: toasts) {}
        },
        Shot(name: "dialog-10", state: .normal, clis: 10) { state, world, _ in
            guard let row = world.rows.first(where: { $0.id == skill }) else { return }
            let wording = InboxWording(world: world, now: InboxSynthetic.now)
            state.confirming = InboxConfirmation(items: [InboxActions.item(row, losers: wording.losers(row).map(wording.name))],
                                                 write: .removeMany([row], registry: world.snapshot.registry), rowIDs: [row.id])
        },
    ]

    /// A host app for every session but the worst state's, which has none (tmux, ssh): "Terminal app not found".
    static func host(_ state: InboxSynthetic.State) -> InboxHost {
        InboxHost(hostApp: { pid in state == .worst ? nil : HostApp(pid: pid_t(pid), bundleIdentifier: "com.example.terminal", name: "Terminal") },
                  activate: { _ in true })
    }

    static func figure(_ world: FrameWorld) -> PageFigure { world.figure(for: .inbox, loading: [], failed: []) }

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
        let world = InboxSynthetic.world(shot.state, clis: shot.clis, pinned: shot.pinned)
        let toasts = ToastCenter(announce: false)
        let state = InboxPageState()
        shot.prepare(state, world, toasts)
        // What the page does on opening (RD44, `frameFirstRowSelection`), which `ImageRenderer` never runs.
        let shown = InboxPage(world: world, figure: figure(world), ticked: state.ticked, showsKept: state.showsKept, now: InboxSynthetic.now)
        let selection = FrameFirstRow.selection(current: shot.selection(world), rows: shown.order)
        let inputs = InboxInputs(world: world, figure: figure(world), now: InboxSynthetic.now, selection: selection)
        let env = AppEnvironment.shared
        let view = AppFrame(page: .inbox, env: env, look: look, sidebarValues: sidebar(world, state: shot.state)) { page, model in
            page == .inbox ? .inbox(model: model, fixed: inputs, host: host(shot.state), state: state) : .notBuilt(page)
        }
        .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)), toasts: toasts, env: env)
        .frame(width: shot.width, height: ShotRenderer.size.height)
        try ShotRenderer.write(view, name: "frame-inbox-\(shot.name)-\(look)", choice: choice, to: directory)
    }

    /// The sidebar of an Inbox shot: the same world with the Clean scan the store reads at launch (RD45), so Clean shows its
    /// figure as on every page.
    static func sidebar(_ world: FrameWorld, state: InboxSynthetic.State) -> FrameSidebarValues {
        let clean: CleanSynthetic.State = switch state {
        case .empty: .empty
        case .scanning: .scanning
        case .error: .error
        case .worst: .worst
        default: .normal
        }
        var snapshot = world.snapshot
        snapshot.clean = CleanSynthetic.scan(clean)
        return sidebar(FrameWorld(snapshot: snapshot, facts: world.facts, now: InboxSynthetic.now))
    }

    /// The sidebar's values from the same world (AR3: hero and sidebar read one figure).
    static func sidebar(_ world: FrameWorld) -> FrameSidebarValues {
        let critical = world.findings.filter { $0.severity == .critical }.count
        let values = FramePage.allCases.map { page in
            (page, FrameSidebarValue(figure: world.figure(for: page, loading: [], failed: []), page: page,
                                     criticalCount: page == .inbox ? critical : 0))
        }
        return FrameSidebarValues(values: Dictionary(uniqueKeysWithValues: values))
    }
}
