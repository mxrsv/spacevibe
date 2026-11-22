import SwiftUI

/// The panes of the redesign's Settings window, in the reference mock's order (`f-settings-tokens-mock.js`, `P`).
enum SettingsPane: String, CaseIterable, Identifiable, Sendable {
    case general, clis, limits, data, updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .clis: "CLIs"
        case .limits: "Limits"
        case .data: "Data"
        case .updates: "Updates"
        }
    }

    var icon: FrameIcon {
        switch self {
        case .general: .slidersHorizontal
        case .clis: .terminalWindow
        case .limits: .limits
        case .data: .hardDrives
        case .updates: .arrowClockwise
        }
    }
}

/// What a screenshot draws the Settings window with: the store's facts and the preferences, in memory, never the machine's.
@MainActor
struct SettingsWindowPreview {
    var state: SettingsWindowState = .normal
    var facts: SettingsFacts
    var now: Date
    var cli: CLIPreferences
    var glance: GlancePreferences
    var countdown: LimitsCountdownPreferences
    var loginItem: LoginItem
    var dataFolder: URL
    /// The refused-setting toast the shot shows.
    var refusal: String?
}

/// The redesign's separate Settings window (RD4, plan AR8): a row of pane tabs under the title bar and the open pane below
/// (RB-R8: General, CLIs, Limits, Data, Updates; `SettingsPanes.swift`). Declared as its own `Window` scene by
/// `SpaceVibeFrameApp` only, so a v5 launch never has it; the v5 Settings overlay stays until RB-X1.
///
/// It reads the app's frame model (`SpaceVibeFrameApp`: the one the main window shows, AR2) for the registry, the
/// status-line snapshot and the Journal, and edits the app's preferences: theme and Session widget in the v5 stores, the Weekly lead in `LimitsCountdownPreferences`,
/// Show and Balance pins in `CLIPreferences`, Open at login through macOS (`LoginItem`). A switch applies at once and is its
/// own undo, so no toast follows; a refused one (macOS said no, the Show guard, a fourth pin) shows the error toast in this
/// window's own toast host.
struct SettingsWindowFrame: View {
    static let windowID = "settings"
    /// The snapshot age and the login item's status are read again this often while the window is open.
    static let redrawInterval: TimeInterval = 60

    @State private var pane: SettingsPane
    @State private var toasts: ToastCenter
    private let preview: SettingsWindowPreview?
    /// The app's frame model; nil in a screenshot, which reads `preview` instead.
    private let model: FrameModel?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.glancePreferences) private var glancePreferences

    init(model: FrameModel? = nil, pane: SettingsPane = .general, preview: SettingsWindowPreview? = nil) {
        self.model = model
        _pane = State(initialValue: preview?.state.openingPane ?? pane)
        let toasts = ToastCenter(announce: preview == nil)
        if let refusal = preview?.refusal { toasts.show(refusal, tone: .danger) }
        _toasts = State(initialValue: toasts)
        self.preview = preview
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.redrawInterval)) { timeline in
            ZStack(alignment: .top) {
                FrameWindowSurface(hasSidebar: false)
                VStack(spacing: 0) {
                    FramePaneTabBar {
                        ForEach(SettingsPane.allCases) { item in
                            FramePaneTab(title: item.title, icon: item.icon, isCurrent: item == pane) { pane = item }
                        }
                    }
                    .padding(.top, SpaceRole.titleBarClearance)
                    .padding(.horizontal, SpaceRole.step16)
                    .padding(.bottom, SpaceRole.step10)
                    SettingsPaneBody(pane: pane, context: context(now: preview?.now ?? timeline.date))
                }
                // The mock's `.toast` in the 660 window: at most 90 % of its width, so the toast keeps room for its text.
                FrameToastHost(windowMargin: BlockRole.settingsToastWindowMargin)
            }
        }
        .environment(toasts)
        .frame(width: FrameRole.settingsWindowWidth)
        .ignoresSafeArea()
        .navigationTitle("Settings")
        .onExitCommand { toasts.dismiss() }
        // Opened before the main window has read anything, the panes still get the registry (`start` runs once).
        .task { await model?.store.start() }
    }

    private func context(now: Date) -> SettingsPaneContext {
        SettingsPaneContext(
            facts: preview?.facts ?? SettingsFacts(store: model?.store), now: now,
            cli: preview?.cli ?? .shared, glance: preview?.glance ?? glancePreferences ?? .shared,
            countdown: preview?.countdown ?? LimitsCountdownPreferences.shared, loginItem: preview?.loginItem ?? .shared,
            dataFolder: preview?.dataFolder ?? SettingsDataWording.dataFolder(),
            toast: { message, tone in toasts.show(message, tone: tone) },
            showJournal: { openWindow(id: JournalWindow.windowID) })
    }
}
