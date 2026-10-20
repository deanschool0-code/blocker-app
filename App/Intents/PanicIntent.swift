import AppIntents
import BlockerCore

/// One intent for Shortcuts, Siri, Spotlight and the Action button (and later the widget
/// and Control Center): opens the app straight into the urge exercise.
struct StartPanicIntent: AppIntent {
    static var title: LocalizedStringResource = "I need a minute"
    static var description = IntentDescription("Opens a short breathing and distraction exercise.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppStore.shared.requestPanic(source: .shortcut)
        return .result()
    }
}

struct BlockerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPanicIntent(),
            phrases: [
                "I need a minute in \(.applicationName)",
                "Start breathing in \(.applicationName)",
                "\(.applicationName) help me ride it out",
            ],
            shortTitle: "I need a minute",
            systemImageName: "wind"
        )
    }
}
