import Foundation
import SiteBlockerCore

func runHostsFileTests() {
    section("HostsFile — entries")

    test("entries expand www and both IP families") {
        let entries = HostsFile.entries(for: ["example.com"])
        expectEqual(entries, [
            "127.0.0.1\texample.com",
            "::1\texample.com",
            "127.0.0.1\twww.example.com",
            "::1\twww.example.com",
        ])
    }

    test("entries for a www. domain are not doubled") {
        let entries = HostsFile.entries(for: ["www.example.com"])
        expectEqual(entries, [
            "127.0.0.1\twww.example.com",
            "::1\twww.example.com",
        ])
    }

    test("entries de-duplicate") {
        expectEqual(HostsFile.entries(for: ["example.com", "example.com"]).count, 4)
    }

    section("HostsFile — render / stripped")

    test("stripped removes only the managed section") {
        let base = "127.0.0.1\tlocalhost\n255.255.255.255\tbroadcasthost"
        let withSection = HostsFile.render(existing: base, blockedDomains: ["example.com"])
        expectTrue(withSection.contains(HostsFile.beginMarker))
        let stripped = HostsFile.stripped(withSection)
        expectFalse(stripped.contains(HostsFile.beginMarker))
        expectFalse(stripped.contains("example.com"))
        expectTrue(stripped.contains("localhost"))
        expectEqual(stripped, base)
    }

    test("render preserves base content and ends with newline") {
        let base = "127.0.0.1\tlocalhost"
        let rendered = HostsFile.render(existing: base, blockedDomains: ["example.com"])
        expectTrue(rendered.contains("127.0.0.1\tlocalhost"))
        expectTrue(rendered.contains("127.0.0.1\texample.com"))
        expectTrue(rendered.hasSuffix("\n"))
    }

    test("render is idempotent") {
        let base = "127.0.0.1\tlocalhost\n255.255.255.255\tbroadcasthost"
        let r1 = HostsFile.render(existing: base, blockedDomains: ["example.com", "reddit.com"])
        let r2 = HostsFile.render(existing: r1, blockedDomains: ["example.com", "reddit.com"])
        expectEqual(r1, r2)
    }

    test("render with no domains removes the section and keeps base") {
        let base = "127.0.0.1\tlocalhost"
        let blockedText = HostsFile.render(existing: base, blockedDomains: ["example.com"])
        let cleared = HostsFile.render(existing: blockedText, blockedDomains: [])
        expectFalse(cleared.contains(HostsFile.beginMarker))
        expectEqual(cleared, base + "\n")
    }

    test("render updates a changing domain set with a single section") {
        let base = "127.0.0.1\tlocalhost"
        let first = HostsFile.render(existing: base, blockedDomains: ["a.com"])
        let second = HostsFile.render(existing: first, blockedDomains: ["b.com"])
        expectFalse(second.contains("\ta.com"))
        expectTrue(second.contains("\tb.com"))
        let occurrences = second.components(separatedBy: HostsFile.beginMarker).count - 1
        expectEqual(occurrences, 1)
    }

    test("render handles an empty base") {
        let rendered = HostsFile.render(existing: "", blockedDomains: ["example.com"])
        expectTrue(rendered.contains(HostsFile.beginMarker))
        expectTrue(rendered.contains("example.com"))
        expectEqual(HostsFile.render(existing: "", blockedDomains: []), "")
    }

    section("HostsFile — blockedHostnames (reading the truth)")

    test("blockedHostnames parses the managed section") {
        let content = HostsFile.render(existing: "127.0.0.1\tlocalhost",
                                       blockedDomains: ["example.com", "reddit.com"])
        let hosts = HostsFile.blockedHostnames(in: content)
        expectTrue(hosts.contains("example.com"))
        expectTrue(hosts.contains("www.example.com"))
        expectTrue(hosts.contains("reddit.com"))
        expectFalse(hosts.contains("localhost"))   // outside the managed section
    }

    test("blockedHostnames is empty when there's no managed section") {
        expectEqual(HostsFile.blockedHostnames(in: "127.0.0.1\tlocalhost").count, 0)
        expectEqual(HostsFile.blockedHostnames(in: "").count, 0)
    }

    test("blockedHostnames round-trips with render") {
        let content = HostsFile.render(existing: "", blockedDomains: ["a.com"])
        expectTrue(HostsFile.blockedHostnames(in: content).contains("a.com"))
        let cleared = HostsFile.render(existing: content, blockedDomains: [])
        expectEqual(HostsFile.blockedHostnames(in: cleared).count, 0)
    }
}
