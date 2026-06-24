import Foundation
import SiteBlockerCore

func runSiteBlockStateTests() {
    func state(_ site: BlockedSite, actuallyBlocked: Bool, _ wd: Weekday, _ h: Int) -> SiteBlockState {
        ScheduleEvaluator.displayState(of: site, isActuallyBlocked: actuallyBlocked,
                                       at: Fixture.date(wd, h), calendar: Fixture.calendar)
    }
    // Enabled, weekdays, all-day.
    let site = BlockedSite(domain: "x.com", isEnabled: true,
                           days: [.monday, .tuesday, .wednesday, .thursday, .friday], ranges: [])

    section("SiteBlockState — hosts truth vs schedule")

    test("Actually in hosts => blocked (the source of truth)") {
        expectEqual(state(site, actuallyBlocked: true, .monday, 12), .blocked)
        // Even if the schedule says inactive, a real hosts entry reads as blocked (truth).
        expectEqual(state(site, actuallyBlocked: true, .saturday, 12), .blocked)
    }

    test("Schedule active but NOT in hosts => scheduledNotEnforced (the user's bug)") {
        // Enabled + in-window, but the daemon hasn't applied it (or isn't installed).
        expectEqual(state(site, actuallyBlocked: false, .monday, 12), .scheduledNotEnforced)
    }

    test("Schedule inactive and not in hosts => inactive") {
        expectEqual(state(site, actuallyBlocked: false, .saturday, 12), .inactive)
    }

    test("Disabled site => disabled regardless of hosts/schedule") {
        let off = BlockedSite(domain: "x.com", isEnabled: false, days: Set(Weekday.allCases), ranges: [])
        expectEqual(state(off, actuallyBlocked: true, .monday, 12), .disabled)
        expectEqual(state(off, actuallyBlocked: false, .monday, 12), .disabled)
    }

    test("Empty days => disabled") {
        let none = BlockedSite(domain: "x.com", isEnabled: true, days: [], ranges: [])
        expectEqual(state(none, actuallyBlocked: false, .monday, 12), .disabled)
    }

    test("Time-window edges drive scheduledNotEnforced vs inactive when not in hosts") {
        let windowed = BlockedSite(domain: "x.com", days: [.monday],
                                   ranges: [TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)])
        expectEqual(state(windowed, actuallyBlocked: false, .monday, 10), .scheduledNotEnforced)
        expectEqual(state(windowed, actuallyBlocked: false, .monday, 17), .inactive) // end exclusive
        expectEqual(state(windowed, actuallyBlocked: true, .monday, 10), .blocked)
    }
}
