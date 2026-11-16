import SwiftUI

/// Settings > Update: the lead card (the version and build as its title, one button in its header, the SpaceVibe mark beside
/// the last check's result and time) and the automatic-check card with its switch. Opening it never starts a check.
struct UpdateSettings: View {
    @Environment(UpdateController.self) private var updates
    @Environment(\.openStateStore) private var store

    var body: some View {
        @Bindable var updates = updates
        VStack(spacing: Rhythm.card) {
            Tile(SettingsWording.appName(version: updates.version), count: updates.build.map { "Build \($0)" }, layout: .content,
                 isOpen: open("update")) {
                HStack(spacing: Space.s16) {
                    SpaceVibeMark()
                    status
                }
                if case .unavailable(let reason) = updates.status {
                    HStack(alignment: .top, spacing: Space.s8) {
                        SpaceVibeIcon(content: .info, ink: TextTone.tertiary.color)
                        Text(reason).spaceVibeText(.prose, tone: .secondary).fixedSize(horizontal: false, vertical: true).lineBox(.prose)
                    }
                    .accessibilityElement(children: .combine)
                }
            } actions: {
                action
            }

            Tile(SettingsWording.automaticChecks, layout: .content, isOpen: open("automatic")) {
                Text(SettingsWording.automaticChecksDetail).spaceVibeText(.prose, tone: .secondary).lineBox(.prose)
            } actions: {
                SpaceVibeSwitch(label: SettingsWording.automaticChecks, isOn: $updates.automaticChecks)
                    .disabled(!updates.isRunning)
            }
        }
    }

    private func open(_ id: String) -> Binding<Bool> {
        store.binding(page: SettingsScreen.page, id: id, byDefault: true)
    }

    @ViewBuilder
    private var status: some View {
        let tag = SettingsWording.tag(updates.status)
        let time = SettingsWording.lastCheck(updates.status, at: updates.lastCheck, now: Date())
        if tag != nil || time != nil {
            VStack(alignment: .leading, spacing: Space.s4) {
                if let tag {
                    HStack(spacing: Space.s6) {
                        if tag.warns {
                            StateMarkIcon(mark: StateMark(.warn, label: tag.text))
                        } else if let glyph = tag.glyph {
                            SpaceVibeIcon(content: glyph, ink: TextTone.secondary.color)
                        }
                        Text(tag.text).spaceVibeText(.control, tone: .primary)
                    }
                }
                if let time { Text(time).spaceVibeText(.meta, tone: .tertiary) }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var action: some View {
        if case .available = updates.status {
            Button { updates.checkForUpdates() } label: { ActionLabel("View Update") }
                .buttonStyle(ActionButtonStyle(kind: .primary, size: .compact))
        } else {
            Button { updates.checkNow() } label: { ActionLabel("Check Now") }
                .buttonStyle(ActionButtonStyle(size: .compact))
                .disabled(!updates.isRunning || updates.status == .checking)
        }
    }
}
