import SwiftUI

/// Settings > Appearance > Session widget: the one switch that shows or hides the glance widget (spec
/// `docs/specs/2026-11-19-session-glance-widget.md`, GW18, GW-R10). Its position is chosen by dragging the widget, not here.
struct GlanceSettings: View {
    @Bindable var preferences: GlancePreferences
    let isOpen: Binding<Bool>

    var body: some View {
        Tile(SettingsWording.glanceWidget, layout: .content, isOpen: isOpen) {
            Text(SettingsWording.glanceWidgetDetail).spaceVibeText(.prose, tone: .secondary).lineBox(.prose)
        } actions: {
            SpaceVibeSwitch(label: SettingsWording.glanceWidget, isOn: $preferences.isEnabled)
        }
    }
}

// Written out: the `@Entry` macro needs SwiftUI's macro plugin, which the Command Line Tools do not ship.
private struct GlancePreferencesKey: EnvironmentKey {
    /// Nil means the app's own `GlancePreferences.shared`; a key's default is read off the main actor, so it cannot name it.
    static let defaultValue: GlancePreferences? = nil
}

extension EnvironmentValues {
    /// The preferences the Session widget switch edits: nil for the app's own; a screenshot passes a throwaway store so the
    /// shot never reads or writes the machine's defaults.
    var glancePreferences: GlancePreferences? {
        get { self[GlancePreferencesKey.self] }
        set { self[GlancePreferencesKey.self] = newValue }
    }
}
