import Foundation

/// Domain parsing / normalization helpers.
public enum Domain {
    /// Normalize raw user input into a canonical, lowercase, registrable-ish host.
    ///
    /// Examples:
    /// - "https://www.Example.com/path?q=1" -> "example.com"
    /// - "  WWW.Reddit.com  "                -> "reddit.com"
    /// - "news.ycombinator.com"              -> "news.ycombinator.com"
    /// - "example.com:8080"                  -> "example.com"
    /// Returns `nil` when the input cannot be interpreted as a hostname.
    public static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return nil }

        // Strip scheme.
        if let range = s.range(of: "://") {
            s = String(s[range.upperBound...])
        }

        // Strip user-info (user:pass@host).
        if let at = s.firstIndex(of: "@") {
            s = String(s[s.index(after: at)...])
        }

        // Strip path / query / fragment.
        for sep in ["/", "?", "#"] {
            if let i = s.firstIndex(of: Character(sep)) {
                s = String(s[..<i])
            }
        }

        // Strip port.
        if let colon = s.firstIndex(of: ":") {
            s = String(s[..<colon])
        }

        // Drop a trailing dot (FQDN form).
        while s.hasSuffix(".") { s.removeLast() }

        // Strip a single leading "www." so the canonical form is the bare domain.
        if s.hasSuffix(".") == false, s.hasPrefix("www.") {
            s = String(s.dropFirst(4))
        }

        guard isValidHostname(s) else { return nil }
        return s
    }

    /// A permissive hostname check: labels of [a-z0-9-] separated by dots, at least one dot,
    /// no leading/trailing hyphen in a label. (Punycode/IDN is accepted as-is once lowercased.)
    public static func isValidHostname(_ s: String) -> Bool {
        guard !s.isEmpty, s.count <= 253 else { return false }
        let labels = s.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            if label.first == "-" || label.last == "-" { return false }
            for ch in label {
                let ok = ch.isASCII && (ch.isLetter || ch.isNumber || ch == "-")
                if !ok { return false }
            }
        }
        return true
    }

    /// The concrete hostnames that should be redirected for a canonical domain.
    /// We block both the bare domain and its `www.` variant so the common cases are covered.
    public static func hostnames(for domain: String) -> [String] {
        guard isValidHostname(domain) else { return [] }
        if domain.hasPrefix("www.") {
            return [domain]
        }
        return [domain, "www." + domain]
    }
}
