import SwiftUI

/// The redesign's Skills and Subagents shots (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=skills` or `subagents`): every page
/// state of RD-R13 from the in-memory engine `EquipShotCore`, in both looks and appearances, beside the mock's same state
/// (`mock.html?page=skills&state=<state>&nclis=<n>`). Files are `frame-<page>-<state>-<look>-<appearance>.png`:
///
/// - `normal`, `normal-1000`, `normal-1600` (window widths), `sidebar-hidden` (Hide Sidebar, RD47), `selected` (a used row: its tiles), `neverran` (a Never ran row
///   selected, the mock's `neverran`), `ticked` (Select N Suggested pressed: the `N selected` head and `Remove N selected…`);
/// - `six-illustration`, `ten-illustration` (RD13, RD28: the same layout at 6 and 10 CLIs, a row selected; RD42 illustration);
/// - `sheet` (an item's `Remove…`: the per-CLI sheet, nothing ticked), `dialog-six-illustration` (a shared file turned off:
///   the anchored confirmation), `inspop-six-illustration` (the same from the inspector's tile), `menu-six-illustration`
///   (`All CLIs` open);
/// - `empty`, `scanning`, `error` (Codex folder unreadable), `failed` (nothing could be read), `worst-ten-illustration`;
/// - `write` (a CLI turned on: the toast with Undo), `refused` (the core's refusal toast, naming the item the shot pressed).
///
/// The confirmation and the menu are system popovers, which `ImageRenderer` does not draw: those shots show the page under
/// them until the harness captures a window.
@MainActor
enum EquipFrameShots {
    struct Shot {
        let name: String
        let scenario: EquipShotCore.Scenario
        var width: CGFloat = 1280
        /// Hide Sidebar pressed (RD47).
        var sidebarHidden = false
        var prepare: @MainActor (FrameModel, EquipPageState) async -> Void = { _, _ in }
    }

    /// The rows the shots act on: one used everywhere, one Never ran, one whose Codex copy is the shared `~/.agents/skills`.
    static func used(_ kind: CoreKind) -> String { kind == .skill ? "skill::commit-helper" : "agent::code-reviewer" }
    static func neverRan(_ kind: CoreKind) -> String { kind == .skill ? "skill::pdf-extract" : "agent::db-migrator" }
    static func shared(_ kind: CoreKind) -> String { kind == .skill ? "skill::lint-fixer" : "agent::code-reviewer" }

    static func shots(_ kind: EquipKind) -> [Shot] {
        let used = used(kind.kind), never = neverRan(kind.kind), shared = shared(kind.kind)
        return [
            Shot(name: "normal", scenario: .normal),
            Shot(name: "normal-1000", scenario: .normal, width: 1000),
            Shot(name: "normal-1600", scenario: .normal, width: 1600),
            Shot(name: "sidebar-hidden", scenario: .normal, sidebarHidden: true),
            Shot(name: "selected", scenario: .normal) { _, state in state.select(used) },
            Shot(name: "neverran", scenario: .normal) { _, state in state.select(never) },
            Shot(name: "ticked", scenario: .normal) { _, state in state.selectSuggested() },
            Shot(name: "six-illustration", scenario: .six) { _, state in state.select(used) },
            Shot(name: "ten-illustration", scenario: .ten) { _, state in state.select(used) },
            Shot(name: "sheet", scenario: .normal) { _, state in
                state.select(used)
                state.openSheet(.remove, rows: [used])
            },
            Shot(name: "dialog-six-illustration", scenario: .six) { _, state in ask(shared, cli: "codex", from: .row, state: state) },
            Shot(name: "inspop-six-illustration", scenario: .six) { _, state in
                state.select(shared)
                ask(shared, cli: "codex", from: .tile, state: state)
            },
            Shot(name: "menu-six-illustration", scenario: .six) { _, state in state.isCLIMenuOpen = true },
            Shot(name: "empty", scenario: .empty),
            Shot(name: "scanning", scenario: .scanning),
            Shot(name: "error", scenario: .error),
            Shot(name: "failed", scenario: .failed),
            // The mock's worst state selects the first row whose name is longer than 40 (`defSel`, `c-inbox-equip.js`).
            Shot(name: "worst-ten-illustration", scenario: .worst) { _, state in
                let all = state.list().all
                state.select((all.first { $0.name.count > 40 } ?? all.first)?.id)
            },
            Shot(name: "write", scenario: .normal) { _, state in await press(used, cli: "codex", from: .row, state: state, add: true) },
            Shot(name: "refused", scenario: .refused) { _, state in await refuse(kind.kind, state: state) },
        ]
    }

