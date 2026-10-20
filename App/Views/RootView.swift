import SwiftUI
import BlockerCore

enum AppSection: String, CaseIterable, Identifiable {
    case today, progress, blockList, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "Today"
        case .progress: "Progress"
        case .blockList: "Block list"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .today: "sun.horizon"
        case .progress: "calendar"
        case .blockList: "shield.lefthalf.filled"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var section: AppSection = .today

    var body: some View {
        @Bindable var store = store
        Group {
            if store.data.onboardingDone {
                main
            } else {
                OnboardingView()
            }
        }
        .coverOrSheet(item: $store.panicRequest) { request in
            PanicFlowView(source: request.source)
                .environment(store)
        }
        .sheet(isPresented: $store.showSetupGuide) {
            NavigationStack {
                SetupGuideView(showsDoneButton: true)
                    .environment(store)
            }
            #if os(macOS)
            .frame(minWidth: Size.coverWidth, minHeight: Size.coverHeight)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
            #if os(iOS)
            if phase == .background { BackgroundRefresh.schedule() }
            #endif
        }
    }

    @ViewBuilder private var main: some View {
        #if os(iOS)
        TabView(selection: $section) {
            ForEach(AppSection.allCases) { s in
                NavigationStack { screen(for: s) }
                    .tabItem { Label(s.title, systemImage: s.symbol) }
                    .tag(s)
            }
        }
        #else
        NavigationSplitView {
            List(AppSection.allCases, selection: Binding(get: { Optional(section) }, set: { section = $0 ?? .today })) { s in
                Label(s.title, systemImage: s.symbol).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            NavigationStack { screen(for: section) }
        }
        #endif
    }

    @ViewBuilder private func screen(for s: AppSection) -> some View {
        switch s {
        case .today: TodayView()
        case .progress: ProgressCalendarView()
        case .blockList: BlockListView()
        case .settings: SettingsView()
        }
    }
}
