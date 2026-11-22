import AppKit
import SwiftUI

/// The Skills or Subagents list (RD-R2: first the hero `N never ran`, then the `Never ran` group head with `Select N
/// Suggested` and the rows by Sessions, most first): the hero, then by state the scanning or problem band, the empty state, or
/// the table. Each row is its name, its logo toggles (one per shown CLI, wrapping at 5, RD-R11), the Sessions bar and count, and
/// Last ran. Ticked rows turn the head into `N selected` with `Add to…` and `Remove from…`. The per-CLI sheet is the page's
/// dialog, over the whole window (`EquipSheetDialog`). The reference mock's `pageEquip` (`src/c-inbox-equip.js`).
struct EquipList: View {
    let state: EquipPageState
    @Environment(FrameChrome.self) private var chrome

    var body: some View {
        let list = state.list()
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                // The mock's `.hdr` (4 above, 8 beside, 20 below with the stack's 12), as on every page (RB-F4).
                PageHero(list.heroFigure, label: list.heroLabel)
                    .padding(.top, SpaceRole.step4)
                    .padding(.horizontal, SpaceRole.step8)
                    .padding(.bottom, SpaceRole.step8)
                phaseContent(list)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // ↑↓ select through the page's own `select`, as a click does: the description collapses on another row.
        .frameListKeys(rows: list.visible.map(\.id), router: state.router ?? FrameRouter(), chrome: chrome) { state.select($0) }
        // RD44: the first shown row is selected on opening and whenever the filter, the CLI menu or the search hides the
        // selected one.
        .frameFirstRowSelection(page: list.kind.page, rows: list.visible.map(\.id), router: state.router ?? FrameRouter()) { state.select($0) }
        .onDisappear { state.closeOverlays() }
    }

    @ViewBuilder
    private func phaseContent(_ list: EquipListModel) -> some View {
        switch list.phase {
        case .loading:
            StatusBanner(.scanning(progress: nil), title: EquipListModel.loadingTitle)
        case .failed(let message):
            StatusBanner(.problem(.critical), title: "\(list.kind.plural) could not be read", detail: message) { tryAgain }
        case .empty:
            PageEmptyState(icon: list.kind.page.icon, title: list.emptyTitle, text: list.emptyText) {
                if let folder = firstFolder(list) {
                    Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)]) } label: {
                        PushButtonLabel("Show in Finder", icon: .folderOpen, size: .small)
                    }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
                }
            }
        case .normal:
            if list.isScanning { StatusBanner(.scanning(progress: nil), title: EquipListModel.scanningTitle) }
            ForEach(list.unreadable) { cli in
                StatusBanner(.problem(.attention), title: "\(cli.name) folder could not be read",
                             detail: "\(rootName(cli, list)) could not be read, so every \(cli.name) figure is Unmeasurable here, not zero.") { tryAgain }
            }
            if list.isSearchMiss, let search = state.search {
                FrameSearchNoMatch(items: list.kind.searchItems, search: search)
            } else {
                table(list)
            }
        }
    }

    private var tryAgain: some View {
        Button { Task { await state.store?.refresh(force: true) } } label: { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
            .buttonStyle(PushButtonStyle(.control, size: .small))
            .focusEffectDisabled()
    }

    /// The CLI's folder as the user knows it (`~/.codex`), from the roots `loadout.rows` reports.
    private func rootName(_ cli: CoreRegistryCLI, _ list: EquipListModel) -> String {
        guard let root = list.roots[cli.id] else { return "The \(cli.name) folder" }
        return (root as NSString).abbreviatingWithTildeInPath
    }

    /// The first shown CLI's own folder of the kind, for the empty state's Show in Finder.
    private func firstFolder(_ list: EquipListModel) -> String? {
        let folders = state.store?.snapshot.loadout?.folders ?? []
        for cli in list.clis {
            if let folder = folders.first(where: { $0.ownedBy == cli.id && $0.kind == list.kind.kind && $0.copyTarget }) { return folder.path }
        }
        return nil
    }

    private func table(_ list: EquipListModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            groupHead(list)
            RowGroup {
                EquipTableHeader(list: list, isLegendOpen: Binding(get: { state.isLegendOpen }, set: { state.isLegendOpen = $0 })) {
                    state.toggleAll(list.tickable)
                }
            } content: {
                if list.visible.isEmpty {
                    Text(list.noMatch)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .frame(maxWidth: .infinity, minHeight: SizeRole.tableRow, alignment: .leading)
                        .padding(.horizontal, SpaceRole.step12)
                }
                // The mock's `.tr:nth-child(odd)` inside a `.grp` whose first child is the head line: the 2nd, 4th… row.
                ForEach(Array(list.visible.enumerated()), id: \.element.id) { index, row in
                    rowView(row, list: list).rowStripe(!index.isMultiple(of: 2))
                }
            }
        }
    }

    @ViewBuilder
    private func groupHead(_ list: EquipListModel) -> some View {
        let picked = list.picked
        if !picked.isEmpty {
            GroupHead("\(NumberWording.count(picked.count)) selected") {
                Button("Add to…") { state.openSheet(.add, rows: picked.map(\.id)) }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
                Button("Remove from…") { state.openSheet(.remove, rows: picked.map(\.id)) }
                    .buttonStyle(PushButtonStyle(.destructive, size: .small))
                    .focusEffectDisabled()
            }
        } else if list.showsNeverRanHead {
            GroupHead("Never ran", count: list.neverRan.count, severity: list.neverRanSeverity) {
                if !list.suggested.isEmpty {
                    if list.allSuggestedTicked {
                        ClearSelectionButton { state.selectSuggested() }
                    } else {
                        SelectSuggestedButton(count: list.suggested.count) { state.selectSuggested() }
                    }
                }
            }
        }
    }

    private func rowView(_ row: EquipListRow, list: EquipListModel) -> some View {
        let isSelected = state.router?.route.selection == row.id
        let actions = EquipFrame.actions(for: row, list: list, state: state)
        return ItemRow(label: EquipRowWording.spoken(row, list: list), height: CLIToggleStrip.rowHeight(row.toggles.count),
                       isSelected: isSelected, isKeyboardFocused: chrome.keyboardRow == row.id, select: {
            state.select(row.id)
            chrome.pointerSelected()
            chrome.openInspector()
        }) {
            HStack(spacing: SpaceRole.step12) {
                CheckboxCell(list.view.ticked.contains(row.id) && row.isTickable ? .on : .off, label: "Select \(row.name)") { state.toggle(row.id) }
                    .disabled(!row.isTickable)
                ItemRowTitle(name: row.name, sub: row.subline, icon: list.kind.page.icon, iconInk: list.kind.page.categoryTone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(row.name)
                EquipToggleCell(row: row, state: state)
                SessionsCell(SessionsCell.value(total: row.total, top: list.maxTotal, floor: row.hasUnknown, pending: row.isPending))
                Text(verbatim: row.lastRan ?? "…")
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .lineLimit(1)
                    .frame(width: TableColumnWidth.lastRan, alignment: .leading)
            }
        }
        .frameRowActions(actions)
        .frameSelectedRowActions(isSelected ? actions : nil)
    }
}

