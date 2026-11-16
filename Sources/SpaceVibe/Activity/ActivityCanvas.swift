import AppKit
import SwiftUI

/// The v5 Activity page (V5-R69 to V5-R71; the `b-activity` mock): the tab head with Running and Failed, and the selected tab's
/// split canvas. No Files tab and no Filter (D70): the lists are already banded and collapsible per CLI. Every sentence and figure
/// is `ActivityAnswers`', every list `ActivityQuery`'s; the cards are `ActivityCards`'. The page's plain keys (V5-R36) are off while
/// the palette or the Stop confirmation holds the keyboard.
struct ActivityCanvas: View {
    static let page = "activity"

    @Bindable var model: ActivityModel

    @Environment(ShellModel.self) private var shell
    @Environment(\.openStateStore) private var store
    @Environment(\.isShotRendering) private var isShotRendering
    /// Whether the window can be seen at all (not minimised, not fully covered or on another Space). Not `scenePhase`: the page
    /// is watched beside a terminal, so the app is rarely frontmost while the window is in view.
    @State private var windowVisible = true

    var body: some View {
        let isActive = shell.activeID == ActivityTab.tabID
        let isPolling = isActive && (windowVisible || isShotRendering)
        // The clock the ages read: the page redraws once a minute, as Limits does.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let query = model.query(at: context.date)
            let visible = Self.visibleIDs(query, pane: model.pane, store: store)
            ZStack(alignment: .topLeading) {
                if !shell.isPaletteOpen && !model.isMenuOpen { keys(query, visible: visible) }
                VStack(spacing: 0) {
                    TabHead {
                        ForEach(ActivityPane.allCases) { pane in
                            TabChip(title: pane.title, glyph: pane.glyph, count: query.isLoading ? nil : query.count(pane), tone: .accent,
                                    isActive: model.pane == pane) { model.select(pane) }
                        }
                    } actions: {}
                    canvas(query, visible: visible, now: context.date)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeOcclusionStateNotification)) { _ in
            windowVisible = NSApp.occlusionState.contains(.visible)
        }
        // Reads while this tab shows in a visible window, and once at launch for the sidebar badge; SwiftUI cancels the task on a
        // tab switch or when the window is hidden.
        .task(id: isPolling) { await model.run(active: isPolling) }
    }

    @ViewBuilder
    private func canvas(_ query: ActivityQuery, visible: [String], now: Date) -> some View {
        if query.isLoading, let failure = model.failure {
            QuietEmptyState("Could not read the session logs", message: failure, placement: .list) {
                Button(action: model.retry) { ActionLabel("Try again") }.buttonStyle(ActionButtonStyle())
            }
            Spacer(minLength: 0)
        } else {
            ActivityCards(pane: model.pane, model: model, query: query, current: model.current(in: visible), now: now)
        }
    }

    // MARK: The rows the keys move over

    /// The rows the user can see, in order: those of every open band (V5-R55's default: a band holding a problem opens; when none
    /// does, the first opens).
    static func visibleIDs(_ query: ActivityQuery, pane: ActivityPane, store: OpenStateStore) -> [String] {
        func open(_ id: String, problem: Bool, offset: Int, needs: Bool) -> Bool {
            store.isOpen(page: page, id: id, byDefault: OpenStateStore.defaultOpen(holdsProblem: problem, isFirst: offset == 0, pageNeedsUser: needs))
        }
        switch pane {
        case .running:
            let needs = query.sessionBands.contains(where: \.holdsProblem)
            return query.sessionBands.enumerated().flatMap { offset, band in
                open("run:\(band.id)", problem: band.holdsProblem, offset: offset, needs: needs) ? band.items.map(\.id) : []
            }
        case .failed:
            let needs = query.failureBands.contains(where: \.holdsProblem)
            return query.failureBands.enumerated().flatMap { offset, band in
                open("fail:\(band.id)", problem: band.holdsProblem, offset: offset, needs: needs) ? band.items.map(\.id) : []
            }
        }
    }

    // MARK: Keys

    /// `j`/`k` and the arrows move, Return opens the detail, `s` stops, `c` copies, `1` and `2` switch the tabs, Esc closes the
    /// detail (V5-R36). A key acts on the current row of the tab it belongs to.
    private func keys(_ query: ActivityQuery, visible: [String]) -> some View {
        let current = model.current(in: visible)
        return Group {
            HiddenKey(KeyboardShortcut("j", modifiers: [])) { model.move(by: 1, in: visible) }
            HiddenKey(KeyboardShortcut(.downArrow, modifiers: [])) { model.move(by: 1, in: visible) }
            HiddenKey(KeyboardShortcut("k", modifiers: [])) { model.move(by: -1, in: visible) }
            HiddenKey(KeyboardShortcut(.upArrow, modifiers: [])) { model.move(by: -1, in: visible) }
            HiddenKey(KeyboardShortcut(.return, modifiers: [])) { model.toggleDetail(of: current) }
            HiddenKey(KeyboardShortcut("s", modifiers: [])) {
                if model.pane == .running, let item = query.sessions.first(where: { $0.id == current }), item.canStop { model.requestStop(item.session) }
            }
            HiddenKey(KeyboardShortcut("c", modifiers: [])) {
                if model.pane == .failed, let item = query.failures.first(where: { $0.id == current }) { model.copy(item) }
            }
            ForEach(Array(ActivityPane.allCases.enumerated()), id: \.element) { index, _ in
                HiddenKey(KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])) { model.select(index: index) }
            }
            if model.detailID != nil { HiddenKey(KeyboardShortcut(.escape, modifiers: [])) { model.detailID = nil } }
        }
    }
}
