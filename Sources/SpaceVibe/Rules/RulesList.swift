import SwiftUI

/// Claude Code's Rules page (RD-R2: first the hero `N rules allow a whole tool`, then the other CLIs' lines beside it): the
/// hero and the strip, on Project the project and file bar, then by phase the reading band, the problem band, the empty
/// state, or the Capabilities grid and the Rules table. The reference mock's `pageRules` (`src/d-hooks-rules.js`). The
/// capability preview is drawn by the frame's overlay host, and the Add Rule sheet is the page's dialog (`RulesFrame`).
struct RulesList: View {
    let model: FrameModel
    let state: RulesPageState
    @Environment(FrameChrome.self) private var chrome

    var body: some View {
        let list = RulesListModel.from(model.store, view: state.view, file: model.router.route.scope, query: model.search.query)
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                RulesHeader(list: list) { state.isCLIMenuOpen = true }
                if !list.isGlobal, list.phase != .noProjects { RulesScopeBar(list: list, state: state) }
                phaseContent(list)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frameListKeys(rows: list.rows.map(\.id), router: model.router, chrome: chrome)
        // RD44: the first rule is selected on opening and whenever the scope, the file or the search hides the selected one.
        .frameFirstRowSelection(page: .rules, rows: list.rows.map(\.id), router: model.router)
    }

    @ViewBuilder
    private func phaseContent(_ list: RulesListModel) -> some View {
        switch list.phase {
        case .loading:
            StatusBanner(.scanning(progress: nil), title: "Reading \(list.fileName)\u{2026}")
            RowGroup { SkeletonRows(count: Self.skeletonRows) }
        case .failed(let message):
            StatusBanner(.problem(.critical), title: "Rules could not be read", detail: message) { RulesTryAgain(model: model) }
        case .noProjects:
            PageEmptyState(icon: .folderSimple, title: "No projects yet",
                           text: "Claude Code lists no project folder yet. A project shows here once Claude Code has run in it.")
        case .projectGone:
            PageEmptyState(icon: .folderSimple, title: "Project not found",
                           text: "Claude Code no longer lists this folder. Pick another project or Global.")
        case .empty:
            problemBand(list)
            PageEmptyState(icon: .rules, title: "No Rules in this scope",
                           text: "Without a Rule Claude Code asks before each risky step. Add an Allow, Ask or Deny entry.") {
                Button { state.openAdd() } label: { PushButtonLabel(RulesFrame.addTitle, icon: .plus, size: .small) }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
                    .disabled(!list.isWritable)
            }
        case .normal:
            problemBand(list)
            VStack(alignment: .leading, spacing: 0) {
                GroupHead("Capabilities")
                RulesCapabilityGrid(list: list, state: state)
                GroupHead("Rules")
                if list.isSearchMiss {
                    FrameSearchNoMatch(items: RulesFrame.searchItems, search: model.search)
                } else {
                    table(list)
                }
            }
        }
    }

    /// The file cannot be read or does not parse (mock "not shown"): the grid and the list are read only, with Try Again.
    @ViewBuilder
    private func problemBand(_ list: RulesListModel) -> some View {
        if let problem = list.problem {
            StatusBanner(.problem(.attention), title: "\(list.fileName) can\u{2019}t be changed here", detail: problem) { RulesTryAgain(model: model) }
        }
    }

    static let skeletonRows = 6

