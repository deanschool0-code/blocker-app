import Foundation

/// Safari content-blocker rule, in WebKit's JSON format.
public struct ContentRule: Codable, Equatable, Sendable {
    public struct Trigger: Codable, Equatable, Sendable {
        public var urlFilter: String
        public var resourceType: [String]?
        enum CodingKeys: String, CodingKey {
            case urlFilter = "url-filter"
            case resourceType = "resource-type"
        }
    }
    public struct Action: Codable, Equatable, Sendable { public var type: String }

    public var trigger: Trigger
    public var action: Action

    public static func block(_ filter: String, documentsOnly: Bool = false) -> ContentRule {
        ContentRule(trigger: .init(urlFilter: filter, resourceType: documentsOnly ? ["document"] : nil),
                    action: .init(type: "block"))
    }
    public static func allow(_ filter: String) -> ContentRule {
        ContentRule(trigger: .init(urlFilter: filter, resourceType: nil), action: .init(type: "ignore-previous-rules"))
    }
}

/// Builds the user's own rules. They are appended after the shipped list, so allow rules
/// (ignore-previous-rules) can undo a block from the list in the same extension.
/// WebKit's regex has no `|`, no `{n}` and no look-arounds, so every alternative is its own rule.
public enum RuleBuilder {

    /// Matches the domain and every subdomain, any scheme, any path.
    public static func domainFilter(_ domain: String) -> String {
        "^[^:]+://+([^:/]+\\.)?" + domain.replacingOccurrences(of: ".", with: "\\.") + "[/:]"
    }

    /// Extra rules for extension A: only allow rules (A carries the big shipped list).
    public static func extraRulesA(data: AppData) -> [ContentRule] {
        data.activeRules(.allow).map { .allow(domainFilter($0.value)) }
    }

    /// Extra rules for extension B: custom blocks, keywords, image search, then allow rules last.
    public static func extraRulesB(data: AppData) -> [ContentRule] {
        var rules: [ContentRule] = []
        rules += data.activeRules(.domain).map { .block(domainFilter($0.value)) }
        rules += data.activeRules(.keyword).map { .block($0.value, documentsOnly: true) }
        if data.prefs.blockImageSearch { rules += imageSearchRules }
        rules += data.activeRules(.allow).map { .allow(domainFilter($0.value)) }
        return rules
    }

    /// Image tabs of the big search engines. Off by default; turned on in Settings.
    public static let imageSearchRules: [ContentRule] = [
        .block("^https?://([^/]+\\.)?google\\.[a-z.]+/search\\?.*tbm=isch"),
        .block("^https?://([^/]+\\.)?google\\.[a-z.]+/search\\?.*udm=2"),
        .block("^https?://([^/]+\\.)?google\\.[a-z.]+/imghp"),
        .block("^https?://images\\.google\\.[a-z.]+/"),
        .block("^https?://([^/]+\\.)?bing\\.com/images/"),
        .block("^https?://([^/]+\\.)?duckduckgo\\.com/.*ia=images"),
        .block("^https?://([^/]+\\.)?duckduckgo\\.com/.*iax=images"),
        .block("^https?://images\\.search\\.yahoo\\.com/"),
    ]

    public static func encode(_ rules: [ContentRule]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try encoder.encode(rules)
    }
}

/// Joins the shipped JSON array with the user's extra JSON array, byte by byte,
/// so the 13 MB shipped list is never decoded.
public enum RuleFiles {
    public static func merge(base: Data, extra: Data) -> Data {
        let baseBody = innerBody(of: base)
        let extraBody = innerBody(of: extra)
        var out = Data("[".utf8)
        out.append(baseBody)
        if !baseBody.isEmpty && !extraBody.isEmpty { out.append(Data(",".utf8)) }
        out.append(extraBody)
        out.append(Data("]".utf8))
        return out
    }

    public static func isEmptyArray(_ data: Data) -> Bool { innerBody(of: data).isEmpty }

    /// The bytes between the outer `[` and `]`, trimmed. Empty for `[]` or garbage.
    static func innerBody(of data: Data) -> Data {
        let bytes = [UInt8](data)
        let space: Set<UInt8> = [0x20, 0x0A, 0x0D, 0x09]
        guard let first = bytes.firstIndex(where: { !space.contains($0) }),
              let last = bytes.lastIndex(where: { !space.contains($0) }),
              bytes[first] == UInt8(ascii: "["), bytes[last] == UInt8(ascii: "]"), last > first
        else { return Data() }
        let inner = bytes[(first + 1)..<last]
        guard let s = inner.firstIndex(where: { !space.contains($0) }),
              let e = inner.lastIndex(where: { !space.contains($0) }) else { return Data() }
        return Data(inner[s...e])
    }
}
