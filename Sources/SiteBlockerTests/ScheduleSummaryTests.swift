import Foundation
import SiteBlockerCore

func runScheduleSummaryTests() {
    section("ScheduleSummary — days")

    test("Every day / Weekdays / Weekends / custom / never") {
        expectEqual(BlockedSite(domain: "a.com", days: Set(Weekday.allCases)).daysDescription, "Every day")
        expectEqual(BlockedSite(domain: "a.com", days: [.monday, .tuesday, .wednesday, .thursday, .friday]).daysDescription, "Weekdays")
        expectEqual(BlockedSite(domain: "a.com", days: [.saturday, .sunday]).daysDescription, "Weekends")
        expectEqual(BlockedSite(domain: "a.com", days: [.monday, .wednesday, .friday]).daysDescription, "Mon Wed Fri")
        expectEqual(BlockedSite(domain: "a.com", days: []).daysDescription, "Never")
    }

    section("ScheduleSummary — times")

    test("All day when no ranges") {
        expectEqual(BlockedSite(domain: "a.com", ranges: []).timesDescription, "All day")
    }

    test("Sorted formatted ranges") {
        let site = BlockedSite(domain: "a.com", ranges: [
            TimeRange(startHour: 20, startMinute: 0, endHour: 22, endMinute: 0),
            TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0),
        ])
        expectEqual(site.timesDescription, "09:00–17:00, 20:00–22:00")
    }

    test("Combined schedule description") {
        let site = BlockedSite(
            domain: "a.com",
            days: [.monday, .tuesday, .wednesday, .thursday, .friday],
            ranges: [TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)]
        )
        expectEqual(site.scheduleDescription, "Weekdays · 09:00–17:30")
    }
}
