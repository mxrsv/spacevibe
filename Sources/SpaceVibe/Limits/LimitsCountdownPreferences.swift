import Foundation
import Observation

/// The weekly countdown lead the user chose in Settings > Limits (spec `docs/specs/2026-11-19-limit-reset-countdown.md`,
/// LC-R4), saved in the app's defaults domain the moment it changes. A change shows at once on the Limits page and in the
/// widget, which both read `shared`. Tests make their own over a throwaway `UserDefaults(suiteName:)`.
@MainActor
@Observable
final class LimitsCountdownPreferences {
    static let weeklyLeadKey = "spacevibe.weeklyCountdownLead"

    static let shared = LimitsCountdownPreferences()

    @ObservationIgnored private let defaults: UserDefaults

    var weeklyLead: WeeklyCountdownLead {
        didSet { defaults.set(weeklyLead.rawValue, forKey: Self.weeklyLeadKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A missing or unknown value (a hand edit, a choice dropped later) reads as the default; reading saves nothing.
        weeklyLead = (defaults.object(forKey: Self.weeklyLeadKey) as? Int).flatMap(WeeklyCountdownLead.init(rawValue:)) ?? .standard
    }
}
