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

/// The redesign's separate Settings window (RD4, plan AR8): a row of pane tabs under the title bar and the open pane below.
/// The panes are RB-R8's; until then each one says "Not built yet". Declared as its own `Window` scene by
/// `SpaceVibeFrameApp` only, so a v5 launch never has it; the v5 Settings overlay stays until RB-X1.
struct SettingsWindowFrame: View {
    static let windowID = "settings"

    @State private var pane: SettingsPane

    init(pane: SettingsPane = .general) {
        _pane = State(initialValue: pane)
    }

    var body: some View {
        ZStack(alignment: .top) {
            FrameWindowSurface(hasSidebar: false)
            VStack(spacing: 0) {
                HStack(spacing: SpaceRole.step4) {
                    ForEach(SettingsPane.allCases) { item in
                        FramePaneTab(title: item.title, icon: item.icon, isCurrent: item == pane) { pane = item }
                    }
                }
                .padding(.top, SpaceRole.titleBarClearance)
                .padding(.horizontal, SpaceRole.step16)
                .padding(.bottom, SpaceRole.step10)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Settings panes")
                FrameQuietEmptyState(icon: pane.icon, title: "Not built yet",
                                     message: "The \(pane.title) pane has no view in the redesign yet.")
                    .frame(maxWidth: .infinity, minHeight: FrameRole.settingsBodyMinHeight, alignment: .top)
            }
        }
        .frame(width: FrameRole.settingsWindowWidth)
        .ignoresSafeArea()
        .navigationTitle("Settings")
    }
}
