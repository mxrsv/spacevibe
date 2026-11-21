import SwiftUI

/// The Hooks region of the redesign's frame (RB-R3; RD-R2 Hooks row, RD-R10, RD-R17, RD26): the parts it hands the frame.
/// The list, the toolbar's `All CLIs` menu and `Remove N selected`, and the inspector share the page's one `HooksPageState`.
enum HooksFrame {
    @MainActor
    static func content(model: FrameModel) -> FramePageContent {
        let state = HooksPageState.of(model)
        let list = HooksListModel.from(model.store, view: state.view, query: model.search.query)
        let selected = list.row(model.router.route.selection)
        return FramePageContent(
            subtitle: list.subtitle,
            help: FramePage.hooks.help,
            toolbarControls: list.hasToolbarControls ? AnyView(HooksCLIMenu(model: model, state: state)) : nil,
            // The mock draws no search on the empty page (`mid` is empty there).
            searchItems: list.phase == .empty ? nil : searchItems,
            primary: AnyView(HooksRemoveSelectedButton(model: model, state: state)),
            body: AnyView(HooksList(model: model, state: state)),
            inspector: AnyView(HooksInspector(model: model, state: state)),
            overlayActions: selected.map { AnyView(HooksRowActionButtons(actions: actions(for: $0, state: state), state: state, row: $0)) }
        )
    }

    static let searchItems = "hooks"

    /// A row's actions, one list for its buttons, context menu, accessibility actions and the Item menu (RD-R16): a Claude
    /// Code Hook the page may write gets `Remove from Claude Code`; a project, plugin or Codex Hook gets none.
    @MainActor
    static func actions(for row: HooksListRow, state: HooksPageState) -> [FrameRowAction] {
        guard row.isWritable else { return [] }
        return [FrameRowAction(id: "remove", title: removeTitle, isDestructive: true,
                               isEnabled: !state.isPending(HooksRemoval.control(for: row))) { state.remove(row) }]
    }

    static let removeTitle = "Remove from Claude Code"
    /// The selected project row's action cell (the mock's `Read-only (project)`).
    static let projectReadOnly = "Read-only (project)"

    /// The primary slot's title: what it removes, or what to do first.
    static func removeSelectedTitle(_ count: Int) -> String {
        count > 0 ? "Remove \(NumberWording.count(count)) selected" : "Select rows to remove"
    }
}

/// The toolbar's `Remove N selected` (RD-R17 Layout: one width, the fixed slot): the ticked rows shown, as one write.
struct HooksRemoveSelectedButton: View {
    let model: FrameModel
    let state: HooksPageState

    var body: some View {
        let list = HooksListModel.from(model.store, view: state.view, query: model.search.query)
        if !list.hasRemoveSelected {
            EmptyView()
        } else {
            let rows = list.removal
            Button { state.removeSelected(rows) } label: {
                PushButtonLabel(HooksFrame.removeSelectedTitle(rows.count), icon: .trash)
                    .lineLimit(1)
            }
            .buttonStyle(PushButtonStyle(.destructive, isLoading: state.isPending(HooksRemoval.selectedControl)))
            .focusEffectDisabled()
            .disabled(rows.isEmpty)
            .help(HooksFrame.removeSelectedTitle(rows.count))
        }
    }
}

/// The toolbar's `All CLIs` pop-up (RD-R10 Toolbar): every shown CLI in the fixed order, a CLI without Hooks listed disabled
/// as Not supported. Picking one shows only its Hooks and clears the ticks.
struct HooksCLIMenu: View {
    let model: FrameModel
    let state: HooksPageState

    var body: some View {
        @Bindable var state = state
        let list = HooksListModel.from(model.store, view: state.view, query: model.search.query)
        let chosen = list.cliOptions.first { $0.cli.id == state.view.cli }?.cli
        MenuTrigger(title: CLIMenuEntries.scopeTitle(list.cliOptions, scope: state.view.cli), lead: chosen.map { .cli($0) } ?? .none,
                    isOpen: state.isCLIMenuOpen, label: "CLIs shown") { state.isCLIMenuOpen.toggle() }
            .help("Choose the CLIs these lists cover")
            .popover(isPresented: $state.isCLIMenuOpen, arrowEdge: .bottom) {
                MenuPanel(heading: CLIMenuEntries.scopeHeading, entries: CLIMenuEntries.scope(list.cliOptions, scope: state.view.cli),
                          footnote: CLIMenuEntries.scopeFootnote,
                          pick: { id in state.filter(cli: id == CLIMenuEntries.allID ? nil : id) },
                          close: { state.isCLIMenuOpen = false })
            }
    }
}

/// A row's action buttons, drawn from its one action list, with the write's pending state at the button (FE-L2). On the
/// selected row and at the top of the overlay inspector.
struct HooksRowActionButtons: View {
    let actions: [FrameRowAction]
    let state: HooksPageState
    let row: HooksListRow

    var body: some View {
        if actions.isEmpty, case .project = row.readOnly {
            Text(HooksFrame.projectReadOnly)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .lineLimit(1)
        }
        ForEach(actions) { action in
            Button(action.title) { action.perform() }
                .buttonStyle(PushButtonStyle(action.buttonKind, size: .small,
                                             isLoading: state.isPending(HooksRemoval.control(for: row))))
                .focusEffectDisabled()
                .disabled(!action.isEnabled)
                .help(action.tooltip)
        }
    }
}
