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
            // The mock draws no search on the empty page (`mid` is empty there), and a page that read no Hook has nothing to
            // search.
            searchItems: list.hasToolbarControls ? searchItems : nil,
            primary: AnyView(HooksRemoveSelectedButton(model: model, state: state)),
            body: AnyView(HooksList(model: model, state: state)),
            inspector: AnyView(HooksInspector(model: model, state: state)),
            overlayActions: selected.map { AnyView(HooksOverlayActions(state: state, row: $0)) }
        )
    }

    static let searchItems = "hooks"

    /// A row's actions, one list for its buttons, context menu, accessibility actions and the Item menu (RD-R16): a Claude
    /// Code Hook the page may write gets `Remove from Claude Code`; every Hook gets `Copy Command` (⇧⌘C, also the inspector's
    /// button), which writes nothing and says so in a toast.
    @MainActor
    static func actions(for row: HooksListRow, state: HooksPageState, toasts: ToastCenter) -> [FrameRowAction] {
        var out: [FrameRowAction] = []
        if row.isWritable {
            // Red on a dead or Never ran Hook, quiet on one that runs (the mock's `rmBtn(h, !(dead || never))`).
            out.append(FrameRowAction(id: "remove", title: removeTitle, shortcut: .remove, isDestructive: row.isDeadOrNeverRan,
                                      isEnabled: !state.isPending(HooksRemoval.control(for: row))) { state.remove(row) })
        }
        out.append(FrameRowAction(id: copyID, title: copyTitle, shortcut: .copyCommand) { state.copyCommand(row, toasts: toasts) })
        return out
    }

    /// The buttons the selected row draws in its action cell: `Remove from Claude Code` only, as in the mock; `Copy Command`
    /// sits in the inspector, the context menu and the Item menu.
    static func rowButtons(_ actions: [FrameRowAction]) -> [FrameRowAction] { actions.filter { $0.id != copyID } }

    /// A row button's look: the red tint for a destructive action, otherwise the quiet button (the mock's `.rb.q`).
    static func buttonKind(_ action: FrameRowAction) -> PushButtonStyle.Kind { action.isDestructive ? .destructive : .quiet }

    static let removeTitle = "Remove from Claude Code"
    static let copyID = "copyCommand"
    static let copyTitle = "Copy Command"
    /// The selected project row's action cell (the mock's `Read-only (project)`).
    static let projectReadOnly = "Read-only (project)"

    /// The primary slot's title: what it removes, or what to do first. Short enough never to be cut in the 196 slot (RD52:
    /// "Remove 104"); the tooltip and VoiceOver say the whole thing (`removeSelectedHelp`).
    static func removeSelectedTitle(_ count: Int) -> String {
        count > 0 ? "Remove \(NumberWording.count(count))" : "Select rows to remove"
    }

    /// "Remove 104 selected Hooks".
    static func removeSelectedHelp(_ count: Int) -> String {
        count > 0 ? "Remove \(NumberWording.count(count)) selected \(count == 1 ? "Hook" : "Hooks")" : "Select rows to remove"
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
            .help(HooksFrame.removeSelectedHelp(rows.count))
            .accessibilityLabel(HooksFrame.removeSelectedHelp(rows.count))
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
        let buttons = HooksFrame.rowButtons(actions)
        if buttons.isEmpty, case .project = row.readOnly {
            Text(HooksFrame.projectReadOnly)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .lineLimit(1)
        }
        ForEach(buttons) { action in
            Button(action.title) { action.perform() }
                .buttonStyle(PushButtonStyle(HooksFrame.buttonKind(action), size: .small,
                                             isLoading: state.isPending(HooksRemoval.control(for: row))))
                .focusEffectDisabled()
                .disabled(!action.isEnabled)
                .help(action.tooltip)
        }
    }
}

/// The selected row's buttons at the top of the overlay inspector, with the toast centre the copy action needs.
struct HooksOverlayActions: View {
    let state: HooksPageState
    let row: HooksListRow
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        HooksRowActionButtons(actions: HooksFrame.actions(for: row, state: state, toasts: toasts), state: state, row: row)
    }
}
