import SwiftUI
import PhotosUI
import BlockerCore
#if os(macOS)
import ServiceManagement
#endif

/// S10 Settings.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmDelete = false
    @State private var exportURL: URL?
    #if os(macOS)
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    #endif

    var body: some View {
        Form {
            Section("Protection") {
                HStack { Text("Safari blocker"); Spacer(); StatusPill(state: store.protection) }
                Button("How to turn it on") { store.showSetupGuide = true }
                NavigationLink("What this blocks — and what it can’t") { WhatThisBlocksView() }
            }

            Section {
                NavigationLink {
                    ReasonEditorView()
                } label: {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("My reason")
                        Text(store.data.reason.text.isEmpty ? "Add a photo and your own words" : store.data.reason.text)
                            .font(Typo.caption).foregroundStyle(Palette.textSecondary).lineLimit(1)
                    }
                }
                Picker("Tone of built-in messages", selection: Binding(
                    get: { store.data.prefs.tone },
                    set: { tone in store.updatePrefs { $0.tone = tone } })) {
                    Text("Gentle").tag(ReasonTone.gentle)
                    Text("Firm").tag(ReasonTone.firm)
                }
            } header: {
                Text("When an urge hits")
            } footer: {
                Text("Firm is direct and pushes you. It never insults you.")
            }

            Section {
                Toggle("Daily reminder", isOn: Binding(
                    get: { store.data.prefs.reminderMinutes != nil },
                    set: { on in
                        Task {
                            if on, await Reminders.requestPermission() == false { return }
                            store.updatePrefs { $0.reminderMinutes = on ? 21 * 60 : nil }
                        }
                    }))
                if let minutes = store.data.prefs.reminderMinutes {
                    DatePicker("Time", selection: Binding(
                        get: { Self.date(fromMinutes: minutes) },
                        set: { d in store.updatePrefs { $0.reminderMinutes = Self.minutes(from: d) } }),
                               displayedComponents: .hourAndMinute)
                }
                Toggle("Discreet wording", isOn: Binding(
                    get: { store.data.prefs.discreet },
                    set: { on in store.updatePrefs { $0.discreet = on } }))
            } header: {
                Text("Reminders")
            } footer: {
                Text("Discreet notifications never mention what this app is for.")
            }

            Section {
                Toggle("Sync with iCloud", isOn: Binding(
                    get: { store.data.syncEnabled },
                    set: { store.setSyncEnabled($0) }))
                if let note = store.syncNote {
                    Text(note).font(Typo.caption).foregroundStyle(Palette.warning)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Your sites, streak, reason text and settings sync through your own iCloud. Your photo and urge details stay on this device.")
            }

            #if os(macOS)
            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            } header: {
                Text("Mac")
            } footer: {
                Text("Keeps the menu-bar icon running, so sites you add on your iPhone are blocked on this Mac within seconds.")
            }
            #endif

            Section {
                if let exportURL {
                    ShareLink("Export my data", item: exportURL)
                } else {
                    Button("Prepare export") { exportURL = store.exportFile() }
                }
                Button("Delete all my data", role: .destructive) { confirmDelete = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("No account, no tracking, no analytics. Deleting removes everything on this device and in your iCloud copy.")
            }

            Section("About") {
                NavigationLink("Acknowledgements") { AcknowledgementsView() }
                Text("This app is a self-help tool, not medical advice or treatment. If you’re struggling, please talk to a doctor or counsellor.")
                    .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                LabeledContent("Version", value: Self.version)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .confirmationDialog("Delete everything?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all my data", role: .destructive) { store.deleteEverything() }
        } message: {
            Text("Your streak, history, lists and reason will be removed from this device and from iCloud. This can’t be undone.")
        }
    }

    static func date(fromMinutes m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now
    }
    static func minutes(from d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 21) * 60 + (c.minute ?? 0)
    }
    static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }
}

/// "My reason": the person's own photo and words, shown in the panic flow.
struct ReasonEditorView: View {
    @Environment(AppStore.self) private var store
    @State private var text = ""
    @State private var pick: PhotosPickerItem?
    @State private var loadError: String?

