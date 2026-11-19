import Foundation
import Observation

/// What the glance widget remembers (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW16, GW18, GW-R10): whether it
/// shows, and the slot the user dragged it to. Both are saved in the app's defaults domain the moment they change.
///
/// One instance per run (`shared`), read by Settings > Appearance and by the widget. Tests and screenshots make their own
/// over a throwaway `UserDefaults(suiteName:)`.
@MainActor
@Observable
final class GlancePreferences {
    static let enabledKey = "spacevibe.glanceWidgetEnabled"
    static let placementKey = "spacevibe.glanceWidgetPlacement"

    static let shared = GlancePreferences()

    @ObservationIgnored private let defaults: UserDefaults

    /// On by default (GW16); the Settings switch turns it off.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// Nil until the user drags the widget; the widget then sits in `GlanceSlot.defaultSlot` on the main screen. Saved as JSON.
    var placement: GlancePlacement? {
        didSet {
            if let placement, let data = try? JSONEncoder().encode(placement) {
                defaults.set(data, forKey: Self.placementKey)
            } else {
                defaults.removeObject(forKey: Self.placementKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Setting a property in init does not fire didSet, so reading saves nothing.
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        // Data that no longer decodes (an older shape, a hand edit) reads as no placement, never as an error.
        placement = defaults.data(forKey: Self.placementKey).flatMap { try? JSONDecoder().decode(GlancePlacement.self, from: $0) }
    }
}
