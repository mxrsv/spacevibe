import Foundation

/// When something last ran and when it was added, as the new frame words them (RD-R17, D63). Pure: every age is an argument, so
/// nothing here reads the clock.
enum DayWording {
    /// The engine records a use by day (usage.md: the date text of the line, no zone), so "last ran" is a day and nothing finer:
    /// `today`, `yesterday`, `N days ago`, the mock's `dayTxt` (`src/m-model.js`). Days only, no weeks or months, unlike the
    /// v5 Skills wording (`SkillDays.phrase`). `daysAgo` is whole days from the recorded day to today, as `SkillDays.daysAgo`
    /// counts them; nil (never ran, or a day the engine could not read) reads as `NumberWording.missing`. A day after today
    /// (a clock that moved back) reads `today`.
    static func lastRan(daysAgo: Int?) -> String {
        guard let days = daysAgo else { return NumberWording.missing }
        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        return "\(NumberWording.count(days)) days ago"
    }

    /// The quiet note on a Never ran item whose file is new (D63): `added 2 hours ago`, `added 41 days ago`, `added 412 days ago`.
    /// `secondsAgo` is the time from the item's first sighting to now. Under a minute `added just now`, then minutes, hours and
    /// days; days do not roll up into months. A sighting in the future (a clock that moved back) is `added just now`; NaN or
    /// infinity reads as `NumberWording.missing`.
    static func added(secondsAgo: TimeInterval) -> String {
        guard secondsAgo.isFinite else { return NumberWording.missing }
        // Capped so a corrupt timestamp cannot overflow `Int` (a trap); 1e15 s is far past any real file.
        let minutes = Int(min(max(0, secondsAgo), 1e15) / 60)
        if minutes < 1 { return "added just now" }
        if minutes < 60 { return "added \(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "added \(NumberWording.plural(hours, "hour")) ago" }
        return "added \(NumberWording.plural(hours / 24, "day")) ago"
    }
}
