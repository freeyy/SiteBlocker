import Foundation
import SiteBlockerCore

func runBlockPlanTests() {
    let always = TimeRange(start: .startOfDay, end: .endOfDay)
    func activeConfig(secureDNS: Bool = false) -> BlockConfig {
        BlockConfig(
            sites: [BlockedSite(domain: "reddit.com", days: Set(Weekday.allCases), ranges: [always])],
            blockSecureDNS: secureDNS
        )
    }
    let monNoon = Fixture.date(.monday, 12)

    section("BlockPlan — active site")

    test("Active site is blocked") {
        let domains = ScheduleEvaluator.domainsToBlock(in: activeConfig(), at: monNoon, calendar: Fixture.calendar)
        expectEqual(domains, ["reddit.com"])
    }

    section("BlockPlan — Secure DNS option")

    test("Secure DNS off does not add resolvers") {
        let domains = ScheduleEvaluator.domainsToBlock(in: activeConfig(secureDNS: false), at: monNoon, calendar: Fixture.calendar)
        expectFalse(domains.contains("dns.google"))
    }

    test("Secure DNS on adds resolvers while a block is active") {
        let domains = ScheduleEvaluator.domainsToBlock(in: activeConfig(secureDNS: true), at: monNoon, calendar: Fixture.calendar)
        expectTrue(domains.contains("reddit.com"))
        expectTrue(domains.contains("dns.google"))
        expectTrue(domains.contains("cloudflare-dns.com"))
        // all DoH resolvers present
        for host in DoHResolvers.hostnames { expectTrue(domains.contains(host), "missing \(host)") }
    }

    test("Secure DNS on does NOT add resolvers when nothing is actively blocked") {
        // A site scheduled only on Tuesday; evaluating on Monday => nothing active.
        let cfg = BlockConfig(
            sites: [BlockedSite(domain: "reddit.com", days: [.tuesday], ranges: [always])],
            blockSecureDNS: true
        )
        let domains = ScheduleEvaluator.domainsToBlock(in: cfg, at: monNoon, calendar: Fixture.calendar)
        expectEqual(domains, [])
    }

    section("BlockPlan — backward-compatible config decoding")

    test("Old config (incl. removed isBlockingEnabled flag) decodes cleanly") {
        let json = """
        { "version": 1, "sites": [], "isBlockingEnabled": false }
        """.data(using: .utf8)!
        do {
            let cfg = try ConfigStore.decode(json)
            expectEqual(cfg.sites.count, 0)      // unknown key ignored, no crash
            expectFalse(cfg.blockSecureDNS)       // defaults to false
        } catch { fail("decode threw: \(error)") }
    }

    test("blockSecureDNS round-trips through encode/decode") {
        do {
            let cfg = BlockConfig(sites: [], blockSecureDNS: true)
            let decoded = try ConfigStore.decode(try ConfigStore.encode(cfg))
            expectTrue(decoded.blockSecureDNS)
        } catch { fail("round-trip threw: \(error)") }
    }
}