    var body: some View {
        Form {
            Section {
                let _ = store.reasonPhotoVersion
                if let photo = store.reasonPhoto {
                    Image(platformImage: photo)
                        .resizable().scaledToFill()
                        .frame(height: Size.reasonPhoto)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
                        .accessibilityLabel("Your reason photo")
                }
                PhotosPicker(store.reasonPhoto == nil ? "Choose a photo" : "Change photo", selection: $pick, matching: .images)
                if store.reasonPhoto != nil {
                    Button("Remove photo", role: .destructive) { store.setReasonPhoto(nil) }
                }
                if let loadError { Text(loadError).foregroundStyle(Palette.warning) }
            } header: {
                Text("Photo")
            } footer: {
                Text("Someone or something you’re doing this for: a goal, a place, the person you want to be. It stays on this device only.")
            }

            Section {
                TextField("In your own words: why does this matter?", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .onSubmit { store.setReasonText(text) }
                Text("\(text.count)/280").font(Typo.caption).foregroundStyle(Palette.textSecondary)
            } header: {
                Text("Your words")
            } footer: {
                Text("Write it like you’re talking to yourself at your weakest moment. Firm is fine — cruel doesn’t help.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("My reason")
        .onAppear { text = store.data.reason.text }
        .onDisappear { if text != store.data.reason.text { store.setReasonText(text) } }
        .onChange(of: text) { _, new in if new.count > 280 { text = String(new.prefix(280)) } }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        store.setReasonPhoto(data)
                        loadError = nil
                    }
                } catch {
                    loadError = "That photo couldn’t be loaded. Try another one."
                }
            }
        }
    }
}

struct WhatThisBlocksView: View {
    var body: some View {
        ScreenScroll {
            Text("What this blocks").font(Typo.title).foregroundStyle(Palette.textPrimary)
            Card {
                bullet("checkmark.circle.fill", Palette.clean, "Hundreds of thousands of known adult sites in Safari, in normal and Private tabs.")
                bullet("checkmark.circle.fill", Palette.clean, "Every site ending in .xxx, .porn, .sex and .adult.")
                bullet("checkmark.circle.fill", Palette.clean, "Any site or keyword you add, synced to your other devices.")
                bullet("checkmark.circle.fill", Palette.clean, "Image search tabs, if you turn that on.")
            }
            Text("What it can’t block (yet)").font(Typo.title2).foregroundStyle(Palette.textPrimary)
            Card {
                bullet("xmark.circle.fill", Palette.slip, "Other browsers like Chrome, Firefox or Brave. Safari blockers only work in Safari.")
                bullet("xmark.circle.fill", Palette.slip, "Apps (social media, messaging) and their built-in browsers.")
                bullet("xmark.circle.fill", Palette.slip, "Turning the blocker off in Settings. Apple lets anyone switch Safari extensions off.")
                bullet("xmark.circle.fill", Palette.slip, "New sites that aren’t on any list yet — add them yourself.")
            }
            Text("Deeper blocking for every browser on iPhone and Mac, and a cooling-off timer before you can switch protection off, are coming in a later version. No blocker is a perfect wall; it’s there to give you a pause at the moment you need one.")
                .font(Typo.callout).foregroundStyle(Palette.textSecondary)
        }
        .navigationTitle("What this blocks")
    }

    private func bullet(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
            Text(text).font(Typo.body).foregroundStyle(Palette.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AcknowledgementsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScreenScroll {
            Text("Acknowledgements").font(Typo.title).foregroundStyle(Palette.textPrimary)
            Card {
                Text("The Block List Project").font(Typo.headline)
                Text("Adult-site list, released into the public domain (The Unlicense; the list file states MIT). Thank you to its maintainers.")
                    .font(Typo.callout).foregroundStyle(Palette.textSecondary)
                Text(store.meta.sourceURL).font(Typo.mono).foregroundStyle(Palette.textSecondary).textSelection(.enabled)
                Text("Upstream version: \(store.meta.sourceLastModified)").font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
            Card {
                Text("StevenBlack/hosts").font(Typo.headline)
                Text("MIT licence. Used only to decide which domains go first.").font(Typo.callout).foregroundStyle(Palette.textSecondary)
            }
        }
        .navigationTitle("Acknowledgements")
    }
}
