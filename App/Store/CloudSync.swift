import Foundation
import BlockerCore

/// Sync through the person's own iCloud Key-Value Store. No account with us, no server of ours.
@MainActor
final class CloudSync {
    private let kvs = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?
    var onRemoteChange: ((RemotePayload) -> Void)?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onRemoteChange?(self.pull())
            }
        }
        kvs.synchronize()
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    func synchronize() { kvs.synchronize() }

    func pull() -> RemotePayload {
        RemotePayload(
            rules: decode([BlockRuleItem].self, SyncKeys.rules),
            streak: decode(StreakInfo.self, SyncKeys.streak),
            resets: decode([ResetItem].self, SyncKeys.resets),
            urgeCounts: decode([String: Int].self, SyncKeys.urges),
            prefs: decode(Preferences.self, SyncKeys.prefs),
            reason: decode(ReasonCard.self, SyncKeys.reason)
        )
    }

    /// Writes everything that syncs. Returns a note for Settings if something had to be held back.
    @discardableResult
    func push(_ data: AppData) -> String? {
        var values: [(String, Data)] = []
        func add<T: Encodable>(_ value: T?, _ key: String) {
            if let value, let json = try? SyncCoding.encoder.encode(value) { values.append((key, json)) }
        }
        add(data.rules, SyncKeys.rules)
        add(data.streak, SyncKeys.streak)
        add(data.resets, SyncKeys.resets)
        add(data.urgeCounts, SyncKeys.urges)
        add(data.prefs, SyncKeys.prefs)
        add(data.reason, SyncKeys.reason)

        let total = values.reduce(0) { $0 + $1.1.count }
        var note: String?
        if total > SyncKeys.maxBytes {
            // Keep the small, important keys; hold back the rule list.
            values.removeAll { $0.0 == SyncKeys.rules }
            note = "Your custom list is too big for iCloud sync. It still works on this device."
        }
        for (key, json) in values { kvs.set(json, forKey: key) }
        return note
    }

    func wipe() {
        for key in SyncKeys.all { kvs.removeObject(forKey: key) }
        kvs.synchronize()
    }

    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let raw = kvs.data(forKey: key) else { return nil }
        return try? SyncCoding.decoder.decode(T.self, from: raw)
    }
}
