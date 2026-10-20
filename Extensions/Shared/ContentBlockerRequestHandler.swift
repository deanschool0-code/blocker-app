import Foundation
import BlockerCore

/// Safari asks this extension for its rules. We hand over the shipped list, with the person's
/// own rules (written by the app into the App Group) appended at the end.
/// The extension never sees which pages are visited: Safari applies the rules itself.
final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let item = NSExtensionItem()
        if let url = Self.rulesURL(), let provider = NSItemProvider(contentsOf: url) {
            item.attachments = [provider]
        }
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    /// "A" or "B", from this extension's Info.plist.
    static var slot: String {
        (Bundle.main.object(forInfoDictionaryKey: "BlockerSlot") as? String) ?? "A"
    }

    static func rulesURL() -> URL? {
        let slot = slot
        guard let bundled = Bundle.main.url(forResource: "blocker\(slot).base", withExtension: "json") else { return nil }
        guard let extra = try? Data(contentsOf: Shared.extraRulesURL(slot: slot)),
              !RuleFiles.isEmptyArray(extra),
              let base = try? Data(contentsOf: bundled, options: .mappedIfSafe)
        else { return bundled }

        let merged = RuleFiles.merge(base: base, extra: extra)
        let out = Shared.mergedRulesURL(slot: slot)
        do {
            try merged.write(to: out, options: .atomic)
            return out
        } catch {
            return bundled
        }
    }
}
