import SwiftUI
import BlockerCore

/// S08: the built-in list, plus the person's own sites, keywords and never-block list.
struct BlockListView: View {
    @Environment(AppStore.self) private var store
    @State private var adding: RuleKind?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack { StatusPill(state: store.protection); Spacer() }
                    Text("\(store.meta.domainCount.formatted()) adult sites blocked")
                        .font(Typo.title2).foregroundStyle(Palette.textPrimary)
                    Text("Plus every site ending in \(store.meta.tldRules.map { "." + $0 }.joined(separator: ", ")). Works in Private Browsing too.")
                        .font(Typo.callout).foregroundStyle(Palette.textSecondary)
                    Text("List: \(store.meta.source), version \(store.meta.listVersion)")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
                .padding(.vertical, Space.xs)
                NavigationLink("What this blocks — and what it can’t") { WhatThisBlocksView() }
                if let error = store.ruleError {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Palette.warning)
                }
                if let note = store.syncNote {
                    Label(note, systemImage: "icloud.slash").foregroundStyle(Palette.warning)
                }
            } header: {
                Text("Built-in list")
            }

            ruleSection(.domain, title: "Your sites",
                        empty: "Add any site you want gone. It’s blocked in Safari right away and on your other devices soon after.",
                        addTitle: "Block a site")
            ruleSection(.keyword, title: "Keywords",
                        empty: "Block any page whose address contains a word. Use specific words so normal pages aren’t caught.",
                        addTitle: "Add a keyword")

            Section {
                Toggle(isOn: Binding(
                    get: { store.data.prefs.blockImageSearch },
                    set: { on in store.updatePrefs { $0.blockImageSearch = on } })) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("Block image search")
                        Text("Turns off the Images tab on Google, Bing, DuckDuckGo and Yahoo in Safari.")
                            .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
            } header: {
                Text("Search")
            }

            ruleSection(.allow, title: "Never block",
                        empty: "If a normal site gets blocked by mistake, add it here and it will always load.",
                        addTitle: "Allow a site")
        }
        .navigationTitle("Block list")
        .sheet(item: $adding) { kind in AddRuleSheet(initialKind: kind).environment(store) }
    }

    @ViewBuilder
    private func ruleSection(_ kind: RuleKind, title: String, empty: String, addTitle: String) -> some View {
        let rules = store.data.activeRules(kind)
        Section {
            if rules.isEmpty {
                Text(empty).font(Typo.callout).foregroundStyle(Palette.textSecondary)
            }
            ForEach(rules) { rule in
                HStack {
                    Text(rule.value).font(Typo.body).foregroundStyle(Palette.textPrimary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    #if os(macOS)
                    Button { store.removeRule(rule.id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityLabel("Remove \(rule.value)")
                    #endif
                }
                .swipeActions {
                    Button(role: .destructive) { store.removeRule(rule.id) } label: { Label("Remove", systemImage: "trash") }
                }
                .contextMenu {
                    Button(role: .destructive) { store.removeRule(rule.id) } label: { Label("Remove", systemImage: "trash") }
                }
            }
            Button { adding = kind } label: { Label(addTitle, systemImage: "plus") }
        } header: {
            Text(rules.isEmpty ? title : "\(title) (\(rules.count))")
        }
    }
}

/// S09: add a site, keyword or never-block site.
struct AddRuleSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var initialKind: RuleKind
    @State private var text = ""
    @State private var message: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $initialKind) {
                        Text("Site").tag(RuleKind.domain)
                        Text("Keyword").tag(RuleKind.keyword)
                        Text("Never block").tag(RuleKind.allow)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: initialKind) { _, _ in message = nil }

                    TextField(placeholder, text: $text)
                        .addressField()
                        .focused($focused)
                        .onSubmit(add)
                        .onChange(of: text) { _, _ in message = nil }
                } footer: {
                    if let message {
                        Text(message).foregroundStyle(Palette.warning)
                    } else {
                        Text(hint)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        #if os(macOS)
        .frame(minWidth: Size.sheetWidth, minHeight: Size.sheetHeight / 1.6)
        #endif
    }

    private func add() {
        if let problem = store.addRule(kind: initialKind, input: text) {
            message = problem
        } else {
            dismiss()
        }
    }

    private var title: String {
        switch initialKind {
        case .domain: "Block a site"
        case .keyword: "Add a keyword"
        case .allow: "Never block a site"
        }
    }
    private var placeholder: String {
        initialKind == .keyword ? "keyword" : "example.com"
    }
    private var hint: String {
        switch initialKind {
        case .domain: "You can paste a full link. Everything on that site is blocked, including its subdomains."
        case .keyword: "Blocks any page whose address contains this word."
        case .allow: "This site will always load, even if a list blocks it."
        }
    }
}
