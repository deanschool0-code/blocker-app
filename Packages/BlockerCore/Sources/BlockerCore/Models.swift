import Foundation

// Data shared by the app, the content-blocker extensions and (later) the widget.
// Slice 1 keeps everything in one small Codable file in the App Group container,
// and syncs the same shapes through iCloud Key-Value Store. No server, no account.

public enum RuleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String { rawValue }
    case domain     // block this site and everything under it
    case keyword    // block pages whose address contains this word
    case allow      // never block this site, even if a list does
}

public struct BlockRuleItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: RuleKind
    public var value: String          // normalised
    public var createdAt: Date
    public var updatedAt: Date        // sync: newest wins per id
    public var deleted: Bool          // tombstone so a delete reaches the other device

    public init(id: UUID = UUID(), kind: RuleKind, value: String, now: Date = .now) {
        self.id = id; self.kind = kind; self.value = value
        self.createdAt = now; self.updatedAt = now; self.deleted = false
    }
}

public struct StreakInfo: Codable, Equatable, Sendable {
    public var journeyStart: Date     // first day the user started (for the calendar)
    public var currentStart: Date     // start of the current run
    public var bestDays: Int
    public var updatedAt: Date

    public init(start: Date, now: Date = .now) {
        journeyStart = start; currentStart = start; bestDays = 0; updatedAt = now
    }
}

public struct ResetItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var at: Date
    public var timeZoneID: String
    public var note: String?

    public init(id: UUID = UUID(), at: Date, timeZone: TimeZone = .current, note: String? = nil) {
        self.id = id; self.at = at; self.timeZoneID = timeZone.identifier; self.note = note
    }
}

public enum UrgeSource: String, Codable, Sendable { case app, menubar, shortcut, widget }

public struct UrgeItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var finishedAt: Date?
    public var stepsCompleted: Int    // 0...4: breathe, reason, play, plan
    public var chosenAction: String?
    public var source: UrgeSource

    public init(id: UUID = UUID(), startedAt: Date = .now, source: UrgeSource) {
        self.id = id; self.startedAt = startedAt; self.finishedAt = nil
        self.stepsCompleted = 0; self.chosenAction = nil; self.source = source
    }
}

public enum ReasonTone: String, Codable, CaseIterable, Sendable { case gentle, firm }

public struct Preferences: Codable, Equatable, Sendable {
    public var reminderMinutes: Int?          // minutes after midnight; nil = off
    public var discreet: Bool
    public var blockImageSearch: Bool
    public var tone: ReasonTone
    public var updatedAt: Date

    public init(now: Date = .now) {
        reminderMinutes = nil; discreet = true; blockImageSearch = false; tone = .gentle; updatedAt = now
    }
}

/// The user's own reason, shown in the panic flow. Text syncs; the photo never leaves the device.
public struct ReasonCard: Codable, Equatable, Sendable {
    public var text: String
    public var updatedAt: Date
    public init(text: String = "", now: Date = .now) { self.text = text; self.updatedAt = now }
}

public struct AppData: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var onboardingDone: Bool = false      // local only
    public var syncEnabled: Bool = true          // local only
    public var rules: [BlockRuleItem] = []
    public var streak: StreakInfo? = nil
    public var resets: [ResetItem] = []
    public var urges: [UrgeItem] = []            // local detail (last 400 days)
    public var urgeCounts: [String: Int] = [:]   // "yyyy-MM-dd" -> urges ridden out; synced
    public var prefs: Preferences = Preferences(now: Date(timeIntervalSince1970: 0))
    public var reason: ReasonCard = ReasonCard(now: Date(timeIntervalSince1970: 0))

    public init() {}

    // Tolerant decoding: a field added in a later version must never make an older file unreadable.
    enum CodingKeys: String, CodingKey {
        case schemaVersion, onboardingDone, syncEnabled, rules, streak, resets, urges, urgeCounts, prefs, reason
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let empty = AppData()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? empty.schemaVersion
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? empty.onboardingDone
        syncEnabled = try c.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? empty.syncEnabled
        rules = try c.decodeIfPresent([BlockRuleItem].self, forKey: .rules) ?? []
        streak = try c.decodeIfPresent(StreakInfo.self, forKey: .streak)
        resets = try c.decodeIfPresent([ResetItem].self, forKey: .resets) ?? []
        urges = try c.decodeIfPresent([UrgeItem].self, forKey: .urges) ?? []
        urgeCounts = try c.decodeIfPresent([String: Int].self, forKey: .urgeCounts) ?? [:]
        prefs = try c.decodeIfPresent(Preferences.self, forKey: .prefs) ?? empty.prefs
        reason = try c.decodeIfPresent(ReasonCard.self, forKey: .reason) ?? empty.reason
    }

    public var activeRules: [BlockRuleItem] { rules.filter { !$0.deleted } }
    public func activeRules(_ kind: RuleKind) -> [BlockRuleItem] {
        activeRules.filter { $0.kind == kind }.sorted { $0.value < $1.value }
    }
}

/// Small summary the app writes for the widget and the menu bar.
public struct Snapshot: Codable, Equatable, Sendable {
    public var currentStart: Date?
    public var bestDays: Int
    public var protectedState: String      // "on", "partial", "off", "unknown"
    public var writtenAt: Date
    public init(currentStart: Date?, bestDays: Int, protectedState: String, writtenAt: Date = .now) {
        self.currentStart = currentStart; self.bestDays = bestDays
        self.protectedState = protectedState; self.writtenAt = writtenAt
    }
}
