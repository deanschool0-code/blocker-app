import Foundation

/// Turns whatever a person types ("https://www.Example.com/videos?x=1", "bücher.de")
/// into the form the rules need ("example.com", "xn--bcher-kva.de").
public enum DomainInput {

    public enum Problem: Error, Equatable, Sendable {
        case empty
        case notADomain          // no dot, bad characters, too long
        case protectedSite       // e.g. apple.com — blocking it would break the device
    }

    /// Sites that must never be blocked from inside the app.
    public static let protectedSites: Set<String> = [
        "apple.com", "icloud.com", "google.com", "bing.com", "duckduckgo.com", "wikipedia.org",
    ]

    public static func normalise(_ raw: String) -> Result<String, Problem> {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return .failure(.empty) }

        // Strip scheme, credentials, path, query, fragment and port.
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        if let at = s.lastIndex(of: "@") { s = String(s[s.index(after: at)...]) }
        if let cut = s.firstIndex(where: { "/?#".contains($0) }) { s = String(s[..<cut]) }
        if let colon = s.lastIndex(of: ":") { s = String(s[..<colon]) }
        while s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        s = s.replacingOccurrences(of: "。", with: ".")   // ideographic full stop

        // Internationalised names → punycode, label by label.
        var labels: [String] = []
        for label in s.split(separator: ".", omittingEmptySubsequences: false).map(String.init) {
            if label.unicodeScalars.allSatisfy({ $0.isASCII }) {
                labels.append(label)
            } else if let encoded = Punycode.encode(label) {
                labels.append("xn--" + encoded)
            } else {
                return .failure(.notADomain)
            }
        }
        let domain = labels.joined(separator: ".")
        guard isValid(domain) else { return .failure(.notADomain) }
        guard !protectedSites.contains(domain) else { return .failure(.protectedSite) }
        return .success(domain)
    }

    public static func isValid(_ domain: String) -> Bool {
        guard domain.count <= 253 else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard (1...63).contains(label.count),
                  label.first != "-", label.last != "-",
                  label.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" })
            else { return false }
        }
        // Top-level label can't be all digits (rules out IP addresses).
        return !(labels.last!.allSatisfy { ("0"..."9").contains($0) })
    }
}

/// Keywords for "block pages whose address contains this word".
public enum KeywordInput {
    public enum Problem: Error, Equatable, Sendable { case tooShort, tooLong, badCharacters }

    public static func normalise(_ raw: String) -> Result<String, Problem> {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard s.count >= 3 else { return .failure(.tooShort) }
        guard s.count <= 30 else { return .failure(.tooLong) }
        guard s.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" })
        else { return .failure(.badCharacters) }
        return .success(s)
    }
}

/// RFC 3492 Punycode encoder (only encoding is needed).
public enum Punycode {
    private static let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700
    private static let initialBias = 72, initialN = 128

    public static func encode(_ input: String) -> String? {
        let scalars = input.unicodeScalars.map { Int($0.value) }
        var output = scalars.filter { $0 < 0x80 }.map { Character(UnicodeScalar(UInt8($0))) }
        let basicCount = output.count
        var handled = basicCount
        if basicCount > 0 { output.append("-") }

        var n = initialN, delta = 0, bias = initialBias
        while handled < scalars.count {
            guard let m = scalars.filter({ $0 >= n }).min() else { return nil }
            let (product, overflow) = (m - n).multipliedReportingOverflow(by: handled + 1)
            guard !overflow else { return nil }
            delta += product
            n = m
            for c in scalars {
                if c < n { delta += 1 }
                if c == n {
                    var q = delta
                    var k = base
                    while true {
                        let t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                        if q < t { break }
                        output.append(digit(t + (q - t) % (base - t)))
                        q = (q - t) / (base - t)
                        k += base
                    }
                    output.append(digit(q))
                    bias = adapt(delta, handled + 1, handled == basicCount)
                    delta = 0
                    handled += 1
                }
            }
            delta += 1
            n += 1
        }
        return String(output)
    }

    private static func digit(_ d: Int) -> Character {
        Character(UnicodeScalar(UInt8(d < 26 ? d + 97 : d + 22)))
    }

    private static func adapt(_ delta: Int, _ numPoints: Int, _ first: Bool) -> Int {
        var delta = first ? delta / damp : delta / 2
        delta += delta / numPoints
        var k = 0
        while delta > ((base - tMin) * tMax) / 2 {
            delta /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * delta / (delta + skew)
    }
}
