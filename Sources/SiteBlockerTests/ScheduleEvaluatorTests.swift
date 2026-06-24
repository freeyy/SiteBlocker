import Foundation
import SiteBlockerCore

private func blocked(_ site: BlockedSite, _ weekday: Weekday, _ hour: Int, _ minute: Int = 0) -> Bool {
    ScheduleEvaluator.isBlocked(site, at: Fixture.date(weekday, hour, minute), calendar: Fixture.calendar)
}

func runScheduleEvaluatorTests() {
    section("ScheduleEvaluator — weekday + time windows")

    test("Work-hours blocking on selected weekdays") {
        let site = BlockedSite(
            domain: "reddit.com",
            days: [.monday, .tuesday, .wednesday, .thursday, .friday],
            ranges: [TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)]
        )
        expectTrue(blocked(site, .monday, 10))
        expectTrue(blocked(site, .friday, 9, 0))
        expectTrue(blocked(site, .friday, 16, 59))
        expectFalse(blocked(site, .monday, 8, 59))
        expectFalse(blocked(site, .monday, 17, 0))
        expectFalse(blocked(site, .saturday, 10))
        expectFalse(blocked(site, .sunday, 10))
    }

    test("Empty ranges block the whole selected day") {
        let site = BlockedSite(domain: "twitter.com", days: [.saturday, .sunday], ranges: [])
        expectTrue(blocked(site, .saturday, 0, 0))
        expectTrue(blocked(site, .saturday, 23, 59))
        expectTrue(blocked(site, .sunday, 12))
        expectFalse(blocked(site, .friday, 12))
    }

    test("Disabled site never blocks") {
        let site = BlockedSite(domain: "x.com", isEnabled: false, days: Set(Weekday.allCases), ranges: [])
        expectFalse(blocked(site, .monday, 12))
    }

    test("Empty days never blocks") {
        let site = BlockedSite(domain: "x.com", days: [], ranges: [])
        expectFalse(blocked(site, .monday, 12))
    }

    section("ScheduleEvaluator — cross-midnight")

    test("Cross-midnight window assigns the morning slice to the start day") {
        let site = BlockedSite(
            domain: "youtube.com",
            days: [.monday],
            ranges: [TimeRange(startHour: 22, startMinute: 0, endHour: 2, endMinute: 0)]
        )
        expectTrue(blocked(site, .monday, 22, 0))
        expectTrue(blocked(site, .monday, 23, 30))
        expectTrue(blocked(site, .tuesday, 1, 0))   // belongs to Monday night
        expectFalse(blocked(site, .tuesday, 2, 0))  // end exclusive
        expectFalse(blocked(site, .tuesday, 3, 0))
        expectFalse(blocked(site, .monday, 1, 0))   // Monday 1am belongs to Sunday, not selected
        expectFalse(blocked(site, .tuesday, 22, 0)) // Tuesday not selected
    }

    section("ScheduleEvaluator — multiple ranges & full day")

    test("Multiple ranges with a gap") {
        let site = BlockedSite(
            domain: "facebook.com",
            days: Set(Weekday.allCases),
            ranges: [
                TimeRange(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0),
                TimeRange(startHour: 14, startMinute: 0, endHour: 18, endMinute: 0),
            ]
        )
        expectTrue(blocked(site, .wednesday, 10))
        expectTrue(blocked(site, .wednesday, 15))
        expectFalse(blocked(site, .wednesday, 13))
        expectFalse(blocked(site, .wednesday, 8))
    }

    test("Full-day range always blocks on selected days") {
        let site = BlockedSite(
            domain: "instagram.com",
            days: [.monday],
            ranges: [TimeRange(start: .startOfDay, end: .endOfDay)]
        )
        expectTrue(blocked(site, .monday, 0, 0))
        expectTrue(blocked(site, .monday, 23, 59))
        expectFalse(blocked(site, .tuesday, 12))
    }

    section("ScheduleEvaluator — activeDomains")

    test("activeDomains de-duplicates, sorts and filters") {
        let always = TimeRange(start: .startOfDay, end: .endOfDay)
        let config = BlockConfig(sites: [
            BlockedSite(domain: "zeta.com", days: [.monday], ranges: [always]),
            BlockedSite(domain: "alpha.com", days: [.monday], ranges: [always]),
            BlockedSite(domain: "alpha.com", days: [.monday], ranges: [always]),
            BlockedSite(domain: "off.com", days: [.tuesday], ranges: [always]),
            BlockedSite(domain: "disabled.com", isEnabled: false, days: [.monday], ranges: [always]),
        ])
        let active = ScheduleEvaluator.activeDomains(
            in: config, at: Fixture.date(.monday, 12), calendar: Fixture.calendar
        )
        expectEqual(active, ["alpha.com", "zeta.com"])
    }
}
