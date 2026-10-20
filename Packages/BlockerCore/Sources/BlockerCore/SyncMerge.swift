import Foundation

/// iCloud Key-Value Store layout and merge rules. Every merge is per item and idempotent:
/// applying the same remote value twice changes nothing, and nothing is ever "missing" —
/// deletes travel as tombstones.
public enum SyncKeys {
    public static let rules = "v1.rules"
    public static let streak = "v1.streak"
    public static let resets = "v1.resets"
    public static let urges = "v1.urges"
    public static let prefs = "v1.prefs"
    public static let reason = "v1.reason"
    public static let all = [rules, streak, resets, urges, prefs, reason]
    public static let maxBytes = 900_000
    public static let tombstoneDays = 90
}

public enum SyncMerge {

    public static func rules(local: [BlockRuleItem], remote: [BlockRuleItem]) -> [BlockRuleItem] {
        var byID: [UUID: BlockRuleItem] = [:]
        for item in local + remote {
            if let existing = byID[item.id], existing.updatedAt >= item.updatedAt { continue }
            byID[item.id] = item
        }
        // Two devices may add the same site with different ids: keep one live copy per (kind, value).
        var seen: Set<String> = []
        var out: [BlockRuleItem] = []
        for item in byID.values.sorted(by: { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }) {
            let key = item.kind.rawValue + "|" + item.value
            if !item.deleted {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            out.append(item)
        }
        return out
    }

    public static func purgeTombstones(_ rules: [BlockRuleItem], now: Date = .now) -> [BlockRuleItem] {
        let cutoff = now.addingTimeInterval(-Double(SyncKeys.tombstoneDays) * 86_400)
        return rules.filter { !$0.deleted || $0.updatedAt > cutoff }
    }

    public static func streak(local: StreakInfo?, remote: StreakInfo?) -> StreakInfo? {
        switch (local, remote) {
        case (nil, let r): return r
        case (let l, nil): return l
        case (let l?, let r?):
            var winner = l.updatedAt >= r.updatedAt ? l : r
            winner.journeyStart = min(l.journeyStart, r.journeyStart)
            winner.bestDays = max(l.bestDays, r.bestDays)
            return winner
        }
    }

    public static func resets(local: [ResetItem], remote: [ResetItem]) -> [ResetItem] {
        var byID: [UUID: ResetItem] = [:]
        for r in local + remote { byID[r.id] = r }
        return byID.values.sorted { $0.at < $1.at }
    }

    /// The current run starts at the latest reset, if that is later than the stored start.
    public static func reconcile(streak: StreakInfo?, resets: [ResetItem]) -> StreakInfo? {
        guard var s = streak else { return nil }
        if let last = resets.map(\.at).max(), last > s.currentStart { s.currentStart = last }
        return s
    }

    public static func counts(local: [String: Int], remote: [String: Int], keepDays: Int = 400, now: Date = .now) -> [String: Int] {
        var out = local.merging(remote) { max($0, $1) }
        if out.count > keepDays {
            let keep = Set(out.keys.sorted().suffix(keepDays))
            out = out.filter { keep.contains($0.key) }
        }
        return out
    }

    public static func newest<T>(_ local: T, _ remote: T?, date: (T) -> Date) -> T {
        guard let remote else { return local }
        return date(remote) > date(local) ? remote : local
    }

    /// Applies everything from the cloud onto local data. Local-only fields are untouched.
    public static func apply(remote: RemotePayload, to data: AppData) -> AppData {
        var d = data
        if let r = remote.rules { d.rules = rules(local: d.rules, remote: r) }
        if let r = remote.resets { d.resets = resets(local: d.resets, remote: r) }
        if let s = remote.streak { d.streak = streak(local: d.streak, remote: s) }
        d.streak = reconcile(streak: d.streak, resets: d.resets)
        if let c = remote.urgeCounts { d.urgeCounts = counts(local: d.urgeCounts, remote: c) }
        d.prefs = newest(d.prefs, remote.prefs) { $0.updatedAt }
        d.reason = newest(d.reason, remote.reason) { $0.updatedAt }
        return d
    }
}

/// What came down from iCloud. Every field is optional: a missing key means "nothing there yet",
/// never "delete everything".
public struct RemotePayload: Sendable {
    public var rules: [BlockRuleItem]?
    public var streak: StreakInfo?
    public var resets: [ResetItem]?
    public var urgeCounts: [String: Int]?
    public var prefs: Preferences?
    public var reason: ReasonCard?

    public init(rules: [BlockRuleItem]? = nil, streak: StreakInfo? = nil, resets: [ResetItem]? = nil,
                urgeCounts: [String: Int]? = nil, prefs: Preferences? = nil, reason: ReasonCard? = nil) {
        self.rules = rules; self.streak = streak; self.resets = resets
        self.urgeCounts = urgeCounts; self.prefs = prefs; self.reason = reason
    }
}

public enum SyncCoding {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]; return e
    }()
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
