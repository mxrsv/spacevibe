import AppKit
import SwiftUI

/// The Hooks page's list (RD-R2: first the hero `N dead or never ran`, then the lifecycle strip's red and amber nodes): the
/// hero and the strip, then by state the scanning or problem band, the empty state, or the table grouped by lifecycle stage
/// with the `Dead or never ran` head, and under it the lines naming the CLIs with no Hooks and without Hooks. One CLI per row
/// (RD46). The reference mock's `pageHooks` (`src/d-hooks-rules.js`).
struct HooksList: View {
    let model: FrameModel
    let state: HooksPageState
    @Environment(FrameChrome.self) private var chrome
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.materialLook) private var look

    var body: some View {
        let list = HooksListModel.from(model.store, view: state.view, query: model.search.query)
        // Below the mock's 940 main column (`ctx.wide`: the window less the sidebar and a docked inspector) the Status column
        // folds into the row's sub-line; until the window is measured, the wide layout.
        let foldsStatus = HooksListModel.foldsStatus(
            listWidth: chrome.listWidth(sidebar: FrameRole.sidebarWidth(look), inspector: FramePage.hooks.inspectorWidth.points),
            windowMeasured: chrome.windowWidth > 0)
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                HooksListHeader(list: list) { state.pressNode($0) }
                phaseContent(list, foldsStatus: foldsStatus)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frameListKeys(rows: list.visible.map(\.id), router: model.router, chrome: chrome)
        // RD44: the first shown row is selected on opening and whenever the strip, the CLI menu or the search hides the
        // selected one.
        .frameFirstRowSelection(page: .hooks, rows: list.visible.map(\.id), router: model.router)
    }

    @ViewBuilder
    private func phaseContent(_ list: HooksListModel, foldsStatus: Bool) -> some View {
        switch list.phase {
        case .scanning:
            // The mock's scanning page: the band and skeleton rows; no judged row and no Select Suggested until the runs
            // are counted.
            StatusBanner(.scanning(progress: nil), title: HooksListModel.scanningTitle)
            RowGroup { SkeletonRows(count: HooksListModel.skeletonRows) }
        case .failed(let message):
            StatusBanner(.problem(.critical), title: "Hooks could not be read", detail: message) { tryAgain }
        case .empty:
            PageEmptyState(icon: .hooks, title: HooksListModel.emptyTitle, text: HooksListModel.emptyText)
        case .normal:
            ForEach(list.unreadable) { cli in
                StatusBanner(.problem(.attention), title: "\(cli.name) folder could not be read",
                             detail: "\(rootName(cli)) could not be read, so every \(cli.name) figure is Unmeasurable here, not zero.") { tryAgain }
            }
            if list.isSearchMiss {
                FrameSearchNoMatch(items: HooksFrame.searchItems, search: model.search)
            } else {
                table(list, foldsStatus: foldsStatus)
            }
        }
    }

    private var tryAgain: some View {
        Button { Task { await model.store.refresh(force: true) } } label: { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
            .buttonStyle(PushButtonStyle(.control, size: .small))
            .focusEffectDisabled()
    }

    /// The CLI's folder as the user knows it (`~/.codex`), from the roots `loadout.rows` reports.
    private func rootName(_ cli: CoreRegistryCLI) -> String {
        guard let root = model.store.snapshot.loadout?.roots[cli.id] else { return "The \(cli.name) folder" }
        return (root as NSString).abbreviatingWithTildeInPath
    }

    private func table(_ list: HooksListModel, foldsStatus: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !list.deadOrNeverRan.isEmpty {
                GroupHead("Dead or never ran", count: list.deadOrNeverRan.count, severity: list.deadHeadSeverity) {
                    if !list.suggested.isEmpty {
                        if list.allSuggestedTicked {
                            ClearSelectionButton { state.toggleAll(list.suggested) }
                        } else {
                            SelectSuggestedButton(count: list.suggested.count) { state.toggleAll(list.suggested) }
                        }
                    }
                }
            }
            // The head row stays pinned while the rows scroll under it (the mock's sticky `.th`).
            RowGroup {
                HooksTableHeader(list: list, foldsStatus: foldsStatus) { state.toggleAll(list.tickable) }
            } content: {
                ForEach(list.stripedStages) { stage in
                    Text(verbatim: stage.stage)
                        .typeRole(.quietMedium)
                        .foregroundStyle(ColorRole.ink2)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, SpaceRole.step12)
                        .padding(.horizontal, SpaceRole.step12)
                        .padding(.bottom, SpaceRole.step6)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(stage.rows, id: \.row.id) { line in
                        rowView(line.row, list: list, foldsStatus: foldsStatus).rowStripe(line.isStriped)
                    }
                }
            }
            HooksTableNotes(list: list)
        }
    }

    private func rowView(_ row: HooksListRow, list: HooksListModel, foldsStatus: Bool) -> some View {
        let isSelected = model.router.route.selection == row.id
        let actions = HooksFrame.actions(for: row, state: state, toasts: toasts)
        let holder = list.holder(of: row)
        // The action column keeps its room on every row (`ItemRow(actions:)`), so selecting one moves nothing (FE-L1).
        return ItemRow(label: HooksRowWording.spoken(row, cli: holder?.name), isSelected: isSelected,
                       isKeyboardFocused: chrome.keyboardRow == row.id, select: {
            model.router.select(row.id)
            chrome.pointerSelected()
            chrome.openInspector()
        }) {
            HStack(spacing: SpaceRole.step12) {
                CheckboxCell(list.view.ticked.contains(row.id) ? .on : .off, label: "Select \(row.label)") { state.toggle(row.id) }
                    .disabled(!row.isWritable)
                HooksRowTitle(row: row, foldsStatus: foldsStatus)
                // One CLI per row (RD46): its logo in the fixed 28 column.
                Group {
                    if let holder {
                        CLILogo(CLIIdentity(id: holder.id, name: holder.name), size: SizeRole.logo20).help(holder.name)
                    }
                }
                .frame(width: TableColumnWidth.logo)
                .accessibilityHidden(true)
                RunsCell(row.runs)
                if !foldsStatus {
                    HooksStatusCell(line: row.statusLine)
                        .frame(width: TableColumnWidth.status, alignment: .leading)
                }
            }
        } actions: {
            HooksRowActionButtons(actions: actions, state: state, row: row)
        }
        .frameRowActions(actions)
        .frameSelectedRowActions(isSelected ? actions : nil)
    }
}

