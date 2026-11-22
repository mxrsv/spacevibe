import SwiftUI

/// A fixed reading for the Activity page instead of the store's (a state shot): everything `ActivityPageInput` takes from the
/// store and the clock. The page state (tab, ticks, selection) still comes from the page.
struct ActivityPreview: Sendable {
    var clis: [CoreRegistryCLI]
    var sessions: [CoreActivitySession]
    /// Sessions of illustration CLIs: their registry id by session id (`ActivityPageInput.sessionCLIs`).
    var sessionCLIs: [String: String] = [:]
    var failures: [CoreActivityFailure]
    var hasReport = true
    var source: FrameSourceState? = .ready
    var figure: PageFigure
    var now = Date()
    /// Page state a shot pins instead of the page's own: the tab, the selected row, the ticks and the rows the Stop alert
    /// names (nil leaves the page's own).
    var tab: ActivityTable?
    var selection: String?
    var ticked: Set<String>?
    var stopAlertIDs: [String] = []
    /// The app that hosts a session, pinned for a shot (the real resolver finds none for a synthetic pid); nil leaves the
    /// page's own.
    var hostApp: (@Sendable (Int) -> HostApp?)?
}

/// The redesign's Activity page (RB-R7; the mock's `pageActivity`): the hero `1 waiting for you` (or the running count),
/// Sessions grouped by CLI with waiting first and Failures, each tab with its own inspector, Stop from the selected row or the
/// ticked ones, and Show Terminal in the inspector. Hands the frame its parts (`FramePageContent`); every part reads the
/// same `ActivityPageData`, so the hero, the rows, the toolbar's Stop and the inspector cannot disagree.
enum ActivityPage {
    @MainActor
    static func content(_ model: FrameModel, preview: ActivityPreview? = nil) -> FramePageContent {
        let state = ActivityPageState.of(model)
        if let hostApp = preview?.hostApp { state.hostApp = hostApp }
        let context = ActivityPageContext(model: model, state: state, preview: preview)
        return FramePageContent(
            help: FramePage.activity.help,
            toolbarControls: AnyView(ActivityToolbarControls(context: context)),
            searchItems: context.data().searchItems,
            primary: AnyView(ActivityStopButton(context: context)),
            body: AnyView(ActivityPageBody(context: context)),
            inspector: AnyView(ActivityInspector(context: context)),
            overlayActions: AnyView(ActivityOverlayActions(context: context)))
    }
}

/// What every part of the page holds: the frame's model, the page state and an optional fixed reading.
struct ActivityPageContext {
    let model: FrameModel
    let state: ActivityPageState
    var preview: ActivityPreview?

    /// The page's derivation now. Reads the store (observed), the route and the page state.
    @MainActor
    func data(now: Date = Date()) -> ActivityPageData {
        guard let preview else { return ActivityPageData(state.input(model: model, now: now)) }
        return ActivityPageData(ActivityPageInput(
            clis: preview.clis, sessions: preview.sessions, sessionCLIs: preview.sessionCLIs, failures: preview.failures, hasReport: preview.hasReport,
            source: preview.source, figure: preview.figure, tab: preview.tab ?? state.tab, scope: state.scope, dismissed: state.dismissed,
            ticked: preview.ticked ?? state.ticked, selection: preview.selection ?? model.router.route.selection, now: preview.now,
            query: model.search.query))
    }

    /// The rows the Stop alert names: the page's, or the ones a shot pins.
    @MainActor
    func stopTargets(in data: ActivityPageData) -> [ActivitySessionRow] {
        guard let ids = preview?.stopAlertIDs, !ids.isEmpty else { return state.stopTargets }
        return data.sessionRows.filter { ids.contains($0.id) }
    }

    /// The row actions of a session (RD-R16: one list for the selected row's buttons, the context menu, the accessibility
    /// actions and the Item menu). Stop… asks first; S is its key (RD39).
    @MainActor
    func actions(for row: ActivitySessionRow) -> [FrameRowAction] {
        let pending = model.writes.isPending(ActivityPageState.stopControl(row)) || model.writes.isPending(ActivityPageState.stopManyControl)
        return [FrameRowAction(id: "stop", title: "Stop…", shortcut: FrameShortcut("s", modifiers: []), isDestructive: true,
                               isEnabled: row.canStop && !pending) { state.requestStop([row]) }]
    }

    @MainActor
    func actions(for row: ActivityFailureRow, toasts: ToastCenter) -> [FrameRowAction] {
        [FrameRowAction(id: "copyCommand", title: "Copy Command", shortcut: .copyCommand) {
            state.copyCommand(row, toasts: toasts)
        }]
    }
}

/// The toolbar's own controls (the mock's `mid`): the Sessions / Failures control and the `All CLIs` menu.
private struct ActivityToolbarControls: View {
    let context: ActivityPageContext

    var body: some View {
        @Bindable var state = context.state
        let clis = context.preview?.clis ?? context.model.store.world().clis
        let options = clis.map { CLIMenuEntries.Option(cli: CLIIdentity(id: $0.id, name: $0.name), isSupported: $0.supports.logs) }
        let chosen = options.first { $0.cli.id == state.scope }?.cli
        // A shot that pins the tab shows it in the switch too.
        let tab = context.preview?.tab ?? state.tab
        HStack(spacing: SpaceRole.step8) {
            FrameSegmentedControl(
                segments: ActivityTable.allCases.map { FrameSegment(id: $0.rawValue, title: $0.title) },
                selection: tab.rawValue, label: "Activity list"
            ) { id in
                if let tab = ActivityTable(rawValue: id) { state.show(tab, router: context.model.router) }
            }
            MenuTrigger(title: CLIMenuEntries.scopeTitle(options, scope: state.scope), lead: chosen.map(MenuPanelEntry.Lead.cli) ?? .none,
                        isOpen: state.isScopeMenuOpen, label: "CLIs shown") { state.isScopeMenuOpen.toggle() }
                .popover(isPresented: $state.isScopeMenuOpen, arrowEdge: .bottom) {
                    MenuPanel(heading: CLIMenuEntries.scopeHeading, entries: CLIMenuEntries.scope(options, scope: state.scope),
                              pick: { id in state.setScope(id == CLIMenuEntries.allID ? nil : id) },
                              close: { state.isScopeMenuOpen = false })
                }
        }
    }
}

