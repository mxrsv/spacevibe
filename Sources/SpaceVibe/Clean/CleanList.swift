import SwiftUI

/// The Clean page (RD-R2 Clean, RD-R13; the reference mock's `pageClean`): the hero with the band beside it (the bar of
/// what is selected against what can be cleaned, or the move's progress with Cancel), the problem bands, then the three
/// sections: Skills, Subagents and Hooks; Session logs; Caches. No inspector (RD-R14). The page reads `clean.scan` when it
/// opens (`measure`), never on the frame's timer. A shared-file confirmation is the page's dialog, drawn by the frame over
/// the whole window (`CleanConfirmationDialog`).
struct CleanList: View {
    let page: CleanPage
    let selection: String?
    let state: CleanPageState
    let actions: CleanActions
    /// A shot draws fixed data and reads nothing.
    var measuresOnOpen = true

    @Environment(FrameChrome.self) private var chrome
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        let actions = actions.using(toasts)
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: SpaceRole.step24) {
                    PageHero(page.hero, label: page.heroLabel)
                        .fixedSize()
                    if let move = page.moveBand {
                        CleanMovingBand(band: move, cancel: actions.cancelMove)
                    } else if page.showsBand {
                        CleanBand(share: page.barShare, text: page.barText)
                    }
                }
                .padding(.top, SpaceRole.step4)
                .padding(.horizontal, SpaceRole.step8)
                .padding(.bottom, SpaceRole.step20)
                ForEach(Array(page.banners.enumerated()), id: \.offset) { _, banner in
                    bannerView(banner, actions: actions).padding(.bottom, SpaceRole.step16)
                }
                if page.isTidy {
                    Text(CleanPage.tidyLine)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .padding(.vertical, SpaceRole.step24)
                        .padding(.horizontal, SpaceRole.step8)
                }
                ForEach(page.sections) { section in
                    sectionView(section, actions: actions)
                    if section.section == .logs, let line = page.notOfferedLine { notOffered(line) }
                }
                if let line = page.notOfferedLine, !page.sections.contains(where: { $0.section == .logs }) { notOffered(line) }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frameListKeys(rows: page.order, router: actions.model.router, chrome: chrome)
        .onKeyPress(.space) { actions.toggleSelected() ? .handled : .ignored }
        .task { if measuresOnOpen { await actions.measure() } }
    }

    @ViewBuilder
    private func sectionView(_ section: CleanSectionModel, actions: CleanActions) -> some View {
        GroupHead(section.title) { pick(section, actions: actions) }
        if section.skeletons > 0 {
            SkeletonRows(count: section.skeletons).groupSurface()
        } else {
            VStack(spacing: 0) {
                ForEach(section.rows) { row in
                    CleanRowView(row: row, isTicked: state.ticked.contains(row.id), isSelected: selection == row.id,
                                 isKeyboardFocused: chrome.keyboardRow == row.id, isMoving: page.phase == .moving,
                                 openLock: state.openLock, actions: actions)
                }
            }
            .groupSurface()
        }
    }

    /// `Select N Suggested`, or `Clear Selection` once every suggested row is ticked (the mock's `selgrp`).
    @ViewBuilder
    private func pick(_ section: CleanSectionModel, actions: CleanActions) -> some View {
        switch section.pick {
        case .none:
            EmptyView()
        case .select(let count):
            SelectSuggestedButton(count: count) { actions.pick(section) }
        case .clear:
            ClearSelectionButton { actions.pick(section) }
        }
    }

    private func notOffered(_ line: String) -> some View {
        HStack(spacing: SpaceRole.step8) {
            FrameGlyph(.minus, side: SizeRole.icon14, ink: ColorRole.ink3)
            Text(line)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(line)
        }
        .padding(.top, SpaceRole.step8)
        .padding(.horizontal, SpaceRole.step8)
    }

    @ViewBuilder
    private func bannerView(_ banner: CleanBanner, actions: CleanActions) -> some View {
        if banner.retries {
            StatusBanner(.problem(banner.isCritical ? .critical : .attention), title: banner.title, detail: banner.detail) {
                Button(action: actions.tryAgain) { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
            }
        } else {
            StatusBanner(.problem(.attention), title: banner.title, detail: banner.detail)
        }
    }
}

/// The band beside the hero (the mock's `.band`): one bar of what is selected against what can be cleaned, its figure at
/// one width, and the quiet line that says where things go (RD-R2 second glance; RD-R17: bytes in use are text only).
struct CleanBand: View {
    let share: Double?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step8) {
            HStack(spacing: SpaceRole.step10) {
                ShareMeter(share: share, height: .hero, tone: .data, label: "Selected of what can be cleaned")
                Text(text)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: TableColumnWidth.cleanBandFigure, alignment: .trailing)
            }
            Text(CleanPage.note)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, SpaceRole.step4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The band while a move runs (the mock's moving state): the progress at the control that started it, what moved so far,
/// and Cancel, which stops before the next file.
struct CleanMovingBand: View {
    let band: CleanMoveBand
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step8) {
            HStack(spacing: SpaceRole.step10) {
                ShareMeter(share: band.share, height: .hero, tone: .plain, label: "Moving the selection")
                Text(band.text)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: TableColumnWidth.cleanBandFigure, alignment: .trailing)
            }
            HStack(spacing: SpaceRole.step12) {
                Text(CleanMoveBand.note)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: cancel) { PushButtonLabel(band.isCancelling ? "Cancelling…" : "Cancel", icon: .x, size: .small) }
                    .buttonStyle(PushButtonStyle(.control, size: .small, isLoading: band.isCancelling))
                    .focusEffectDisabled()
                    .disabled(band.isCancelling)
            }
        }
        .padding(.bottom, SpaceRole.step4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
