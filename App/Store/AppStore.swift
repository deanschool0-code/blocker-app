import Foundation
import SwiftUI
import Observation
import SafariServices
import BlockerCore
#if canImport(WidgetKit)
import WidgetKit
#endif

enum ProtectionState: String { case on, partial, off, unknown }

struct PanicRequest: Identifiable, Equatable {
    let id = UUID()
    let source: UrgeSource
}

/// The one place the app's state lives and changes. Views read it and call its methods.
@MainActor
@Observable
final class AppStore {
    static let shared = AppStore()

    private(set) var data: AppData
    private(set) var protection: ProtectionState = .unknown
    private(set) var enabledBlockers: Set<String> = []
    private(set) var ruleError: String?
    private(set) var syncNote: String?
    var panicRequest: PanicRequest?
    var showSetupGuide = false

    let math = StreakMath()
    let meta = BlocklistMeta.load()

    @ObservationIgnored private let cloud = CloudSync()
    @ObservationIgnored private var started = false

    init() {
        data = Persistence.load()
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        cloud.onRemoteChange = { [weak self] payload in self?.mergeRemote(payload) }
        if data.syncEnabled {
            cloud.start()
            mergeRemote(cloud.pull())
        }
        // First run: make sure the extensions have their (empty) extra files.
        let firstRun = !FileManager.default.fileExists(atPath: Shared.extraRulesURL(slot: "B").path)
        writeRuleFiles(forceReload: firstRun)
        Task { await refreshProtection() }
        Reminders.reschedule(minutes: data.prefs.reminderMinutes, discreet: data.prefs.discreet, days: currentDays)
    }

    /// Called when the app comes to the front, and from background refresh on iPhone.
    func refresh() async {
        if data.syncEnabled { cloud.synchronize(); mergeRemote(cloud.pull()) }
        await refreshProtection()
    }

    // MARK: Derived

    var currentDays: Int { math.currentDays(data.streak) }
    var bestDays: Int { math.bestDays(data.streak) }
    var urgesRiddenOut: Int { data.urgeCounts.values.reduce(0, +) }
    var cleanDaysTotal: Int {
        guard let s = data.streak else { return 0 }
        let total = math.days(from: s.journeyStart, to: .now) + 1
        let resetDays = Set(data.resets.map { math.dayKey($0.at) }).count
        return max(0, total - resetDays)
    }
    var customRuleCount: Int { data.activeRules.count }
    static let customRuleLimit = 9_000

    // MARK: Onboarding & streak

    func finishOnboarding(start: Date, syncEnabled: Bool) {
        if data.streak == nil { data.streak = StreakInfo(start: start) }
        data.onboardingDone = true
        setSyncEnabled(syncEnabled, commitNow: false)
        commit()
    }

    func slip(at date: Date, note: String?) {
        guard let streak = data.streak else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        data.streak = math.reset(streak, at: date)
        data.resets.append(ResetItem(at: date, note: (trimmed?.isEmpty ?? true) ? nil : trimmed))
        commit()
        Reminders.reschedule(minutes: data.prefs.reminderMinutes, discreet: data.prefs.discreet, days: currentDays)
    }

    // MARK: Rules

    /// Returns a message for the person if the input can't be added, or nil on success.
    func addRule(kind: RuleKind, input: String) -> String? {
        let value: String
        switch kind {
        case .domain, .allow:
            switch DomainInput.normalise(input) {
            case .success(let v): value = v
            case .failure(.empty): return "Type a website address first."
            case .failure(.notADomain): return "That doesn’t look like a website address. Try something like example.com."
            case .failure(.protectedSite):
                return kind == .allow ? "That site is never blocked, so there’s nothing to allow."
                                      : "That site is needed by your device, so it can’t be blocked."
            }
        case .keyword:
            switch KeywordInput.normalise(input) {
            case .success(let v): value = v
            case .failure(.tooShort): return "Use at least 3 letters, so normal pages don’t get caught."
            case .failure(.tooLong): return "Keep it to 30 characters or fewer."
            case .failure(.badCharacters): return "Use one word: letters, numbers or a dash."
            }
        }
        if data.activeRules.contains(where: { $0.kind == kind && $0.value == value }) {
            return "Already on your list."
        }
        if customRuleCount >= Self.customRuleLimit {
            return "Your list is full (\(Self.customRuleLimit) entries). Remove a few first."
        }
        data.rules.append(BlockRuleItem(kind: kind, value: value))
        commit(rulesChanged: true)
        return nil
    }

