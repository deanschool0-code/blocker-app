import SwiftUI
import BlockerCore

/// S04 Today, with the S11 "blocker is off" banner.
struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var addingSite = false

    var body: some View {
        ScreenScroll {
            HStack { StatusPill(state: store.protection); Spacer() }

            if store.protection == .off || store.protection == .partial {
                Banner(
                    title: store.protection == .off ? "Your blocker is switched off" : "Only part of your blocker is on",
                    message: "Safari isn’t using the full list right now. It takes a few seconds to fix.",
                    actionTitle: "Show me how",
                    action: { store.showSetupGuide = true })
            }

            streakHero

            PanicButton { store.requestPanic(source: .app) }

            Button {
                addingSite = true
            } label: {
                Label("Block a site", systemImage: "plus.circle.fill")
            }
            .buttonStyle(SecondaryButtonStyle())

            lastRunCard

            weekStrip

            if let error = store.ruleError {
                Text(error).font(Typo.callout).foregroundStyle(Palette.warning)
            }
        }
        .navigationTitle("Today")
        .sheet(isPresented: $addingSite) {
            AddRuleSheet(initialKind: .domain).environment(store)
        }
    }

    private var streakHero: some View {
        let days = store.currentDays
        return Card(padding: Space.xl) {
            Text(days == 1 ? "day" : "days")
                .font(Typo.headline).foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
            Text("\(days)")
                .font(Typo.hero).foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(days) \(days == 1 ? "day" : "days") clean")
            Text(heroLine(days))
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
            HStack(spacing: Space.m) {
                StatTile(value: "\(store.bestDays)", label: "Best run")
                StatTile(value: "\(store.urgesRiddenOut)", label: "Urges ridden out")
            }
        }
    }

    private func heroLine(_ days: Int) -> String {
        if StreakMath.milestones.contains(days) {
            return "\(days) \(days == 1 ? "day" : "days"). That’s a milestone — notice it."
        }
        switch days {
        case 0: return "Day one starts now. Just get through today."
        case 1...6: return "Early days are the hardest. You’re doing them."
        case 7...29: return "The habit is loosening its grip."
        default: return "This is who you are now."
        }
    }

    /// The most recent urge: when it started, whether it was finished, how long it took.
    @ViewBuilder
    private var lastRunCard: some View {
        if let run = store.data.urges.max(by: { $0.startedAt < $1.startedAt }) {
            Card {
                SectionTitle(text: "Last run")
                HStack(alignment: .firstTextBaseline) {
                    Text(run.finishedAt != nil ? "Finished" : "Left early")
                        .font(Typo.headline).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(run.startedAt, style: .relative)
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
                if let end = run.finishedAt {
                    let seconds = max(1, Int(end.timeIntervalSince(run.startedAt).rounded()))
                    Text("Took \(seconds) second\(seconds == 1 ? "" : "s").")
                        .font(Typo.callout).foregroundStyle(Palette.textSecondary)
                }
                if let action = run.chosenAction {
                    Text("Next step: \(action)")
                        .font(Typo.callout).foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    private var weekStrip: some View {
        let cal = store.math.calendar
        let days: [Date] = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: .now) }
        return Card {
            SectionTitle(text: "This week")
            HStack(spacing: Space.s) {
                ForEach(days, id: \.self) { day in
                    let state = store.math.state(of: day, streak: store.data.streak, resets: store.data.resets)
                    VStack(spacing: Space.xs) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                        Circle()
                            .fill(DayStyle.fill(state))
                            .overlay(Circle().strokeBorder(DayStyle.stroke(state), lineWidth: Size.focusRing))
                            .frame(width: Size.badge, height: Size.badge)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(DayStyle.label(state))")
                }
            }
        }
    }
}

/// How each calendar day state looks. Shared by Today and Progress.
enum DayStyle {
    static func fill(_ s: StreakMath.DayState) -> Color {
        switch s {
        case .clean: Palette.clean
        case .today: Palette.accentSoft
        case .reset: Palette.slip
        case .beforeStart, .future: Palette.surfaceRaised
        }
    }
    static func stroke(_ s: StreakMath.DayState) -> Color {
        s == .today ? Palette.accent : .clear
    }
    static func label(_ s: StreakMath.DayState) -> String {
        switch s {
        case .clean: "clean"
        case .today: "today"
        case .reset: "restarted"
        case .beforeStart: "before you started"
        case .future: "not yet"
        }
    }
}
