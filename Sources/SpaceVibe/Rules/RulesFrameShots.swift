import SwiftUI

/// The redesign's Rules shots (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=rules`): every page state of RD-R13 from the
/// in-memory engine `RulesShotCore`, in both looks and appearances, beside the mock's same state
/// (`mock.html?page=rules&state=<state>`). Files are `frame-rules-<name>-<look>-<appearance>.png`:
///
/// - `normal`, `normal-1000`, `normal-1600`, `selected` (the whole-tool `Bash` and its inspector), `ticked` (two rules:
///   `Remove 2 selected`), `project` (payments-web's Local file), `many` (10 CLIs: the strip and `+N more CLIs`);
/// - `dialog` (the preview Push and deploy → Deny, the mock's `dialog`), `nothing` (a same-value press: "Nothing to change"),
///   `add` (the Add Rule sheet with a draft), `add-refused` (the shape refused next to the field);
/// - `codex` (Codex read only in its own terms), `codex-error` (`config.toml` unreadable), `other` (a CLI with no reading:
///   Unmeasurable);
/// - `empty`, `scanning`, `failed`, `problem` (settings.json does not parse: read only), `no-projects`, `worst`;
/// - `write` (Bash changed to Ask: the toast with Undo), `refused` (the core's refusal toast).
@MainActor
enum RulesFrameShots {
    struct Shot {
        let name: String
        let scenario: RulesShotCore.Scenario
        var width: CGFloat = 1280
        var prepare: @MainActor (FrameModel, RulesPageState) async -> Void = { _, _ in }
    }

    static let bash = "global:allow:Bash"

    static let shots: [Shot] = [
        Shot(name: "normal", scenario: .normal),
        Shot(name: "normal-1000", scenario: .normal, width: 1000),
        Shot(name: "normal-1600", scenario: .normal, width: 1600),
        Shot(name: "selected", scenario: .normal) { model, _ in model.router.select(bash) },
        Shot(name: "ticked", scenario: .normal) { _, state in
            state.toggle(bash)
            state.toggle("global:deny:Bash(rm -rf:*)")
        },
        Shot(name: "project", scenario: .normal) { model, state in
            state.pick(scopeIsProject: true, projects: RulesShotCore.projects)
            state.pick(local: true)
            await reread(model)
        },
        Shot(name: "many", scenario: .many),
        Shot(name: "dialog", scenario: .normal) { model, state in await preview(.push, to: .deny, model: model, state: state) },
        Shot(name: "nothing", scenario: .normal) { model, state in await preview(.push, to: .ask, model: model, state: state) },
        Shot(name: "add", scenario: .normal) { _, state in
            state.openAdd()
            state.addDraft?.text = "Bash(git log:*)"
        },
        Shot(name: "add-refused", scenario: .normal) { _, state in
            state.openAdd()
            state.addDraft?.text = "Bash(git log:*"
            state.submitAdd(fileName: "~/.claude/settings.json")
            try? await Task.sleep(for: .milliseconds(50))
        },
        Shot(name: "codex", scenario: .normal) { _, state in state.pick(cli: RulesReadOnlyPage.codexID) },
        Shot(name: "codex-error", scenario: .codexError) { _, state in state.pick(cli: RulesReadOnlyPage.codexID) },
        Shot(name: "other", scenario: .many) { _, state in state.pick(cli: "cli2") },
        Shot(name: "empty", scenario: .empty),
        Shot(name: "scanning", scenario: .scanning),
        Shot(name: "failed", scenario: .failed),
        Shot(name: "problem", scenario: .problem),
        Shot(name: "no-projects", scenario: .noProjects) { _, state in state.pick(scopeIsProject: true, projects: []) },
        Shot(name: "worst", scenario: .worst),
        Shot(name: "write", scenario: .normal) { model, state in await change(model: model, state: state) },
        Shot(name: "refused", scenario: .refused) { model, state in await change(model: model, state: state) },
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
        let core = RulesShotCore(shot.scenario)
        let toasts = ToastCenter(announce: false)
        let env = AppEnvironment(toasts: toasts, makeCoreClient: { core })
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: .rules))
        let state = RulesPageState.of(model)
        // `ImageRenderer` runs no `.task`: the store is started here and the run loop spun until it has read.
        var ready = false
        Task { @MainActor in
            Task { await model.store.start() }
            try? await Task.sleep(for: .milliseconds(1))
            await waitForReads(model)
            await shot.prepare(model, state)
            ready = true
        }
        try ShotHarness.wait("the Rules shot \(shot.name)") { ready }
        let view = AppFrame(page: .rules, env: env, look: look, sidebarValues: .from(model.store)) { _, _ in RulesFrame.content(model: model) }
            .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)), toasts: toasts, env: env)
            .frame(width: shot.width, height: ShotRenderer.size.height)
        try ShotRenderer.write(view, name: "frame-rules-\(shot.name)-\(look)", choice: choice, to: directory)
    }

    /// Until the global file answered or failed (a scanning core never answers, so it is not waited for long).
    private static func waitForReads(_ model: FrameModel) async {
        for _ in 0..<200 {
            if let state = model.store.states[.rules(.global)], state != .loading { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private static func reread(_ model: FrameModel) async {
        await model.store.reread([.rules(model.router.route.scope)])
    }

    private static func preview(_ capability: CoreCapability, to verdict: CoreVerdict, model: FrameModel, state: RulesPageState) async {
        guard let row = state.list()?.capabilities.first(where: { $0.id == capability }) else { return }
        state.requestPreview(row, to: verdict)
        for _ in 0..<100 where state.preview?.phase == .loading { try? await Task.sleep(for: .milliseconds(10)) }
    }

    private static func change(model: FrameModel, state: RulesPageState) async {
        model.router.select(bash)
        guard let rule = state.list()?.row(bash)?.rule else { return }
        await model.writes.perform(.changeVerdict(rule.rule, from: rule.verdict, to: .ask, in: .global,
                                                  label: RulesWriteWording.changed(rule, to: .ask, in: "~/.claude/settings.json")))
    }
}
