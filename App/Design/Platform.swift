import SwiftUI
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

extension View {
    /// Inline navigation titles on iPhone; no-op on Mac.
    @ViewBuilder func inlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Lowercase, no autocorrect: for typing web addresses and keywords.
    @ViewBuilder func addressField() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
        #else
        self.autocorrectionDisabled()
        #endif
    }

    /// Full-screen on iPhone, sheet on Mac.
    @ViewBuilder func coverOrSheet<Item: Identifiable, C: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> C) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, content: content)
        #else
        self.sheet(item: item) { value in content(value).frame(minWidth: Size.coverWidth, minHeight: Size.coverHeight) }
        #endif
    }
}

enum SystemLinks {
    /// Opens the place where the user turns the Safari extension on.
    @MainActor static func openBlockerSettings(extensionID: String) {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        SFSafariApplicationBridge.showSettings(extensionID: extensionID)
        #endif
    }
}

#if os(macOS)
import SafariServices
enum SFSafariApplicationBridge {
    static func showSettings(extensionID: String) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionID) { error in
            if error != nil {
                // Fall back to opening Safari; the steps on screen explain where to click.
                DispatchQueue.main.async {
                    if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                        NSWorkspace.shared.openApplication(at: safari, configuration: .init())
                    }
                }
            }
        }
    }
}
#endif
