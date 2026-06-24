import Foundation

/// A day of the week. Raw values intentionally match `Calendar.component(.weekday, ...)`
/// where Sunday == 1 ... Saturday == 7, so we can convert without a lookup table.
public enum Weekday: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The day before this one (wrapping Sunday -> Saturday).
    public var previous: Weekday {
        Weekday(rawValue: self == .sunday ? 7 : rawValue - 1)!
    }

    /// Monday ... Sunday, the order most people expect to see in a week view.
    public static let mondayFirst: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]

    /// Short, localized-ish label (kept English+symbolic to stay dependency free).
    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

/// A wall-clock time of day, stored as minutes since midnight in the range 0...1440.
/// 1440 (i.e. 24:00) is a valid *end* of day, letting a range cover a whole day.
public struct TimeOfDay: Codable, Sendable, Hashable, Comparable, CustomStringConvertible {
    /// Minutes since midnight, clamped to 0...1440.
    public let minutes: Int

    public init(minutes: Int) {
        self.minutes = Swift.max(0, Swift.min(1440, minutes))
    }

    public init(hour: Int, minute: Int) {
        self.init(minutes: hour * 60 + minute)
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutes < rhs.minutes
    }

    /// "HH:mm" 24-hour formatting, e.g. "09:05" or "24:00".
    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static let startOfDay = TimeOfDay(minutes: 0)
    public static let endOfDay = TimeOfDay(minutes: 1440)
}

/// A contiguous block of time within a day.
///
/// - If `start < end` the range is a normal same-day window `[start, end)`.
/// - If `start > end` the range wraps past midnight (e.g. 22:00 -> 02:00); the portion
///   after midnight is considered to belong to the *start* day's schedule.
/// - If `start == end` the range is empty (blocks nothing).
public struct TimeRange: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var start: TimeOfDay
    public var end: TimeOfDay

    public init(id: UUID = UUID(), start: TimeOfDay, end: TimeOfDay) {
        self.id = id
        self.start = start
        self.end = end
    }

    public init(id: UUID = UUID(), startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.init(
            id: id,
            start: TimeOfDay(hour: startHour, minute: startMinute),
            end: TimeOfDay(hour: endHour, minute: endMinute)
        )
    }

    public var isEmpty: Bool { start.minutes == end.minutes }
    public var crossesMidnight: Bool { start.minutes > end.minutes }

    /// Whether `minutes` (since midnight) falls inside this range, ignoring day-of-week.
    /// For wrapping ranges this returns true for both the evening and the early-morning slice.
    public func contains(minutes: Int) -> Bool {
        if isEmpty { return false }
        if crossesMidnight {
            return minutes >= start.minutes || minutes < end.minutes
        }
        return minutes >= start.minutes && minutes < end.minutes
    }
}

/// A single domain to block, together with the schedule controlling *when* it is blocked.
///
/// Semantics:
/// - `isEnabled == false`  -> never blocked.
/// - `days` empty          -> never blocked.
/// - `ranges` empty        -> blocked for the entire selected day(s).
/// - otherwise             -> blocked when the current day is selected and the current time
///                            falls inside one of the ranges (see `TimeRange` for wrap rules).
public struct BlockedSite: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    /// Canonical domain, e.g. "example.com" (already normalized).
    public var domain: String
    public var isEnabled: Bool
    public var days: Set<Weekday>
    public var ranges: [TimeRange]

    public init(
        id: UUID = UUID(),
        domain: String,
        isEnabled: Bool = true,
        days: Set<Weekday> = Set(Weekday.allCases),
        ranges: [TimeRange] = []
    ) {
        self.id = id
        self.domain = domain
        self.isEnabled = isEnabled
        self.days = days
        self.ranges = ranges
    }
}

/// The full persisted configuration.
public struct BlockConfig: Codable, Sendable, Hashable {
    /// Bump when the on-disk schema changes in a breaking way.
    public static let currentVersion = 1

    public var version: Int
    public var sites: [BlockedSite]
    /// When true, the helper also blocks well-known DNS-over-HTTPS resolvers *while a site is
    /// actively blocked*, so browsers using "Secure DNS" fall back to the system resolver.
    public var blockSecureDNS: Bool

    public init(
        version: Int = BlockConfig.currentVersion,
        sites: [BlockedSite] = [],
        blockSecureDNS: Bool = false
    ) {
        self.version = version
        self.sites = sites
        self.blockSecureDNS = blockSecureDNS
    }

    private enum CodingKeys: String, CodingKey {
        case version, sites, blockSecureDNS
    }

    // Backward compatible: older configs (incl. a removed `isBlockingEnabled` flag) decode cleanly;
    // unknown keys are ignored and missing keys take sane defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? BlockConfig.currentVersion
        sites = try c.decodeIfPresent([BlockedSite].self, forKey: .sites) ?? []
        blockSecureDNS = try c.decodeIfPresent(Bool.self, forKey: .blockSecureDNS) ?? false
    }
}