/// The toolbar's destructive slot (the mock's `.dst.slot`): `Stop N…` while rows are ticked, an empty slot
/// otherwise, so the controls beside it never move (FE-L1, RD-R17 Layout).
private struct ActivityStopButton: View {
    let context: ActivityPageContext

    var body: some View {
        let data = context.data()
        if let title = data.primaryTitle {
            Button { context.state.requestStop(data.picks) } label: { PushButtonLabel(title, icon: .stopCircle) }
                .buttonStyle(PushButtonStyle(.destructive, isLoading: context.model.writes.isPending(ActivityPageState.stopManyControl)))
                .focusEffectDisabled()
                .help(data.primaryHelp ?? title)
                .accessibilityLabel(data.primaryHelp ?? title)
        } else {
            Color.clear.accessibilityHidden(true)
        }
    }
}

/// The selected row's actions at the overlay inspector's top below 1100 pt (DS-R10 Inspector).
private struct ActivityOverlayActions: View {
    let context: ActivityPageContext
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        let data = context.data()
        if let row = data.selectedSession {
            FrameRowActionButtons(actions: context.actions(for: row))
        } else if let row = data.selectedFailure {
            FrameRowActionButtons(actions: context.actions(for: row, toasts: toasts))
        }
    }
}

/// The list column: hero, the state band, then the tab's table or its empty state.
private struct ActivityPageBody: View {
    let context: ActivityPageContext
    @Environment(FrameChrome.self) private var chrome
    @Environment(\.materialLook) private var look

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let data = context.data(now: context.preview?.now ?? timeline.date)
            SpaceVibeScrollView {
                VStack(alignment: .leading, spacing: SpaceRole.step16) {
                    // The mock's `.hdr` (4 above, 8 beside, 20 below with the stack's 16), as on every page (RB-F4).
                    PageHero(data.hero.figure, label: data.hero.label)
                        .padding(.top, SpaceRole.step4)
                        .padding(.horizontal, SpaceRole.step8)
                        .padding(.bottom, SpaceRole.step4)
                    content(data)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frameListKeys(rows: data.visibleIDs, router: context.model.router, chrome: chrome)
            // RD44: the first shown row is selected on opening and whenever the tab, the CLI menu or the search hides the
            // selected one (`FrameRouter.keepSelection`, the rule `frameFirstRowSelection` applies). Only once a reading is
            // shown: before the first report the session the glance widget opened (`FrameRoute.session`) must survive. A shot
            // pins its own selection instead.
            .onChange(of: ActivityFirstRowInput(route: context.model.router.route, rows: data.visibleIDs, isReady: !data.isReading),
                      initial: true) { _, input in
                guard context.preview == nil, input.isReady else { return }
                context.model.router.keepSelection(onPage: .activity, among: input.rows)
            }
            .stopAlert(isPresented: Binding(get: { !context.stopTargets(in: data).isEmpty }, set: { if !$0 { context.state.cancelStop() } }),
                       text: ActivityPageData.stopText(context.stopTargets(in: data))) {
                context.state.confirmStop(writes: context.model.writes)
            }
        }
        .onDisappear { context.state.pageLeft() }
    }

    @ViewBuilder
    private func content(_ data: ActivityPageData) -> some View {
        switch data.phase {
        case .reading:
            StatusBanner(.scanning(progress: nil), title: "Reading the process table and session logs…")
            RowGroup { SkeletonRows(count: 4) }
        case .unreadable(let reason):
            problem(title: "Sessions could not be read", detail: reason)
        case .ready(let stale):
            if let stale { problem(title: "Showing the last reading", detail: stale) }
            if data.isSearchMiss {
                FrameSearchNoMatch(items: data.searchItems, search: context.model.search)
            } else {
                switch data.input.tab {
                case .sessions:
                    ActivitySessionsList(context: context, data: data, isWide: isWide)
                case .failures:
                    ActivityFailuresList(context: context, data: data)
                }
            }
        }
    }

    /// The mock's `ctx.wide`: the main column (the window less the sidebar and a docked inspector, `FrameChrome.listWidth`, the
    /// mock's `mw`) is at least 940, measured outside the content's safe-area padding. A shot without a window width is wide.
    private var isWide: Bool {
        let width = chrome.listWidth(sidebar: FrameRole.sidebarWidth(look), inspector: FramePage.activity.inspectorWidth.points)
        return chrome.windowWidth == 0 || width >= TableColumnWidth.wideListWidth
    }

    /// The error band (RD-R13): what could not be read, the core's sentence, and Try Again, which reads again at once.
    private func problem(title: String, detail: String) -> some View {
        StatusBanner(.problem(.attention), title: title, detail: detail) {
            Button("Try Again") { Task { await context.model.store.refresh(force: true) } }
                .buttonStyle(PushButtonStyle(.control, size: .small))
                .focusEffectDisabled()
        }
    }
}

/// What Activity's first-row rule watches (RD44): a change in any of these may leave the page without a selected row it shows.
private struct ActivityFirstRowInput: Equatable {
    let route: FrameRoute
    let rows: [String]
    let isReady: Bool
}
