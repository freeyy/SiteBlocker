import Foundation
import SiteBlockerCore

func runModelTests() {
    section("Model — TimeOfDay")

    test("TimeOfDay hour/minute and description") {
        let t = TimeOfDay(hour: 9, minute: 5)
        expectEqual(t.minutes, 545)
        expectEqual(t.hour, 9)
        expectEqual(t.minute, 5)
        expectEqual(t.description, "09:05")
    }

    test("TimeOfDay clamps to 0...1440") {
        expectEqual(TimeOfDay(minutes: -100).minutes, 0)
        expectEqual(TimeOfDay(minutes: 5000).minutes, 1440)
    }

    test("TimeOfDay end-of-day") {
        expectEqual(TimeOfDay.endOfDay.minutes, 1440)
        expectEqual(TimeOfDay.endOfDay.description, "24:00")
        expectEqual(TimeOfDay.startOfDay.description, "00:00")
    }

    test("TimeOfDay is comparable") {
        expectTrue(TimeOfDay(hour: 8, minute: 0) < TimeOfDay(hour: 8, minute: 1))
        expectTrue(TimeOfDay(hour: 23, minute: 59) > TimeOfDay(hour: 0, minute: 0))
    }

    section("Model — TimeRange")

    test("Normal range membership (start inclusive, end exclusive)") {
        let r = TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        expectFalse(r.isEmpty)
        expectFalse(r.crossesMidnight)
        expectTrue(r.contains(minutes: 9 * 60))
        expectTrue(r.contains(minutes: 12 * 60))
        expectFalse(r.contains(minutes: 17 * 60))
        expectFalse(r.contains(minutes: 8 * 60 + 59))
    }

    test("Empty range contains nothing") {
        let r = TimeRange(startHour: 10, startMinute: 0, endHour: 10, endMinute: 0)
        expectTrue(r.isEmpty)
        expectFalse(r.contains(minutes: 10 * 60))
    }

    test("Cross-midnight range membership") {
        let r = TimeRange(startHour: 22, startMinute: 0, endHour: 2, endMinute: 0)
        expectTrue(r.crossesMidnight)
        expectTrue(r.contains(minutes: 23 * 60))
        expectTrue(r.contains(minutes: 1 * 60))
        expectFalse(r.contains(minutes: 2 * 60))
        expectFalse(r.contains(minutes: 12 * 60))
    }

    test("Full-day range covers the whole day") {
        let r = TimeRange(start: .startOfDay, end: .endOfDay)
        expectFalse(r.crossesMidnight)
        expectTrue(r.contains(minutes: 0))
        expectTrue(r.contains(minutes: 1439))
    }

    section("Model — Weekday")

    test("Weekday raw values match Calendar (Sun=1...Sat=7)") {
        expectEqual(Weekday.sunday.rawValue, 1)
        expectEqual(Weekday.saturday.rawValue, 7)
    }

    test("Weekday previous wraps correctly") {
        expectEqual(Weekday.monday.previous, .sunday)
        expectEqual(Weekday.sunday.previous, .saturday)
        expectEqual(Weekday.tuesday.previous, .monday)
    }

    test("Weekday mondayFirst order") {
        expectEqual(Weekday.mondayFirst.first, .monday)
        expectEqual(Weekday.mondayFirst.last, .sunday)
        expectEqual(Weekday.mondayFirst.count, 7)
    }
}
