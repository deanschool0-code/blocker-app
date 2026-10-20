#if os(macOS)
import SwiftUI
import AppKit
import BlockerCore

/// Mac menu-bar item: streak at a glance and a one-click panic button.
/// Keeping it running is what lets iPhone changes reach Safari on the Mac within seconds.
struct MenuBarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(store.currentDays == 1 ? "1 day" : "\(store.currentDays) days")
        Text(store.protection.title)
        Divider()
        Button("I need a minute") {
            openMain()
            store.requestPanic(source: .menubar)
        }
        .keyboardShortcut("m")
        Button("Block a site…") {
            openMain()
        }
        Button("Open") { openMain() }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