    func removeRule(_ id: UUID) {
        guard let i = data.rules.firstIndex(where: { $0.id == id }) else { return }
        data.rules[i].deleted = true
        data.rules[i].updatedAt = .now
        commit(rulesChanged: true)
    }

    // MARK: Urges (panic flow)

    func requestPanic(source: UrgeSource) { panicRequest = PanicRequest(source: source) }

    func beginUrge(source: UrgeSource) -> UUID {
        let item = UrgeItem(source: source)
        data.urges.append(item)
        saveLocal()
        return item.id
    }

    func updateUrge(_ id: UUID, step: Int, action: String? = nil, finished: Bool = false) {
        guard let i = data.urges.firstIndex(where: { $0.id == id }) else { return }
        data.urges[i].stepsCompleted = min(4, max(data.urges[i].stepsCompleted, step))
        if let action { data.urges[i].chosenAction = action }
        if finished && data.urges[i].finishedAt == nil {
            data.urges[i].finishedAt = .now
            let key = math.dayKey(.now)
            data.urgeCounts[key, default: 0] += 1
            trimUrges()
            commit()
        } else {
            saveLocal()
        }
    }

    private func trimUrges() {
        let cutoff = Date.now.addingTimeInterval(-400 * 86_400)
        data.urges.removeAll { $0.startedAt < cutoff }
    }

    // MARK: Reason card

    func setReasonText(_ text: String) {
        data.reason = ReasonCard(text: String(text.prefix(280)))
        commit()
    }

    var reasonPhoto: PlatformImage? {
        guard let d = try? Data(contentsOf: Shared.reasonPhotoURL) else { return nil }
        return PlatformImage(data: d)
    }

    /// The photo stays on this device only. Never synced, never uploaded.
    func setReasonPhoto(_ imageData: Data?) {
        if let imageData {
            #if os(iOS)
            try? imageData.write(to: Shared.reasonPhotoURL, options: [.atomic, .completeFileProtection])
            #else
            try? imageData.write(to: Shared.reasonPhotoURL, options: [.atomic])
            #endif
        } else {
            try? FileManager.default.removeItem(at: Shared.reasonPhotoURL)
        }
        reasonPhotoVersion += 1
    }
    /// Bumped so views reload the photo after it changes.
    private(set) var reasonPhotoVersion = 0

    // MARK: Preferences

    func updatePrefs(_ change: (inout Preferences) -> Void) {
        let before = data.prefs
        change(&data.prefs)
        data.prefs.updatedAt = .now
        commit(rulesChanged: before.blockImageSearch != data.prefs.blockImageSearch)
        Reminders.reschedule(minutes: data.prefs.reminderMinutes, discreet: data.prefs.discreet, days: currentDays)
    }

    func setSyncEnabled(_ on: Bool, commitNow: Bool = true) {
        data.syncEnabled = on
        if on {
            cloud.start()
            mergeRemote(cloud.pull())
        } else {
            cloud.stop()
        }
        if commitNow { commit() }
    }

    // MARK: Data controls

    func exportFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("my-blocker-data.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(data) else { return nil }
        try? json.write(to: url, options: .atomic)
        return url
    }

    /// Wipes this device and the iCloud copy. The built-in list stays (it ships with the app).
    func deleteEverything() {
        if data.syncEnabled { cloud.wipe() }
        for url in [Shared.dataURL, Shared.snapshotURL, Shared.reasonPhotoURL,
                    Shared.extraRulesURL(slot: "A"), Shared.extraRulesURL(slot: "B"),
                    Shared.mergedRulesURL(slot: "A"), Shared.mergedRulesURL(slot: "B")] {
            try? FileManager.default.removeItem(at: url)
        }
        Reminders.cancel()
        data = AppData()
        reasonPhotoVersion += 1
        writeRuleFiles(forceReload: true)
        saveLocal()
    }

    // MARK: Protection state

    func refreshProtection() async {
        var enabled = Set<String>()
        for id in Shared.blockerIDs {
            if await Self.isBlockerEnabled(id) { enabled.insert(id) }
        }
        enabledBlockers = enabled
        protection = enabled.count == Shared.blockerIDs.count ? .on : (enabled.isEmpty ? .off : .partial)
        writeSnapshot()
    }