/// A row's logo toggles with the shared-file confirmation anchored under the pressed logo (RD-R11 "Shared files").
struct EquipToggleCell: View {
    let row: EquipListRow
    let state: EquipPageState

    var body: some View {
        CLIToggleStrip(states: row.toggles, pending: state.pendingToggles(row)) { toggle in state.press(toggle, on: row, from: .row) }
            .popover(isPresented: isPresented, attachmentAnchor: .rect(.rect(anchor)), arrowEdge: .bottom) { confirmation }
    }

    private var prompt: EquipPageState.SharedPrompt? {
        guard let prompt = state.shared, prompt.anchor == .row, prompt.removal.rowID == row.id else { return nil }
        return prompt
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0, prompt != nil { state.shared = nil } })
    }

    /// The pressed logo's cell inside the strip: 5 per line, 28 each.
    private var anchor: CGRect {
        let index = prompt.flatMap { prompt in row.toggles.firstIndex { $0.cli.id == prompt.removal.cli } } ?? 0
        let columns = CLIToggleStrip.columns(row.toggles.count)
        return CGRect(x: CGFloat(index % columns) * SizeRole.hitCell, y: CGFloat(index / columns) * SizeRole.hitCell,
                      width: SizeRole.hitCell, height: SizeRole.hitCell)
    }

    @ViewBuilder
    private var confirmation: some View {
        if let prompt {
            SharedFileConfirmation(wording: prompt.removal.wording, cancel: { state.shared = nil },
                                   removeForAll: { state.confirmShared(copyFirst: false) },
                                   copyThenRemove: prompt.removal.savable.isEmpty ? nil : { state.confirmShared(copyFirst: true) })
        }
    }
}

/// The table's head line (the mock's `.th`): the select-all box over the rows shown, the kind's word, the CLIs legend button,
/// `Sessions ▾` (the sort, most first) and `Last ran`, each over its column.
struct EquipTableHeader: View {
    let list: EquipListModel
    @Binding var isLegendOpen: Bool
    let toggleAll: () -> Void

    var body: some View {
        let ticked = list.tickable.filter(list.view.ticked.contains).count
        HStack(spacing: SpaceRole.step12) {
            CheckboxCell(CheckboxValue.header(ticked: ticked, total: list.tickable.count), label: "Select all shown rows", toggle: toggleAll)
                .disabled(list.tickable.isEmpty)
            Text(list.kind.noun).frame(maxWidth: .infinity, alignment: .leading)
            CLILegendButton(isOpen: isLegendOpen) { isLegendOpen.toggle() }
                .popover(isPresented: $isLegendOpen, arrowEdge: .bottom) {
                    CLILegend(clis: list.clis.map { CLIIdentity(id: $0.id, name: $0.name) }) { isLegendOpen = false }
                }
                .frame(width: CLIToggleStrip.width(list.clis.count), alignment: .leading)
            HStack(spacing: SpaceRole.step4) {
                Text("Sessions").foregroundStyle(ColorRole.ink)
                FrameGlyph(.caretDown, side: SizeRole.icon12, ink: ColorRole.ink)
            }
            .frame(width: TableColumnWidth.sessions, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sessions, sorted most first")
            Text("Last ran").frame(width: TableColumnWidth.lastRan, alignment: .leading)
        }
        .typeRole(.quiet)
        .foregroundStyle(ColorRole.ink3)
        .lineLimit(1)
        .padding(.horizontal, SpaceRole.step12)
        .frame(height: TableColumnWidth.headerHeight)
    }
}

/// A row's spoken label, pure for the tests.
enum EquipRowWording {
    /// What VoiceOver reads for the row: "pdf-extract, never ran, 0 sessions"; "review-pr, 1,204 sessions, read-only".
    static func spoken(_ row: EquipListRow, list: EquipListModel) -> String {
        var parts = [row.name]
        if row.isPending {
            parts.append("counting sessions")
        } else {
            if row.isNeverRan { parts.append("never ran") }
            parts.append(NumberWording.plural(row.total, "session") + (row.hasUnknown ? " or more" : ""))
        }
        if row.isReadOnly { parts.append("read-only") }
        return parts.joined(separator: ", ")
    }
}
