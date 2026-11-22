import Foundation

/// The redesign's time wording for limit Windows (RD46: the mock's `LIM` strings, `src/a-core.js`), beside the v5
/// `LimitsWording`, which the shipped page keeps: a reset's clock time ("3:12 PM", "Mon 9:00 AM", "Dec 1"), the time to it
/// ("42s", "42m", "4h 06m", "4d 18h") and a reading's age ("12 min ago", "7 hours ago").
enum LimitsClockWording {
    /// Today "3:12 PM", within six days "Mon 9:00 AM", later "Dec 1" (the mock's `reset`), and "Nov 10, 2025" in another
    /// year than `now`'s, so a Journal entry from last year never reads as this year's (break-ui, RB-F3).
    static func clock(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = date.timeIntervalSince(now) / 86_400
        let format: String
        if calendar.isDate(date, inSameDayAs: now) {
            format = "h:mm a"
        } else if abs(days) < 6 {
            format = "EEE h:mm a"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            format = "MMM d"
        } else {
            format = "MMM d, yyyy"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    /// The reset's clock time of a Window.
    static func resetsAt(_ window: CoreLimitWindow, now: Date, calendar: Calendar = .current) -> String {
        clock(window.resetsAtDate, now: now, calendar: calendar)
    }

    /// The time to a Window's reset, nil once it has passed.
    static func resetsIn(_ window: CoreLimitWindow, now: Date) -> String? {
        window.isCurrent(at: now) ? span(window.resetsAtDate.timeIntervalSince(now)) : nil
    }

    /// "42s" under a minute, "42m" under an hour, "4h 06m" under a day, "4d 18h" beyond (the mock's `in`).
    static func span(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        if total < 60 { return "\(Int(total.rounded(.down)))s" }
        let minutes = Int((total / 60).rounded(.down))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(String(format: "%02d", minutes % 60))m" }
        return "\(hours / 24)d \(hours % 24)h"
    }

    /// "just now", "12 min ago", "1 hour ago", "7 hours ago", "2 days ago" (the mock's `ago`).
    static func ago(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded())
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(NumberWording.plural(hours, "hour")) ago" }
        return "\(NumberWording.plural(hours / 24, "day")) ago"
    }
}
