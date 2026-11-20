import Foundation
import Observation

/// The weekly countdown lead the user chose in Settings > Limits (spec `docs/specs/2026-11-19-limit-reset-countdown.md`,
/// LC-R4), saved in the app's defaults domain the moment it changes. A change shows at once on the Limits page and in the
/// widget, which both read `shared`. Tests make their own over a throwaway `UserDefaults(suiteName:)`, and screenshots one
/// with no defaults at all, which keeps its choice in memory.
@MainActor
@Observable
final class LimitsCountdownPreferences {
    static let weeklyLeadKey = "spacevibe.weeklyCountdownLead"

    /// One per run. The shot harness swaps in an in-memory one while it draws a lead other than the user's, then puts this
    /// back, so a screenshot never writes the user's defaults.
    static var shared = LimitsCountdownPreferences()

    @ObservationIgnored private let defaults: UserDefaults?

    var weeklyLead: WeeklyCountdownLead {
        didSet { defaults?.set(weeklyLead.rawValue, forKey: Self.weeklyLeadKey) }
    }

    /// `defaults` nil keeps the choice in memory only, starting at `weeklyLead`.
    init(defaults: UserDefaults? = .standard, weeklyLead: WeeklyCountdownLead = .standard) {
        self.defaults = defaults
        // A missing or unknown value (a hand edit, a choice dropped later) reads as the default; reading saves nothing.
        self.weeklyLead = (defaults?.object(forKey: Self.weeklyLeadKey) as? Int).flatMap(WeeklyCountdownLead.init(rawValue:)) ?? weeklyLead
    }
}