    nonisolated static func isBlockerEnabled(_ id: String) async -> Bool {
        await withCheckedContinuation { continuation in
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: id) { state, _ in
                continuation.resume(returning: state?.isEnabled ?? false)
            }
        }
    }

    // MARK: Saving, syncing, rule files

    private func commit(rulesChanged: Bool = false) {
        data.rules = SyncMerge.purgeTombstones(data.rules)
        saveLocal()
        if data.syncEnabled { syncNote = cloud.push(data) }
        if rulesChanged { writeRuleFiles(forceReload: false) }
    }

    private func saveLocal() {
        Persistence.save(data)
        writeSnapshot()
    }

    private func mergeRemote(_ payload: RemotePayload) {
        let before = data
        let merged = SyncMerge.apply(remote: payload, to: data)
        guard merged != before else { return }
        data = merged
        saveLocal()
        syncNote = cloud.push(data)       // send back the union so both sides converge
        if merged.rules != before.rules || merged.prefs.blockImageSearch != before.prefs.blockImageSearch {
            writeRuleFiles(forceReload: false)
        }
    }

    private func writeSnapshot() {
        let snap = Snapshot(currentStart: data.streak?.currentStart, bestDays: bestDays, protectedState: protection.rawValue)
        if let json = try? SyncCoding.encoder.encode(snap) {
            try? json.write(to: Shared.snapshotURL, options: .atomic)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Writes each extension's extra rules and asks Safari to reload the ones that changed.
    private func writeRuleFiles(forceReload: Bool) {
        let files: [(slot: String, id: String, rules: [ContentRule])] = [
            ("A", Shared.blockerA, RuleBuilder.extraRulesA(data: data)),
            ("B", Shared.blockerB, RuleBuilder.extraRulesB(data: data)),
        ]
        for file in files {
            guard let json = try? RuleBuilder.encode(file.rules) else { continue }
            let url = Shared.extraRulesURL(slot: file.slot)
            let old = try? Data(contentsOf: url)
            let changed = old != json
            if changed { try? json.write(to: url, options: .atomic) }
            if changed || forceReload { reloadBlocker(file.id) }
        }
    }

    private func reloadBlocker(_ id: String) {
        SFContentBlockerManager.reloadContentBlocker(withIdentifier: id) { [weak self] error in
            Task { @MainActor in
                if let error {
                    let ns = error as NSError
                    // Not enabled yet is normal during setup; anything else is worth showing.
                    self?.ruleError = ns.code == 1 ? nil : "Safari couldn’t load the rules (\(ns.domain) \(ns.code)). Your last working list is still active."
                } else {
                    self?.ruleError = nil
                }
            }
        }
    }
}

// MARK: - Local file

enum Persistence {
    static func load() -> AppData {
        guard let raw = try? Data(contentsOf: Shared.dataURL) else { return AppData() }
        if let data = try? SyncCoding.decoder.decode(AppData.self, from: raw) { return data }
        // Never silently overwrite a file we couldn't read: keep a copy next to it.
        let backup = Shared.containerURL.appendingPathComponent("data-unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? raw.write(to: backup)
        return AppData()
    }

    static func save(_ data: AppData) {
        guard let json = try? SyncCoding.encoder.encode(data) else { return }
        try? json.write(to: Shared.dataURL, options: [.atomic])
    }
}

// MARK: - Shipped list info

struct BlocklistMeta: Decodable {
    var listVersion: String
    var source: String
    var sourceURL: String
    var sourceLastModified: String
    var domainCount: Int
    var tldRules: [String]
    var ruleCountA: Int
    var ruleCountB: Int

    static func load() -> BlocklistMeta {
        guard let url = Bundle.main.url(forResource: "blocklist-meta", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let meta = try? JSONDecoder().decode(BlocklistMeta.self, from: raw)
        else {
            return BlocklistMeta(listVersion: "—", source: "The Block List Project", sourceURL: "https://github.com/blocklistproject/Lists",
                                 sourceLastModified: "—", domainCount: 0, tldRules: [], ruleCountA: 0, ruleCountB: 0)
        }
        return meta
    }
}
