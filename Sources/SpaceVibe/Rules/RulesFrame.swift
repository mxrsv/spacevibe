import SwiftUI

/// The Rules region of the redesign's frame (RB-R4; RD-R10 Rules, RD26, RD-R2 Rules row, RD-R17 Honesty): the parts it hands
/// the frame. A CLI pop-up picks the page: Claude Code's is editable (grid, rules, inspector, `Add Rule…`), every other
/// CLI's is read only in its own terms and has no inspector. The views share the page's one `RulesPageState`.
enum RulesFrame {
    @MainActor
    static func content(model: FrameModel) -> FramePageContent {
        let state = RulesPageState.of(model)
        let list = RulesListModel.from(model.store, view: state.view, file: model.router.route.scope)
        let controls = AnyView(RulesToolbarControls(model: model, state: state))
        guard list.isClaudePage else {
            return FramePageContent(help: FramePage.rules.help, toolbarControls: controls,
                                    body: AnyView(RulesReadOnlyList(model: model, state: state)))
        }
        let selected = list.row(model.router.route.selection)
        return FramePageContent(
            help: FramePage.rules.help,
            toolbarControls: controls,
            primary: AnyView(RulesPrimaryButton(model: model, state: state)),
            body: AnyView(RulesList(model: model, state: state)),
            inspector: AnyView(RulesInspector(model: model, state: state)),
            overlayActions: selected.map { row in
                AnyView(RulesRowActionButtons(actions: actions(for: row, list: list, state: state), state: state, file: list.file))
            }
        )
    }

    static let changeToAskTitle = "Change to Ask"
    static let removeTitle = "Remove Rule"
    static let addTitle = "Add Rule\u{2026}"

    /// A row's actions, one list for its context menu, accessibility actions, the Item menu and the inspector (RD-R16): a
    /// whole-tool allow gets `Change to Ask` first; every rule of a file the page may write gets `Remove Rule`, red on a
    /// whole-tool allow (the mock's `rbtn('Remove Rule', { d: w })`). A file that cannot be read gets none.
    @MainActor
    static func actions(for row: RulesRuleRow, list: RulesListModel, state: RulesPageState) -> [FrameRowAction] {
        guard list.isWritable else { return [] }
        let pending = state.isPending(RulesPageState.removeControl(list.file))
        var out: [FrameRowAction] = []
        if row.isWideAllow {
            out.append(FrameRowAction(id: "changeToAsk", title: changeToAskTitle) { state.change(row.rule, to: .ask, fileName: list.fileName) })
        }
        out.append(FrameRowAction(id: "remove", title: removeTitle, isDestructive: row.isWideAllow, isEnabled: !pending) {
            state.remove(row.rule, fileName: list.fileName)
        })
        return out
    }

    /// The buttons the selected row draws in its 172 action cell: `Remove Rule` only, as in the mock; `Change to Ask` sits in
    /// the inspector, the context menu and the Item menu, where it fits.
    static func rowButtons(_ actions: [FrameRowAction]) -> [FrameRowAction] { actions.filter { $0.id == "remove" } }

    static func removeSelectedTitle(_ count: Int) -> String { "Remove \(NumberWording.count(count)) selected" }
}

/// The toolbar's controls (the mock's `rulesCliBtn`, `segCtl('rules', …)`): the CLI pop-up, and on Claude Code's page the
/// Global / Project switch.
struct RulesToolbarControls: View {
    let model: FrameModel
    let state: RulesPageState

    var body: some View {
        @Bindable var state = state
        let list = RulesListModel.from(model.store, view: state.view, file: model.router.route.scope)
        HStack(spacing: SpaceRole.step8) {
            MenuTrigger(title: list.cli.name, lead: .cli(CLIIdentity(id: list.cli.id, name: list.cli.name)), isOpen: state.isCLIMenuOpen,
                        label: "CLI") { state.isCLIMenuOpen.toggle() }
                .help("Choose the CLI")
                .popover(isPresented: $state.isCLIMenuOpen, arrowEdge: .bottom) {
                    MenuPanel(entries: CLIMenuEntries.picker(list.cliOptions, chosen: list.cli.id),
                              pick: { state.pick(cli: $0) }, close: { state.isCLIMenuOpen = false })
                }
            if list.isClaudePage {
                FrameSegmentedControl(segments: Self.scopes, selection: list.isGlobal ? Self.global : Self.project, label: "Rules scope") { id in
                    state.pick(scopeIsProject: id == Self.project, projects: list.projects)
                }
            }
        }
    }

    static let global = "global", project = "project"
    static let scopes = [FrameSegment(id: global, title: "Global"), FrameSegment(id: project, title: "Project")]
}

/// The toolbar's fixed slot: `Add Rule…`, the page's one primary in `#0B6FE4` (RD11), or `Remove N selected` once rules are
/// ticked (destructive, never primary, RD-R9).
struct RulesPrimaryButton: View {
    let model: FrameModel
    let state: RulesPageState

    var body: some View {
        let list = RulesListModel.from(model.store, view: state.view, file: model.router.route.scope)
        switch list.primary {
        case .none:
            EmptyView()
        case .addRule:
            Button { state.openAdd() } label: { PushButtonLabel(RulesFrame.addTitle, icon: .plus).lineLimit(1) }
                .buttonStyle(PushButtonStyle(.primary))
                .focusEffectDisabled()
                .disabled(state.addDraft != nil)
                .help("Add an Allow, Ask or Deny rule to \(list.fileName)")
        case .removeSelected(let count):
            Button { state.removeSelected(list.removal, fileName: list.fileName) } label: {
                PushButtonLabel(RulesFrame.removeSelectedTitle(count), icon: .trash).lineLimit(1)
            }
            .buttonStyle(PushButtonStyle(.destructive, isLoading: state.isPending(RulesPageState.removeControl(list.file))))
            .focusEffectDisabled()
            .help(RulesFrame.removeSelectedTitle(count))
        }
    }
}

/// The selected row's buttons, with the write's pending state at the button (FE-L2): in the row's action cell and at the
/// top of the overlay inspector.
struct RulesRowActionButtons: View {
    let actions: [FrameRowAction]
    let state: RulesPageState
    let file: FrameScope

    var body: some View {
        ForEach(RulesFrame.rowButtons(actions)) { action in
            Button(action.title) { action.perform() }
                .buttonStyle(PushButtonStyle(action.buttonKind, size: .small,
                                             isLoading: state.isPending(RulesPageState.removeControl(file))))
                .focusEffectDisabled()
                .disabled(!action.isEnabled)
                .help(action.tooltip)
        }
    }
}
