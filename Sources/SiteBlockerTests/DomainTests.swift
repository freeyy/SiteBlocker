import Foundation
import SiteBlockerCore

func runDomainTests() {
    section("Domain — normalize")

    test("Basic normalization") {
        expectEqual(Domain.normalize("example.com"), "example.com")
        expectEqual(Domain.normalize("Example.COM"), "example.com")
        expectEqual(Domain.normalize("  example.com  "), "example.com")
    }

    test("Strips scheme") {
        expectEqual(Domain.normalize("https://example.com"), "example.com")
        expectEqual(Domain.normalize("http://example.com"), "example.com")
    }

    test("Strips leading www.") {
        expectEqual(Domain.normalize("www.example.com"), "example.com")
        expectEqual(Domain.normalize("https://www.Reddit.com"), "reddit.com")
    }

    test("Strips path, query, fragment, port") {
        expectEqual(Domain.normalize("https://www.example.com/path?q=1#frag"), "example.com")
        expectEqual(Domain.normalize("example.com:8080"), "example.com")
        expectEqual(Domain.normalize("example.com/some/path"), "example.com")
    }

    test("Strips user-info and trailing dot") {
        expectEqual(Domain.normalize("user:pass@example.com"), "example.com")
        expectEqual(Domain.normalize("example.com."), "example.com")
    }

    test("Keeps subdomains") {
        expectEqual(Domain.normalize("news.ycombinator.com"), "news.ycombinator.com")
        expectEqual(Domain.normalize("mail.google.com"), "mail.google.com")
    }

    test("Rejects invalid input") {
        expectNil(Domain.normalize(""))
        expectNil(Domain.normalize("   "))
        expectNil(Domain.normalize("localhost"))
        expectNil(Domain.normalize("has space.com"))
        expectNil(Domain.normalize("-bad.com"))
        expectNil(Domain.normalize("bad-.com"))
    }

    section("Domain — hostnames")

    test("hostnames expands www variant") {
        expectEqual(Domain.hostnames(for: "example.com"), ["example.com", "www.example.com"])
    }

    test("hostnames does not double www") {
        expectEqual(Domain.hostnames(for: "www.example.com"), ["www.example.com"])
    }

    test("hostnames rejects invalid") {
        expectEqual(Domain.hostnames(for: "not a domain"), [])
    }

    section("Domain — isValidHostname")

    test("isValidHostname") {
        expectTrue(Domain.isValidHostname("example.com"))
        expectTrue(Domain.isValidHostname("a.b.c.d.com"))
        expectFalse(Domain.isValidHostname("nodot"))
        expectFalse(Domain.isValidHostname(".com"))
        expectFalse(Domain.isValidHostname("a..b.com"))
    }
}
