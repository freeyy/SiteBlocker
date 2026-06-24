import Foundation

/// The display state of a single site at a moment in time, combining its schedule with whether
/// the system is actually enforcing (the daemon is installed and not paused).
public enum SiteBlockState: String, Sendable, Equatable {
    /// The site's own switch is off.
    case disabled
    /// Enabled, but its schedule is not active right now.
    case inactive
    /// Enabled, schedule active, and being enforced — actually blocked.
    case blocked
    /// Enabled and schedule active, but enforcement is off — it *would* block if enforcement were on.
    case scheduledNotEnforced
}

/// Pure logic deciding whether a site is blocked at a given instant.
public enum ScheduleEvaluator {
    /// The per-site display state, using the *actual* `/etc/hosts` contents as the source of truth
    /// for whether it is blocked, falling back to the schedule to explain non-blocked sites.
    ///
    /// - `isActuallyBlocked`: whether the site's domain is currently in the managed hosts section.
    public static func displayState(
        of site: BlockedSite,
        isActuallyBlocked: Bool,
        at date: Date,
        calendar: Calendar = .current
    ) -> SiteBlockState {
        guard site.isEnabled, !site.days.isEmpty else { return .disabled }
        if isActuallyBlocked { return .blocked }
        if isBlocked(site, at: date, calendar: calendar) { return .scheduledNotEnforced }
        return .inactive
    }

    /// Decompose a date into (weekday, minutes-since-midnight) using the given calendar.
    static func components(of date: Date, calendar: Calendar) -> (weekday: Weekday, minutes: Int) {
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let weekday = Weekday(rawValue: c.weekday ?? 1) ?? .sunday
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return (weekday, minutes)
    }

    /// Whether `site` is actively blocked at `date`.
    public static func isBlocked(
        _ site: BlockedSite,
        at date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard site.isEnabled, !site.days.isEmpty else { return false }

        let (weekday, now) = components(of: date, calendar: calendar)
        let prev = weekday.previous

        // No explicit ranges => block the whole selected day.
        if site.ranges.isEmpty {
            return site.days.contains(weekday)
        }

        for range in site.ranges where !range.isEmpty {
            if range.crossesMidnight {
                // Evening slice belongs to `weekday`; early-morning slice belongs to `prev`.
                if site.days.contains(weekday), now >= range.start.minutes { return true }
                if site.days.contains(prev), now < range.end.minutes { return true }
            } else {
                if site.days.contains(weekday), range.contains(minutes: now) { return true }
            }
        }
        return false
    }

    /// The set of canonical domains whose schedule is active right now, de-duplicated and sorted.
    /// This ignores the master switch and Secure-DNS option — see `domainsToBlock` for the final list.
    public static func activeDomains(
        in config: BlockConfig,
        at date: Date,
        calendar: Calendar = .current
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for site in config.sites where isBlocked(site, at: date, calendar: calendar) {
            if seen.insert(site.domain).inserted {
                result.append(site.domain)
            }
        }
        return result.sorted()
    }

    /// The final list of hostnames the helper should write to /etc/hosts right now, honoring the
    /// master switch and (when a block is active) the Secure-DNS option. De-duplicated and sorted.
    public static func domainsToBlock(
        in config: BlockConfig,
        at date: Date,
        calendar: Calendar = .current
    ) -> [String] {
        let active = activeDomains(in: config, at: date, calendar: calendar)
        guard config.blockSecureDNS, !active.isEmpty else { return active }
        // Only block DoH resolvers while something is actually being blocked, to limit side effects.
        var set = Set(active)
        set.formUnion(DoHResolvers.hostnames)
        return set.sorted()
    }
}
