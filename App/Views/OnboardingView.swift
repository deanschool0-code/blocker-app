import SwiftUI
import BlockerCore

/// S01 Welcome → S02 Turn on the blocker → S03 Your start.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var step = 0
    @State private var startDate = Date.now
    @State private var syncOn = true

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: 3)
                .tint(Palette.accent)
                .padding(.horizontal, Space.l)
                .padding(.top, Space.m)
                .accessibilityLabel("Step \(step + 1) of 3")
            Group {
                switch step {
                case 0: welcome
                case 1: SetupGuideView(showsDoneButton: false, onContinue: { withAnimation(Motion.gentle) { step = 2 } })
                default: yourStart
                }
            }
            .transition(.opacity)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    // S01
    private var welcome: some View {
        ScreenScroll {
            Spacer(minLength: Space.xl)
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: Size.symbolHero))
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text("Take back your evenings.")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            Text("This app blocks adult sites in Safari, counts your clean days and gives you something to do when an urge hits.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)

            Card {
                promise("person.crop.circle.badge.xmark", "No account", "No email, no name, no sign-up.")
                promise("lock.shield", "Nothing leaves your device", "Safari does the blocking. We never see what you visit.")
                promise("icloud", "Your iCloud, not ours", "Your list and streak sync between your iPhone and Mac through your own iCloud.")
            }

            Text("This is a self-help tool, not medical treatment. If you’re struggling, talking to a professional can help.")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)

            Button("Get started") { withAnimation(Motion.gentle) { step = 1 } }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private func promise(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: symbol).font(Typo.title2).foregroundStyle(Palette.accent).frame(width: Size.iconColumn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(title).font(Typo.headline).foregroundStyle(Palette.textPrimary)
                Text(detail).font(Typo.callout).foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // S03
    private var yourStart: some View {
        ScreenScroll {
            Text("When did your run start?")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            Text("Pick today, or the last day you slipped if you’ve already been going for a while.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
            Card {
                DatePicker("Start", selection: $startDate, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
            Card {
                Toggle(isOn: $syncOn) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("Sync with my other devices").font(Typo.headline)
                        Text("Uses your own iCloud. Turn off to keep everything on this device only.")
                            .font(Typo.callout).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            Button("Start my run") {
                store.finishOnboarding(start: startDate, syncEnabled: syncOn)
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
    }
}

/// S02: how to switch the blocker on, with a live check. Also opened from the "blocker is off" banner.
struct SetupGuideView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton: Bool
    var onContinue: (() -> Void)? = nil

    var body: some View {
        ScreenScroll {
            Text("Turn on the blocker")
                .font(Typo.title).foregroundStyle(Palette.textPrimary)
            HStack { StatusPill(state: store.protection); Spacer() }

            Card {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, text in
                    HStack(alignment: .top, spacing: Space.m) {
                        Text("\(i + 1)")
                            .font(Typo.headline).foregroundStyle(Palette.onAccent)
                            .frame(width: Size.badge, height: Size.badge)
                            .background(Palette.accent, in: Circle())
                            .accessibilityHidden(true)
                        Text(text).font(Typo.body).foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(i + 1): \(text)")
                }
            }

            Card {
                SectionTitle(text: "Both switches")
                blockerRow(id: Shared.blockerA, name: "Blocker – Core list")
                blockerRow(id: Shared.blockerB, name: "Blocker – More sites & yours")
            }

            if store.protection == .partial {
                Text("One switch is still off. Turn on both so the full list is active.")
                    .font(Typo.callout).foregroundStyle(Palette.warning)
            }

            Button(openTitle) { SystemLinks.openBlockerSettings(extensionID: Shared.blockerA) }
                .buttonStyle(SecondaryButtonStyle())
            Button("Check again") { Task { await store.refresh() } }
                .buttonStyle(SecondaryButtonStyle())

            DisclosureGroup("Switch won’t turn on?") {
                VStack(alignment: .leading, spacing: Space.s) {
                    ForEach(troubleshooting, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb").font(Typo.callout).foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.top, Space.s)
            }
            .font(Typo.headline)

            if let onContinue {
                Button(store.protection == .on ? "Continue" : "I’ll do it later") { onContinue() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .navigationTitle("Setup")
        .inlineTitle()
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .task {
            // Re-check every second while this screen is open, so the switch turning on shows up live.
            while !Task.isCancelled {
                await store.refreshProtection()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func blockerRow(id: String, name: String) -> some View {
        let on = store.enabledBlockers.contains(id)
        return HStack {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(on ? Palette.clean : Palette.textSecondary)
            Text(name).font(Typo.body).foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(on ? "On" : "Off").font(Typo.callout).foregroundStyle(Palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var openTitle: String {
        #if os(iOS)
        "Open Settings"
        #else
        "Open Safari settings"
        #endif
    }

    private var steps: [String] {
        #if os(iOS)
        [
            "Open the Settings app.",
            "Go to Apps → Safari → Extensions. (On older iPhones: Safari → Extensions.)",
            "Turn on both “Blocker” switches.",
            "Come back here — this screen updates by itself.",
        ]
        #else
        [
            "Open Safari, then Safari → Settings (⌘,).",
            "Click the Extensions tab.",
            "Tick both “Blocker” boxes.",
            "Come back here — this screen updates by itself.",
        ]
        #endif
    }

    private var troubleshooting: [String] {
        #if os(iOS)
        [
            "Restart Safari: swipe it away in the app switcher, then open it again.",
            "If a switch is greyed out, a Screen Time limit may be on. Check Settings → Screen Time → Content & Privacy.",
            "Restart your iPhone, then try again.",
            "Delete and reinstall the app. Your streak comes back from iCloud if sync is on.",
        ]
        #else
        [
            "Quit Safari completely (⌘Q) and open it again.",
            "Open this app once after installing — Safari only lists extensions from apps that have been opened.",
            "Make sure the app is in your Applications folder.",
            "Restart your Mac, then try again.",
        ]
        #endif
    }
}
