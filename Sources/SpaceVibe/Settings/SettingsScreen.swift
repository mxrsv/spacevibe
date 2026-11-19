import SwiftUI

/// Settings over the whole window (spec `docs/specs/2026-11-04-reins-settings.md`, mock A2): the rail of sections at the
/// top with the back button after the window buttons, one centred column of cards, and a status bar with only `Esc`.
struct SettingsScreen: View {
    /// The page name under which the cards keep their open state.
    static let page = "settings"

    @Environment(ShellModel.self) private var shell

    var body: some View {
        VStack(spacing: 0) {
            rail
            SpaceVibeScrollView {
                Group {
                    switch shell.settingsSection {
                    case .appearance: AppearanceSettings()
                    case .limits: LimitsSettings()
                    case .update: UpdateSettings()
                    }
                }
                .frame(width: Metrics.settingsColumnWidth)
                .frame(maxWidth: .infinity)
                .padding(.top, Space.s16)
                .padding(.bottom, Rhythm.edge)
            }
            StatusBar(hints: [KeyHint(keys: "Esc", label: "Back to \(shell.title)")])
        }
        .pageBackground()
    }

    private var rail: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: Space.s4) {
                ForEach(SettingsSection.allCases) { section in
                    RailTab(title: section.title, glyph: section.icon, isActive: section == shell.settingsSection) {
                        shell.settingsSection = section
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s12)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Settings sections")

            Button { shell.closeSettings() } label: { SpaceVibeIcon(content: .caretLeft) }
                .buttonStyle(ActionButtonStyle(kind: .icon))
                // `Esc` belongs to the palette while it is open over Settings.
                .keyboardShortcut(shell.isPaletteOpen ? nil : .cancelAction)
                .help("Back to \(shell.title) (Esc)")
                .accessibilityLabel("Back to \(shell.title)")
                .padding(.leading, Metrics.trafficLightsWidth)
                .padding(.top, Space.s8)
        }
    }
}
