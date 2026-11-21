import SwiftUI

/// The Skills and Subagents regions of the redesign's frame (RB-R2; RD14–RD16, RD21/D53, RD31, RD-R11, RD-R12, RD-R13, RD-A6;
/// the mock's `pageEquip`, `src/c-inbox-equip.js`): the parts one page hands the frame. Both pages are this one implementation
/// with their `EquipKind` (`SkillsFrame`, `SubagentsFrame`). The list, the toolbar's `All / Never ran` control, `All CLIs` menu
/// and `Remove N selected…`, and the inspector share the page's one `EquipPageState`.
enum EquipFrame {
    @MainActor
    static func content(_ kind: EquipKind, model: FrameModel) -> FramePageContent {
        let state = EquipPageState.of(model, kind: kind)
        let list = state.list()
        return FramePageContent(
            help: kind.page.help,
            toolbarControls: list.phase == .empty ? nil : AnyView(EquipToolbarControls(state: state)),
            primary: AnyView(EquipRemoveSelectedButton(state: state)),
            body: AnyView(EquipList(state: state)),
            inspector: AnyView(EquipInspector(state: state)),
            // The rows draw no action buttons (their logos are the actions, as the mock's), so the overlay repeats none.
            overlayActions: nil)
    }

    /// A row's actions as its context-menu items, accessibility actions and the Item menu (RD-R16): `Add to…` and `Remove…`
    /// open the per-CLI sheet for that row. A plugin or project row has none: it is read-only.
    @MainActor
    static func actions(for row: EquipListRow, list: EquipListModel, state: EquipPageState) -> [FrameRowAction] {
        guard list.canRemove(row) else { return [] }
        let busy = state.isPending(EquipControl.sheet(list.kind.page))
        return [
            FrameRowAction(id: "addTo", title: "Add to…", isEnabled: !busy) { state.openSheet(.add, rows: [row.id]) },
            FrameRowAction(id: "remove", title: "Remove…", isDestructive: true, isEnabled: !busy) { state.openSheet(.remove, rows: [row.id]) },
        ]
    }
}

/// The toolbar's own controls (the mock's `mid`): `All / Never ran` and the `All CLIs` menu (RD22, RD-R10 Toolbar).
struct EquipToolbarControls: View {
    let state: EquipPageState

    var body: some View {
        @Bindable var state = state
        let list = state.list()
        let options = list.clis.map { CLIMenuEntries.Option(cli: CLIIdentity(id: $0.id, name: $0.name), isSupported: $0.supports.supports(list.kind.kind)) }
        let chosen = options.first { $0.cli.id == state.view.cli }?.cli
        HStack(spacing: SpaceRole.step8) {
            FrameSegmentedControl(segments: EquipFilter.allCases.map { FrameSegment(id: $0.rawValue, title: $0.title) },
                                  selection: state.view.filter.rawValue, label: "\(list.kind.plural) shown") { id in
                if let filter = EquipFilter(rawValue: id) { state.filter(filter) }
            }
            MenuTrigger(title: CLIMenuEntries.scopeTitle(options, scope: state.view.cli), lead: chosen.map { .cli($0) } ?? .none,
                        isOpen: state.isCLIMenuOpen, label: "CLIs shown") { state.isCLIMenuOpen.toggle() }
                .help("Choose the CLIs these lists cover")
                .popover(isPresented: $state.isCLIMenuOpen, arrowEdge: .bottom) {
                    MenuPanel(heading: CLIMenuEntries.scopeHeading, entries: CLIMenuEntries.scope(options, scope: state.view.cli),
                              footnote: CLIMenuEntries.scopeFootnote,
                              pick: { id in state.scope(id == CLIMenuEntries.allID ? nil : id) },
                              close: { state.isCLIMenuOpen = false })
                }
        }
        .disabled(state.sheet != nil)
    }
}

/// The toolbar's destructive slot (RD-R17 Layout: one width): `Remove N selected…` opens the per-CLI sheet for the ticked
/// rows shown, so it names who loses them before anything is written (the mock's `dstBtn(… 'bkopen')`); empty while the
/// first scan runs or the page is empty, so the controls beside it never move.
struct EquipRemoveSelectedButton: View {
    let state: EquipPageState

    var body: some View {
        let list = state.list()
        if let title = list.primaryTitle {
            Button { state.openSheet(.remove, rows: list.picked.map(\.id)) } label: {
                PushButtonLabel(title, icon: .trash).lineLimit(1)
            }
            .buttonStyle(PushButtonStyle(.destructive, isLoading: state.isPending(EquipControl.sheet(list.kind.page))))
            .focusEffectDisabled()
            .disabled(list.picked.isEmpty || state.sheet != nil)
            .help(title)
        } else {
            Color.clear.accessibilityHidden(true)
        }
    }
}
