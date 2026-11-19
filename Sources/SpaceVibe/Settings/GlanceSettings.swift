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