/// The hero and the lifecycle strip side by side (the mock's `.hdr`). No strip while the page has no Hook or none could be
/// read.
private struct HooksListHeader: View {
    let list: HooksListModel
    let pick: (String) -> Void

    var body: some View {
        // RD58: the hero at the header's top, the strip on its bottom line.
        PageHeader {
            PageHero(list.hero, label: HooksListModel.heroLabel)
        } band: {
            if !list.nodes.isEmpty {
                LifecycleStrip(nodes: list.nodes, chosen: list.view.event, pick: pick)
                    .padding(.bottom, SpaceRole.step4)
            }
        }
        .padding(.top, SpaceRole.step4)
        .padding(.horizontal, SpaceRole.step8)
        .padding(.bottom, SpaceRole.step8)
    }
}

/// The table's header line: the select-all box over the writable rows shown, then the column names over their columns (the
/// Action caption over `ItemRow`'s fixed action cell).
private struct HooksTableHeader: View {
    let list: HooksListModel
    let foldsStatus: Bool
    let toggleAll: () -> Void

    var body: some View {
        let ticked = list.tickable.filter(list.view.ticked.contains).count
        HStack(spacing: SpaceRole.step12) {
            CheckboxCell(.header(ticked: ticked, total: list.tickable.count), label: "Select every Hook shown", toggle: toggleAll)
                .disabled(list.tickable.isEmpty)
            caption("Command").frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: TableColumnWidth.logo, height: TableColumnWidth.headerHeight)
            caption("Runs").frame(width: TableColumnWidth.runs, alignment: .leading)
            if !foldsStatus { caption("Status").frame(width: TableColumnWidth.status, alignment: .leading) }
            caption("Action").frame(width: TableColumnWidth.action, alignment: .trailing)
        }
        .padding(.horizontal, SpaceRole.step12)
        .frame(height: TableColumnWidth.headerHeight)
    }

    private func caption(_ text: String) -> some View {
        Text(text).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1)
    }
}

/// The row's name (the script it runs, RD-R17) in mono, and under it the quiet sub-line and the full command, cut in the
/// middle with the whole command as the tooltip.
private struct HooksRowTitle: View {
    let row: HooksListRow
    let foldsStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step2) {
            MiddleTruncatedText(row.label)
                .typeRole(.mono)
                .foregroundStyle(ColorRole.ink)
                .help(row.command)
            HStack(spacing: 0) {
                Text(verbatim: "\(row.subLine(foldsStatus: foldsStatus)) · ")
                    .typeRole(.quiet)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                MiddleTruncatedText(row.command)
                    .typeRole(.mono)
            }
            .foregroundStyle(ColorRole.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Status column: a failing or dead Hook leads with its state glyph in its colour (RD-R16), any other state is quiet.
struct HooksStatusCell: View {
    let line: HooksStatusLine

    var body: some View {
        HStack(spacing: SpaceRole.step6) {
            switch line.tone {
            case .critical: FrameGlyph(.xCircleFill, side: SizeRole.icon14, ink: ColorRole.stateCritical, label: "Critical")
            case .attention: FrameGlyph(.warningFill, side: SizeRole.icon14, ink: ColorRole.stateAttention, label: "Needs attention")
            case .quiet: EmptyView()
            }
            Text(line.text)
                .typeRole(.quiet)
                .foregroundStyle(line.tone == .quiet ? ColorRole.ink3 : ColorRole.ink2)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

/// The lines under the table (RD-R10 Pages): SpaceVibe writes Hooks only into Claude Code; the CLIs with Hooks but none
/// installed; the CLIs without command Hooks.
private struct HooksTableNotes: View {
    let list: HooksListModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step6) {
            note(.infoFill, HooksListModel.writesNote)
            if !list.noHooks.isEmpty {
                note(.minus, "No Hooks: \(CLINames.sentence(list.noHooks.map(\.name))).")
            }
            if !list.notSupported.isEmpty {
                note(.minus, "Not supported: \(CLINames.sentence(list.notSupported.map(\.name))) \(list.notSupported.count == 1 ? "has" : "have") no command Hooks.")
            }
        }
        .padding(.top, SpaceRole.step12)
        .padding(.horizontal, SpaceRole.step8)
        .padding(.bottom, SpaceRole.step12)
    }

    private func note(_ icon: FrameIcon, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step8) {
            FrameGlyph(icon, side: SizeRole.icon14, ink: ColorRole.ink3)
            Text(text)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
