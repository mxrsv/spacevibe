import SwiftUI

/// Settings > Limits: how long before a weekly reset its countdown starts, on the Limits page and in the glance widget
/// (spec `docs/specs/2026-11-19-limit-reset-countdown.md`, LC3, LC-R4). The 5-hour lead is fixed (LC4), so it has no control.
struct LimitsSettings: View {
    @Environment(\.openStateStore) private var store
    private let countdown = LimitsCountdownPreferences.shared

    var body: some View {
        @Bindable var countdown = countdown
        VStack(spacing: Rhythm.card) {
            Tile(SettingsWording.weeklyCountdown, layout: .content, isOpen: open("weeklyCountdown")) {
                Text(SettingsWording.weeklyCountdownDetail).spaceVibeText(.prose, tone: .secondary).lineBox(.prose)
            } actions: {
                SegmentedControl(label: SettingsWording.weeklyCountdown,
                                 options: WeeklyCountdownLead.allCases.map { SegmentOption($0.title, value: $0) },
                                 selection: $countdown.weeklyLead)
            }
        }
    }

    private func open(_ id: String) -> Binding<Bool> {
        store.binding(page: SettingsScreen.page, id: id, byDefault: true)
    }
}
