import SwiftUI
import BlockerCore

/// S05: Breathe → Your reason → Play → Plan → Done. Every step can be skipped; leaving early is fine.
struct PanicFlowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let source: UrgeSource

    enum Step: Int, CaseIterable { case breathe = 1, reason, play, plan, done }
    @State private var step: Step = .breathe
    @State private var urgeID: UUID?
    @State private var chosen: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch step {
                case .breathe: BreathingStep(onNext: { advance(to: .reason) })
                case .reason: ReasonStep(onNext: { advance(to: .play) })
                case .play: DotGameStep(onNext: { advance(to: .plan) })
                case .plan: planStep
                case .done: doneStep
                }
            }
            .frame(maxWidth: Size.maxReadable)
            .padding(Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .background(Palette.background.ignoresSafeArea())
        .onAppear { if urgeID == nil { urgeID = store.beginUrge(source: source) } }
    }

    private var header: some View {
        HStack {
            if step != .done {
                Text("Step \(step.rawValue) of 4")
                    .font(Typo.callout).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button(step == .done ? "Close" : "I’m OK now") { finishAndClose() }
                .font(Typo.callout.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Palette.accent)
                .keyboardShortcut(.cancelAction)
        }
        .padding(Space.l)
    }

    private func advance(to next: Step) {
        if let urgeID { store.updateUrge(urgeID, step: next.rawValue - 1) }
        withAnimation(Motion.gentle) { step = next }
    }

    private func finishAndClose() {
        // Counts as ridden out once they got past the breathing step.
        if let urgeID {
            store.updateUrge(urgeID, step: min(step.rawValue - 1, 4), action: chosen, finished: step.rawValue >= 2)
        }
        dismiss()
        store.panicRequest = nil
    }

    // Step 4
    private var planStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("What will you do for the next 10 minutes?")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            Text("Pick one and go do it now. Getting up and moving breaks the loop.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
                ForEach(PanicCopy.actions, id: \.self) { action in
                    Chip(title: action, selected: chosen == action) { chosen = action }
                }
            }
            Spacer()
            Button("Done — I’ve got this") {
                if let urgeID { store.updateUrge(urgeID, step: 4, action: chosen, finished: true) }
                withAnimation(Motion.gentle) { step = .done }
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
    }

    private var doneStep: some View {
        VStack(spacing: Space.l) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: Size.symbolHero)).foregroundStyle(Palette.clean)
                .accessibilityHidden(true)
            Text("You rode it out.")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            Text(chosen.map { "Now: \($0.lowercased())." } ?? "The wave passed. It always does.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Text("\(store.urgesRiddenOut) urges ridden out so far")
                .font(Typo.callout).foregroundStyle(Palette.textSecondary)
            Spacer()
            Button("Close") { dismiss(); store.panicRequest = nil }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Step 1: breathing (4 in, 4 hold, 6 out)

struct BreathingStep: View {
    var onNext: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now
    private let inhale = 4.0, hold = 4.0, exhale = 6.0
    private var cycle: Double { inhale + hold + exhale }
    private let cycles = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            let t = elapsed.truncatingRemainder(dividingBy: cycle)
            let phase = phaseInfo(t)
            let finished = elapsed >= cycle * Double(cycles)
            VStack(spacing: Space.xl) {
                Text("Breathe with the circle")
                    .font(Typo.title).foregroundStyle(Palette.textPrimary)
                ZStack {
                    Circle().fill(Palette.calmSoft)
                    Circle().fill(Palette.calm)
                        .scaleEffect(reduceMotion ? 0.7 : phase.scale)
                    Text(phase.word)
                        .font(Typo.title2).foregroundStyle(Palette.onCalm)
                }
                .frame(width: Size.breathingRing, height: Size.breathingRing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(phase.word)
                ProgressView(value: min(elapsed, cycle * Double(cycles)), total: cycle * Double(cycles))
                    .tint(Palette.calm)
                    .accessibilityLabel("Breathing progress")
                Text(finished ? "Good. Your body is calmer than a minute ago." : "Urges peak and fade, usually within a few minutes.")
                    .font(Typo.callout).foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button(finished ? "Next" : "Skip ahead", action: onNext)
                    .buttonStyle(finished ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(SecondaryButtonStyle()))
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func phaseInfo(_ t: Double) -> (word: String, scale: CGFloat) {
        let small: CGFloat = 0.45, big: CGFloat = 1.0
        if t < inhale { return ("Breathe in", small + (big - small) * CGFloat(t / inhale)) }
        if t < inhale + hold { return ("Hold", big) }
        let p = (t - inhale - hold) / exhale
        return ("Breathe out", big - (big - small) * CGFloat(p))
    }
}

/// Lets two button styles share one call site.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: - Step 2: your reason

struct ReasonStep: View {
    @Environment(AppStore.self) private var store
    var onNext: () -> Void
    @State private var builtIn = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Remember why")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            let _ = store.reasonPhotoVersion
            if let photo = store.reasonPhoto {
                Image(platformImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: Size.reasonPhoto)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.l))
                    .accessibilityLabel("Your reason photo")
            }
            let text = store.data.reason.text.trimmingCharacters(in: .whitespacesAndNewlines)
            Card {
                Text(text.isEmpty ? builtIn : text)
                    .font(Typo.title2).foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if text.isEmpty {
                    Text("Add your own reason and photo in Settings → My reason. It hits harder in your own words.")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer()
            Button("Next", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .onAppear { builtIn = PanicCopy.line(for: store.data.prefs.tone) }
    }
}

// MARK: - Step 3: tap the dots (20 seconds of something else to do with your hands and eyes)

struct DotGameStep: View {
    var onNext: () -> Void
    struct Dot: Identifiable { let id = UUID(); let x: CGFloat; let y: CGFloat }
    @State private var dots: [Dot] = []
    @State private var score = 0
    @State private var secondsLeft = 20

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Catch the dots")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            HStack {
                Text("Caught: \(score)").font(Typo.headline).monospacedDigit()
                Spacer()
                Text(secondsLeft > 0 ? "\(secondsLeft)s" : "Time’s up").font(Typo.headline).monospacedDigit()
            }
            .foregroundStyle(Palette.textSecondary)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.l).fill(Palette.surface)
                    ForEach(dots) { dot in
                        Button {
                            withAnimation(Motion.quick) { dots.removeAll { $0.id == dot.id } }
                            score += 1
                        } label: {
                            Circle().fill(Palette.calm)
                                .frame(width: Size.dot, height: Size.dot)
                        }
                        .buttonStyle(.plain)
                        .position(x: Size.dot / 2 + dot.x * max(1, geo.size.width - Size.dot),
                                  y: Size.dot / 2 + dot.y * max(1, geo.size.height - Size.dot))
                        .transition(.scale)
                        .accessibilityLabel("Dot")
                    }
                }
            }
            .frame(minHeight: Size.gameArea)
            Button(secondsLeft > 0 ? "Skip" : "Next", action: onNext)
                .buttonStyle(secondsLeft > 0 ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
                .keyboardShortcut(.defaultAction)
        }
        .task {
            var tick = 0
            while secondsLeft > 0 && !Task.isCancelled {
                if dots.count < 4 {
                    withAnimation(Motion.quick) {
                        dots.append(Dot(x: .random(in: 0...1), y: .random(in: 0...1)))
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
                tick += 1
                if tick % 2 == 0 { secondsLeft -= 1 }
                if tick % 3 == 0, dots.count > 2 { _ = withAnimation(Motion.quick) { dots.removeFirst() } }
            }
            withAnimation(Motion.quick) { dots.removeAll() }
        }
    }
}