    private func table(_ list: RulesListModel) -> some View {
        let ids = list.rows.map(\.id)
        let ticked = ids.filter(list.ticked.contains).count
        // The head row stays pinned while the rules scroll under it (the mock's sticky `.th`).
        return RowGroup {
            HStack(spacing: SpaceRole.step12) {
                CheckboxCell(.header(ticked: ticked, total: ids.count), label: "Select every Rule shown") { state.toggleAll(ids) }
                    .disabled(ids.isEmpty || !list.isWritable)
                HStack(spacing: SpaceRole.step4) {
                    caption("Rule")
                    FrameGlyph(.arrowUp, side: SizeRole.icon12, ink: ColorRole.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rule, sorted A to Z")
                caption("Permission").frame(width: TableColumnWidth.permission, alignment: .leading)
                caption("Action").frame(width: TableColumnWidth.action, alignment: .trailing)
            }
            .padding(.horizontal, SpaceRole.step12)
            .frame(height: TableColumnWidth.headerHeight)
        } content: {
            ForEach(Array(list.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row, list: list).rowStripe(RulesListModel.isStriped(index))
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1)
    }

    private func rowView(_ row: RulesRuleRow, list: RulesListModel) -> some View {
        let isSelected = model.router.route.selection == row.id
        let actions = RulesFrame.actions(for: row, list: list, state: state)
        let label = "\(row.rule.rule), \(PermissionDial.title(row.rule.verdict))\(row.isWideAllow ? ", whole tool" : "")"
        return ItemRow(label: label, isSelected: isSelected, isKeyboardFocused: chrome.keyboardRow == row.id, select: {
            model.router.select(row.id)
            chrome.pointerSelected()
            chrome.openInspector()
        }) {
            HStack(spacing: SpaceRole.step12) {
                CheckboxCell(list.ticked.contains(row.id) ? .on : .off, label: "Select \(row.rule.rule)") { state.toggle(row.id) }
                    .disabled(!list.isWritable)
                HStack(spacing: SpaceRole.step8) {
                    MiddleTruncatedText(row.rule.rule)
                        .typeRole(.mono)
                        .foregroundStyle(ColorRole.ink)
                        .help(row.rule.rule)
                    if row.isWideAllow {
                        LabelChip("Whole tool", icon: .warningFill, iconInk: ColorRole.stateAttention)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: SpaceRole.step6) {
                    FrameGlyph(row.permissionIcon, side: SizeRole.icon14, ink: ColorRole.ink2)
                    Text(PermissionDial.title(row.rule.verdict)).typeRole(.quiet).foregroundStyle(ColorRole.ink2).lineLimit(1)
                }
                .frame(width: TableColumnWidth.permission, alignment: .leading)
            }
        } actions: {
            // The action column keeps its room on every row (`ItemRow(actions:)`), so selecting one moves nothing (FE-L1).
            RulesRowActionButtons(actions: actions, state: state, file: list.file)
        }
        .frameRowActions(actions)
        .frameSelectedRowActions(isSelected ? actions : nil)
    }
}

/// The hero and, beside it, the other CLIs' lines (the mock's `.hdr` and `.band`): at most three, then `+N more CLIs`,
/// which opens the CLI pop-up.
struct RulesHeader: View {
    let list: RulesListModel
    let openMore: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: SpaceRole.step24) {
            PageHero(list.hero, label: list.heroLabel)
                .fixedSize()
            if !list.shownSummaries.isEmpty {
                VStack(alignment: .leading, spacing: SpaceRole.step6) {
                    ForEach(list.shownSummaries) { other in
                        HStack(spacing: SpaceRole.step8) {
                            CLILogo(CLIIdentity(id: other.cli.id, name: other.cli.name), size: SizeRole.logo16)
                            Text(other.cli.name).foregroundStyle(ColorRole.ink2).lineLimit(1).fixedSize()
                            Text(other.line).foregroundStyle(ColorRole.ink3).lineLimit(1).truncationMode(.tail)
                        }
                        .typeRole(.quiet)
                        .accessibilityElement(children: .combine)
                    }
                    if list.hiddenSummaryCount > 0 {
                        Button("+\(NumberWording.plural(list.hiddenSummaryCount, "more CLI"))", action: openMore)
                            .buttonStyle(PushButtonStyle(.quiet, size: .small))
                            .focusEffectDisabled()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, SpaceRole.step4)
            }
        }
        .padding(.top, SpaceRole.step4)
        .padding(.horizontal, SpaceRole.step8)
        .padding(.bottom, SpaceRole.step8)
    }
}

/// Rules › Project's bar (the mock's `scopeBar`): the project menu, Shared / Local, and the file it reads and writes.
struct RulesScopeBar: View {
    let list: RulesListModel
    let state: RulesPageState

    var body: some View {
        @Bindable var state = state
        HStack(spacing: SpaceRole.step8) {
            MenuTrigger(title: list.project?.name ?? "Project", lead: .icon(.folderSimple), isOpen: state.isProjectMenuOpen,
                        label: "Project") { state.isProjectMenuOpen.toggle() }
                .help(list.project?.dir ?? "Choose the project")
                .popover(isPresented: $state.isProjectMenuOpen, arrowEdge: .bottom) {
                    MenuPanel(entries: CLIMenuEntries.projects(list.projects.map { CLIMenuEntries.Project(name: $0.name, path: Self.path($0.dir)) },
                                                               chosen: list.project?.name),
                              pick: { name in if let dir = list.projects.first(where: { $0.name == name })?.dir { state.pick(project: dir) } },
                              close: { state.isProjectMenuOpen = false })
                }
            FrameSegmentedControl(segments: Self.files, selection: list.file.scope == .local ? Self.local : Self.shared, label: "Settings file") {
                state.pick(local: $0 == Self.local)
            }
            Spacer(minLength: SpaceRole.step8)
            MiddleTruncatedText(list.fileName)
                .typeRole(.mono)
                .foregroundStyle(ColorRole.ink3)
                .help(list.project.map { "\(Self.path($0.dir))/.claude/settings\(list.file.scope == .local ? ".local" : "").json" } ?? list.fileName)
        }
        .padding(.top, SpaceRole.step4)
        .padding(.horizontal, SpaceRole.step8)
    }

    static let shared = "shared", local = "local"
    static let files = [FrameSegment(id: shared, title: "Shared"), FrameSegment(id: local, title: "Local")]

    /// A folder as the user knows it (`~/Development/payments-web`).
    static func path(_ dir: String) -> String { (dir as NSString).abbreviatingWithTildeInPath }
}

/// `Try Again`: every source read again (⌘R).
struct RulesTryAgain: View {
    let model: FrameModel

    var body: some View {
        Button { Task { await model.store.refresh(force: true) } } label: { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
            .buttonStyle(PushButtonStyle(.control, size: .small))
            .focusEffectDisabled()
    }
}
