import Foundation
import SiteBlockerCore

/// Deterministic calendar/date helpers so schedule tests never depend on the machine clock,
/// timezone, or DST.
enum Fixture {
    /// A fixed Gregorian calendar pinned to UTC.
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// In January 2024 the day-of-month lines up with weekdays:
    /// 2024-01-01 = Monday ... 2024-01-07 = Sunday. We use that as a stable anchor.
    private static let weekdayToDayOfMonth: [Weekday: Int] = [
        .monday: 1, .tuesday: 2, .wednesday: 3, .thursday: 4,
        .friday: 5, .saturday: 6, .sunday: 7,
    ]

    /// Build a UTC date for a given weekday + wall-clock time during the anchor week.
    static func date(_ weekday: Weekday, _ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 1
        comps.day = weekdayToDayOfMonth[weekday]!
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }
}
