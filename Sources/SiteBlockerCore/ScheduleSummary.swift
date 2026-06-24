import Foundation

public extension BlockedSite {
    /// Human-readable summary of which days this site is active, e.g. "Weekdays" or "Mon Wed Fri".
    var daysDescription: String {
        if days.isEmpty { return "Never" }
        if days.count == 7 { return "Every day" }
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekends: Set<Weekday> = [.saturday, .sunday]
        if days == weekdays { return "Weekdays" }
        if days == weekends { return "Weekends" }
        return Weekday.mondayFirst.filter { days.contains($0) }.map(\.shortName).joined(separator: " ")
    }

    /// Human-readable summary of the time windows, e.g. "All day" or "09:00–17:00, 20:00–22:00".
    var timesDescription: String {
        let active = ranges.filter { !$0.isEmpty }
        if active.isEmpty { return "All day" }
        return active
            .sorted { $0.start.minutes < $1.start.minutes }
            .map { "\($0.start.description)–\($0.end.description)" }
            .joined(separator: ", ")
    }

    /// Combined one-line schedule summary, e.g. "Weekdays · 09:00–17:00".
    var scheduleDescription: String {
        "\(daysDescription) · \(timesDescription)"
    }
}
