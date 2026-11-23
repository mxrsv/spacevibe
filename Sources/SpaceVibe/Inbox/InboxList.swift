import SwiftUI

/// The Inbox list (RD-R4, RD-R13; the reference mock's `pageInbox`): the hero, the scanning or problem band, the groups by job
/// with severity once at each head, the Balance and kept lines, and the kept group while shown. The shared-file confirmation
/// is the page's dialog, which the frame draws over the whole window (`InboxConfirmationDialog`).
struct InboxList: View {
    let page: InboxPage
    let selection: String?
    let state: InboxPageState
    let actions: InboxActions

    @Environment(FrameChrome.self) private var chrome
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.materialLook) private var look

    var body: some View {
        let actions = actions.using(toasts)
        let evidence = FindingRowLayout.showsEvidence(chrome: chrome, look: look)
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHero(page.hero, label: page.heroLabel)
                    .padding(.top, SpaceRole.step4)
                    .padding(.horizontal, SpaceRole.step8)
                    .padding(.bottom, SpaceRole.step20)
                if let banner = page.banner { bannerView(banner, actions: actions).padding(.bottom, SpaceRole.step16) }
                if page.banner == .scanning {
                    RowGroup { SkeletonRows(count: 6) }
                }
                if page.isSearchMiss {
                    FrameSearchNoMatch(items: InboxPage.searchItems, search: actions.model.search)
                }
                if page.showsList {
                    if page.isClear {
                        Text("New findings land here.")
                            .typeRole(.quiet)
                            .foregroundStyle(ColorRole.ink3)
                            .padding(.vertical, SpaceRole.step24)
                            .padding(.horizontal, SpaceRole.step8)
                    }
                    ForEach(page.groups) { group in
                        GroupHead(group.title, count: group.rows.count, severity: group.severity) {
                            if !group.suggested.isEmpty { pick(group.suggested) }
                        }
                        RowGroup { rows(group.rows, evidence: evidence, actions: actions) }
                    }
                    lines
                    if page.showsKept {
                        GroupHead("Kept", count: page.kept.count)
                        RowGroup { rows(page.kept, evidence: evidence, actions: actions) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frameListKeys(rows: page.order, router: actions.model.router, chrome: chrome)
        // RD44: the first shown row is selected on opening and whenever the search, Keep or a removal hides the selected one.
        .frameFirstRowSelection(page: .inbox, rows: page.order, router: actions.model.router)
        .onKeyPress(.space) { actions.toggleTick(actions.model.router.route.selection) ? .handled : .ignored }
    }

    /// A group's rows, every other one on the zebra step (the mock's `.tr:nth-child(odd)`).
    private func rows(_ rows: [InboxRowModel], evidence: Bool, actions: InboxActions) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            rowView(row, evidence: evidence, actions: actions).rowStripe(index.isMultiple(of: 2))
        }
    }

    private func rowView(_ row: InboxRowModel, evidence: Bool, actions: InboxActions) -> some View {
        let isSelected = selection == row.id
        let list = actions.rowActions(row)
        let check = row.isRemovable
            ? ItemRow<FindingRowContent<FrameRowActionButtons>, EmptyView>.Check(
                value: state.ticked.contains(row.id) ? .on : .off, label: "Select \(row.title)", toggle: { state.toggleTick(row.id) })
            : nil
        return ItemRow(label: "\(row.title), \(row.sub), \(row.evidence)", isSelected: isSelected,
                       isKeyboardFocused: chrome.keyboardRow == row.id, check: check, select: {
                           actions.select(row.id)
                           chrome.pointerSelected()
                           chrome.openInspector()
                       }) {
            FindingRowContent(icon: row.glyph.icon, iconInk: row.glyph.ink == .sessionWaiting ? ColorRole.sessionWait : ColorRole.ink3,
                              title: row.title, isMono: row.isMono, sub: row.sub, evidence: evidence ? row.evidence : nil,
                              reservesCheckCell: !row.isRemovable) {
                FrameRowActionButtons(actions: isSelected ? list : [])
            }
        }
        .frameRowActions(list)
        .frameSelectedRowActions(isSelected ? list : nil)
    }

    /// `Select N Suggested`, or `Clear Selection` once every suggested row is ticked (the mock's `selsug`).
    @ViewBuilder
    private func pick(_ ids: [String]) -> some View {
        if ids.allSatisfy(state.ticked.contains) {
            ClearSelectionButton { state.pickSuggested(ids) }
        } else {
            SelectSuggestedButton(count: ids.count) { state.pickSuggested(ids) }
        }
    }

    /// The kept line (the mock's `keptLine`). With fewer than two pins the page has no Balance group and says nothing
    /// about it (RD61).
    @ViewBuilder
    private var lines: some View {
        if !page.kept.isEmpty {
            InboxNoteLine(icon: .pushPin, text: "\(NumberWording.count(page.kept.count)) kept, not counted") {
                Button(state.showsKept ? "Hide" : "Show") { state.showsKept.toggle() }
                    .buttonStyle(PushButtonStyle(.quiet, size: .small))
                    .focusEffectDisabled()
            }
            .padding(.vertical, SpaceRole.step4)
        }
    }

    @ViewBuilder
    private func bannerView(_ banner: InboxBanner, actions: InboxActions) -> some View {
        switch banner {
        case .scanning:
            StatusBanner(.scanning(progress: nil), title: banner.title)
        case .failed:
            StatusBanner(.problem(.critical), title: banner.title, detail: banner.detail) { tryAgain(actions) }
        case .unreadable:
            StatusBanner(.problem(.attention), title: banner.title, detail: banner.detail) { tryAgain(actions) }
        }
    }

    private func tryAgain(_ actions: InboxActions) -> some View {
        Button(action: actions.tryAgain) { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
            .buttonStyle(PushButtonStyle(.control, size: .small))
            .focusEffectDisabled()
    }
}

/// A quiet line under the groups (the mock's `.q2` lines): a 14 pt glyph, the sentence and a quiet button.
struct InboxNoteLine<Action: View>: View {
    let icon: FrameIcon
    let text: String
    @ViewBuilder var action: Action

    init(icon: FrameIcon, text: String, @ViewBuilder action: () -> Action) {
        self.icon = icon
        self.text = text
        self.action = action()
    }

    var body: some View {
        HStack(spacing: SpaceRole.step8) {
            FrameGlyph(icon, side: SizeRole.icon14, ink: ColorRole.ink3)
            Text(text)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .lineLimit(1)
                .truncationMode(.tail)
            action
        }
        .padding(.vertical, SpaceRole.step8)
        .padding(.horizontal, SpaceRole.step8)
    }
}

/// The toolbar's `Remove N` (RD-R2, RD-R17 Layout: one width in the slot): the red tint, never primary (RD-R9), the
/// trash glyph, the real count; disabled with "Select rows to remove" until a row is ticked; pending while the removal runs.
struct InboxRemoveButton: View {
    let page: InboxPage
    let actions: InboxActions
    @Environment(ToastCenter.self) private var toasts
    @Environment(FrameChrome.self) private var chrome
    @Environment(\.materialLook) private var look

    var body: some View {
        let title = page.primary.title(narrow: !FindingRowLayout.showsEvidence(chrome: chrome, look: look)) ?? ""
        let count = page.ticked.count
        Button { actions.using(toasts).removeTicked() } label: { PushButtonLabel(title, icon: .trash) }
            .buttonStyle(PushButtonStyle(.destructive, isLoading: actions.writes.isPending("removeMany")))
            .focusEffectDisabled()
            .disabled(count == 0)
            .help(count == 0 ? "Select rows to remove" : title)
    }
}

extension FindingRowLayout {
    /// Whether the evidence column shows, from the main column's width as the mock measures it (`mw`: the window less the
    /// sidebar and a docked inspector, `FrameChrome.listWidth`), never from the list's own width inside the page padding,
    /// which is 32 pt narrower and loses the column and "Select rows to remove" at 1280 pt.
    @MainActor
    static func showsEvidence(chrome: FrameChrome, look: MaterialLook) -> Bool {
        showsEvidence(listWidth: chrome.listWidth(sidebar: FrameRole.sidebarWidth(look), inspector: FramePage.inbox.inspectorWidth.points))
    }
}
