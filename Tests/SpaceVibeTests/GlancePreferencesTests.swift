import Foundation
import Testing
@testable import SpaceVibe

/// The glance widget's saved switch and slot (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW16, GW18, GW-R10).
/// Every test reads and writes a throwaway defaults suite, never `.standard`.
@MainActor
@Suite("GlancePreferences")
struct GlancePreferencesTests {
    private func throwawayDefaults() -> UserDefaults {
        UserDefaults(suiteName: "spacevibe-tests-\(UUID().uuidString)")!
    }

    private let placement = GlancePlacement(screen: GlanceScreenID(displayID: 2, name: "Studio Display"), slot: .topLeft)

    @Test("on with no placement when nothing is saved, and reading saves nothing")
    func defaults() {
        let defaults = throwawayDefaults()
        let preferences = GlancePreferences(defaults: defaults)
        #expect(preferences.isEnabled)
        #expect(preferences.placement == nil)
        #expect(defaults.object(forKey: GlancePreferences.enabledKey) == nil)
        #expect(defaults.object(forKey: GlancePreferences.placementKey) == nil)
    }

    @Test("the switch is remembered by the next instance, off and on again")
    func switchPersists() {
        let defaults = throwawayDefaults()
        GlancePreferences(defaults: defaults).isEnabled = false
        let second = GlancePreferences(defaults: defaults)
        #expect(!second.isEnabled)
        second.isEnabled = true
        #expect(GlancePreferences(defaults: defaults).isEnabled)
    }

    @Test("a placement round-trips, and clearing it removes the saved data")
    func placementRoundTrips() {
        let defaults = throwawayDefaults()
        GlancePreferences(defaults: defaults).placement = placement
        let second = GlancePreferences(defaults: defaults)
        #expect(second.placement == placement)
        second.placement = nil
        #expect(defaults.object(forKey: GlancePreferences.placementKey) == nil)
        #expect(GlancePreferences(defaults: defaults).placement == nil)
    }

    @Test("unreadable placement data reads as no placement", arguments: [
        Data("not json".utf8),
        Data(#"{"slot":"middle","screen":{"displayID":1,"name":"A"}}"#.utf8),
        Data(#"{"slot":"topLeft"}"#.utf8),
    ])
    func garbagePlacement(data: Data) {
        let defaults = throwawayDefaults()
        defaults.set(data, forKey: GlancePreferences.placementKey)
        #expect(GlancePreferences(defaults: defaults).placement == nil)
    }

    @Test("a placement saved as another type reads as no placement, and a non-Bool switch reads as on")
    func wrongTypes() {
        let defaults = throwawayDefaults()
        defaults.set("topLeft", forKey: GlancePreferences.placementKey)
        defaults.set("off", forKey: GlancePreferences.enabledKey)
        let preferences = GlancePreferences(defaults: defaults)
        #expect(preferences.placement == nil)
        #expect(preferences.isEnabled)
    }
}
