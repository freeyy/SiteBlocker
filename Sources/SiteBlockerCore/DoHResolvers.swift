import Foundation

/// Well-known DNS-over-HTTPS (DoH) resolver hostnames. Browsers with "Secure DNS" enabled resolve
/// names through one of these encrypted endpoints, bypassing /etc/hosts. By null-routing the
/// resolver hostnames while a block is active, the browser's secure DNS fails and it falls back to
/// the system resolver — which honors our block.
///
/// Limitation: a browser configured to bootstrap DoH via a hard-coded IP (rather than a hostname)
/// can still slip through; hostname blocking covers the overwhelming majority of real setups.
public enum DoHResolvers {
    public static let hostnames: [String] = [
        // Cloudflare
        "cloudflare-dns.com",
        "mozilla.cloudflare-dns.com",
        "chrome.cloudflare-dns.com",
        "one.one.one.one",
        // Google
        "dns.google",
        "dns.google.com",
        // Quad9
        "dns.quad9.net",
        "dns9.quad9.net",
        "dns11.quad9.net",
        // OpenDNS
        "doh.opendns.com",
        "doh.familyshield.opendns.com",
        // AdGuard
        "dns.adguard.com",
        "dns.adguard-dns.com",
        // NextDNS / ControlD / others
        "dns.nextdns.io",
        "dns.controld.com",
        "doh.dns.sb",
        "doh.cleanbrowsing.org",
    ]
}
