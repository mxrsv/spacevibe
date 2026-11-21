import Foundation
import Testing
@testable import SpaceVibe

/// "Last ran" is a day (the mock's `dayTxt`), "added" is the D63 note; both with the break-ui extremes.
@Suite("Day wording")
struct DayWordingTests {
    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 86_400

    @Test("last ran: today, yesterday, then whole days with no rollup into weeks or months")
    func lastRan() {
        #expect(DayWording.lastRan(daysAgo: 0) == "today")
        #expect(DayWording.lastRan(daysAgo: 1) == "yesterday")
        #expect(DayWording.lastRan(daysAgo: 2) == "2 days ago")
        #expect(DayWording.lastRan(daysAgo: 19) == "19 days ago")
        #expect(DayWording.lastRan(daysAgo: 412) == "412 days ago")
        #expect(DayWording.lastRan(daysAgo: 1204) == "1,204 days ago")
    }

    @Test("last ran: no day reads as a dash, a day after today as today")
    func lastRanGuards() {
        #expect(DayWording.lastRan(daysAgo: nil) == NumberWording.missing)
        #expect(DayWording.lastRan(daysAgo: -2) == "today")
        #expect(DayWording.lastRan(daysAgo: Int.max) == "9,223,372,036,854,775,807 days ago")
    }

    @Test("last ran: the day count is the one the v5 Skills page computes from the engine's YYYY-MM-DD")
    func lastRanFromEngineDay() {
        let now = Date(timeIntervalSince1970: 1_794_268_800 + 5 * Self.hour) // 2026-11-10T05:00:00Z
        #expect(DayWording.lastRan(daysAgo: SkillDays.daysAgo("2026-11-10", now: now)) == "today")
        #expect(DayWording.lastRan(daysAgo: SkillDays.daysAgo("2026-11-09", now: now)) == "yesterday")
        #expect(DayWording.lastRan(daysAgo: SkillDays.daysAgo("2026-10-22", now: now)) == "19 days ago")
        #expect(DayWording.lastRan(daysAgo: SkillDays.daysAgo("not a day", now: now)) == NumberWording.missing)
    }

    @Test("added: just now, minutes, hours, then days, singular for one")
    func added() {
        #expect(DayWording.added(secondsAgo: 0) == "added just now")
        #expect(DayWording.added(secondsAgo: 59) == "added just now")
        #expect(DayWording.added(secondsAgo: 60) == "added 1 min ago")
        #expect(DayWording.added(secondsAgo: 3599) == "added 59 min ago")
        #expect(DayWording.added(secondsAgo: Self.hour) == "added 1 hour ago")
        #expect(DayWording.added(secondsAgo: 2 * Self.hour) == "added 2 hours ago")
        #expect(DayWording.added(secondsAgo: Self.day - 1) == "added 23 hours ago")
        #expect(DayWording.added(secondsAgo: Self.day) == "added 1 day ago")
        #expect(DayWording.added(secondsAgo: 41 * Self.day) == "added 41 days ago")
        #expect(DayWording.added(secondsAgo: 412 * Self.day) == "added 412 days ago")
    }

    @Test("added: a future sighting is just now; NaN and infinity read as a dash; a huge age does not trap")
    func addedGuards() {
        #expect(DayWording.added(secondsAgo: -100) == "added just now")
        #expect(DayWording.added(secondsAgo: .nan) == NumberWording.missing)
        #expect(DayWording.added(secondsAgo: .infinity) == NumberWording.missing)
        #expect(DayWording.added(secondsAgo: -.infinity) == NumberWording.missing)
        #expect(DayWording.added(secondsAgo: 1e300) == "added 11,574,074,074 days ago")
    }
}