    static func run(_ kind: EquipKind, into directory: URL) throws {
        for shot in shots(kind) {
            for choice in [AppearanceChoice.dark, .light] {
                for look in ShotRenderer.frameLooks {
                    try write(shot, kind: kind, look: look, choice: choice, into: directory)
                }
            }
        }
    }

    private static func write(_ shot: Shot, kind: EquipKind, look: MaterialLook, choice: AppearanceChoice, into directory: URL) throws {
        let core = EquipShotCore(shot.scenario, kind: kind.kind)
        let toasts = ToastCenter(announce: false)
        let env = AppEnvironment(toasts: toasts, makeCoreClient: { core })
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: kind.page))
        let state = EquipPageState.of(model, kind: kind)
        // `ImageRenderer` runs no `.task`: the store is started here and the run loop spun until it has read.
        var ready = false
        Task { @MainActor in
            Task { await model.store.start() }
            try? await Task.sleep(for: .milliseconds(1))
            try? await waitForReads(model)
            // What the page does on opening (RD44, `frameFirstRowSelection`), which `ImageRenderer` never runs.
            model.router.keepSelection(onPage: kind.page, among: state.list().visible.map(\.id)) { state.select($0) }
            await shot.prepare(model, state)
            ready = true
        }
        try ShotHarness.wait("the \(kind.page.title) shot \(shot.name)") { ready }
        let view = AppFrame(model: model, look: look, sidebarValues: .from(model.store), sidebarHidden: shot.sidebarHidden)
            .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)), toasts: toasts, env: env)
            .frame(width: shot.width, height: ShotRenderer.size.height)
        try ShotRenderer.write(view, name: "frame-\(kind.page.rawValue)-\(shot.name)-\(look)", choice: choice, to: directory)
    }

    /// Until `loadout.rows` answered or failed (a scanning core never finishes its scan, so the scan is not waited for).
    private static func waitForReads(_ model: FrameModel) async throws {
        for _ in 0..<500 {
            if model.store.states[.loadout] != nil, model.store.states[.loadout] != .loading { return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Presses `cli`'s logo (or tile) on row `id`; `add` presses an off logo of a row that lacks it, finding one if `cli` is on.
    private static func press(_ id: String, cli: String, from anchor: EquipPageState.Anchor, state: EquipPageState, add: Bool) async {
        let list = state.list()
        let row = add ? list.all.first { $0.row.presence(cli) == .off && $0.isTickable } : list.row(id)
        guard let row, let toggle = row.toggles.first(where: { $0.cli.id == cli }) else { return }
        await state.press(toggle, on: row, from: anchor)?.value
    }

    /// The refused write of the mock's `writefail`: Skills adds a skill Codex does not have (`changelog-writer`, Claude Code only)
    /// to Codex; Subagents removes `release-captain` (Codex only, so its last copy: through `Remove…`). The core's sentence names
    /// that item, so the toast never names one the page shows as already on.
    private static func refuse(_ kind: CoreKind, state: EquipPageState) async {
        if kind == .skill {
            await press(refusedSkill, cli: "codex", from: .row, state: state, add: false)
        } else {
            state.select(refusedSubagent)
            state.openSheet(.remove, rows: [refusedSubagent])
            state.sheetToggle("codex")
            await state.confirmSheet()?.value
        }
    }

    static let refusedSkill = "skill::changelog-writer"
    static let refusedSubagent = "agent::release-captain"

    /// Presses a lit logo of a shared file: it only opens the confirmation.
    private static func ask(_ id: String, cli: String, from anchor: EquipPageState.Anchor, state: EquipPageState) {
        let list = state.list()
        guard let row = list.row(id), let toggle = row.toggles.first(where: { $0.cli.id == cli }) else { return }
        state.press(toggle, on: row, from: anchor)
    }
}