// MARK: - Copy (all original)

enum PanicCopy {
    static let actions = [
        "Go for a walk", "Cold water on my face", "Text a friend", "20 push-ups",
        "Leave this room", "Shower", "Make something to eat", "Phone in another room, sleep",
    ]

    static let gentle = [
        "This feeling is a wave. It rises, peaks and passes. You don’t have to act on it.",
        "You’ve already done the hardest part: you stopped and opened this.",
        "Tomorrow-you will be glad you gave this ten minutes.",
        "You’re not your urges. You’re the one deciding what happens next.",
        "Every time you ride one out, the next one is a little weaker.",
        "Be kind to yourself and still say no. Both are possible.",
        "Nothing on that screen will feel better than keeping your word to yourself.",
        "Breathe. Stand up. Change the room. That’s enough for now.",
    ]

    static let firm = [
        "You said you’d be better than this. Prove it tonight.",
        "You know exactly how this ends. Close it and walk away.",
        "Ten minutes of discipline or another morning of regret. Choose.",
        "Your streak is on the line. Protect it.",
        "Get up. Move. You don’t negotiate with this.",
        "The person you want to become doesn’t do this. Be that person now.",
        "You’ve beaten this before. Do it again.",
        "Not today. Put the phone down and go.",
    ]

    static func line(for tone: ReasonTone) -> String {
        (tone == .firm ? firm : gentle).randomElement() ?? gentle[0]
    }
}
