import SwiftUI
import BlockerCore
#if os(iOS)
import BackgroundTasks
#endif

@main
struct BlockerApp: App {
    @State private var store = AppStore.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(store)
                .tint(Palette.accent)
                .onAppear { store.start() }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) {
            await AppStore.shared.refresh()
            BackgroundRefresh.schedule()
        }
        #else
        .defaultSize(width: 960, height: 680)
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarView().environment(store)
        } label: {
            Image(systemName: store.protection == .on ? "sun.horizon.fill" : "sun.horizon")
        }
        #endif
    }
}

#if os(iOS)
enum BackgroundRefresh {
    static let id = "com.deancarson.blocker.refresh"

    /// Asks iOS to wake the app now and then, so sites added on the Mac reach Safari here.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
#endif
