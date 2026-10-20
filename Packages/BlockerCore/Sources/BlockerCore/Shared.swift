import Foundation

/// Identifiers and file locations shared by the app and its extensions.
public enum Shared {
    public static let bundlePrefix = "com.deancarson.blocker"
    public static let blockerA = bundlePrefix + ".blockerA"
    public static let blockerB = bundlePrefix + ".blockerB"
    public static let blockerIDs = [blockerA, blockerB]

    /// App Group id comes from each target's Info.plist (`AppGroupIdentifier`), because macOS
    /// needs the team-prefixed form and iOS the `group.` form.
    public static var appGroupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String) ?? "group." + bundlePrefix
    }

    /// The shared container, or the app's own Application Support folder when the group isn't set up
    /// (for example in previews). Created on first use.
    public static var containerURL: URL {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("BlockerFallback", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var dataURL: URL { containerURL.appendingPathComponent("data.json") }
    public static var snapshotURL: URL { containerURL.appendingPathComponent("snapshot.json") }
    public static var reasonPhotoURL: URL { containerURL.appendingPathComponent("reason-photo.jpg") }

    /// The user's extra rules for one extension ("A" or "B").
    public static func extraRulesURL(slot: String) -> URL {
        containerURL.appendingPathComponent("extra-\(slot).json")
    }
    /// The merged file the extension hands to Safari.
    public static func mergedRulesURL(slot: String) -> URL {
        containerURL.appendingPathComponent("merged-\(slot).json")
    }
}
