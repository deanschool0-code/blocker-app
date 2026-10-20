import SwiftUI
import BlockerCore

/// S06 Progress: month calendar of clean days, stats, and the way into S07 "I slipped".
struct ProgressCalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var month = Date.now
    @State private var slipping = false

    var body: some View {
        ScreenScroll {
            HStack(spacing: Space.m) {
                StatTile(value: "\(store.currentDays)", label: "Current run")
                StatTile(value: "\(store.bestDays)", label: "Best run")
            }
            HStack(spacing: Space.m) {
                StatTile(value: "\(store.cleanDaysTotal)", label: "Clean days in total")
                StatTile(value: "\(store.urgesRiddenOut)", label: "Urges ridden out")
            }

            Card {
                monthHeader
                weekdayHeader
                grid
                legend
            }

            if store.data.streak == nil {
                Text("Your calendar fills in once you start your run.")
                    .font(Typo.callout).foregroundStyle(Palette.textSecondary)
            }

            Button("I slipped") { slipping = true }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(store.data.streak == nil)
            Text("Slipping doesn’t erase your progress. Your history stays, and you start a new run straight away.")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)

            if !store.data.resets.isEmpty {
                Card {
                    SectionTitle(text: "Restarts")
                    ForEach(store.data.resets.sorted { $0.at > $1.at }.prefix(10)) { r in
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(r.at.formatted(date: .abbreviated, time: .omitted))
                                .font(Typo.body).foregroundStyle(Palette.textPrimary)
                            if let note = r.note {
                                Text(note).font(Typo.callout).foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Progress")
        .sheet(isPresented: $slipping) { SlipSheet().environment(store) }
    }

    private var monthHeader: some View {
        let cal = store.math.calendar
        let canGoForward = !cal.isDate(month, equalTo: .now, toGranularity: .month)
        return HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(Typo.headline).foregroundStyle(Palette.textPrimary)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(!canGoForward)
                .accessibilityLabel("Next month")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.accent)
    }

    private func shift(_ months: Int) {
        if let m = store.math.calendar.date(byAdding: .month, value: months, to: month) {
            withAnimation(Motion.quick) { month = m }
        }
    }

    private var weekdayHeader: some View {
        let cal = store.math.calendar
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        return HStack {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                Text(s).font(Typo.caption).foregroundStyle(Palette.textSecondary).frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        let cells = store.math.monthGrid(for: month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 7), spacing: Space.xs) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    let state = store.math.state(of: day, streak: store.data.streak, resets: store.data.resets)
                    Text(day.formatted(.dateTime.day()))
                        .font(Typo.callout.weight(state == .today ? .bold : .regular))
                        .foregroundStyle(state == .clean || state == .reset ? Palette.onAccent : Palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Size.calendarCell)
                        .background(DayStyle.fill(state), in: RoundedRectangle(cornerRadius: Radius.s))
                        .overlay(RoundedRectangle(cornerRadius: Radius.s).strokeBorder(DayStyle.stroke(state), lineWidth: Size.focusRing))
                        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)): \(DayStyle.label(state))")
                } else {
                    Color.clear.frame(minHeight: Size.calendarCell).accessibilityHidden(true)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Space.l) {
            legendItem(Palette.clean, "Clean")
            legendItem(Palette.slip, "Restarted")
            legendItem(Palette.accentSoft, "Today")
        }
        .font(Typo.caption)
        .foregroundStyle(Palette.textSecondary)
    }

    private func legendItem(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Space.xs) {
            RoundedRectangle(cornerRadius: Radius.s / 2).fill(color).frame(width: Space.m, height: Space.m)
            Text(text)
        }
    }
}

/// S07: "I slipped". Kind, quick, keeps history.
struct SlipSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var when = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("It happens. What matters is what you do next — and you’re already doing it.")
                        .font(Typo.body).foregroundStyle(Palette.textSecondary)
                }
                Section("When") {
                    DatePicker("Date", selection: $when, in: (store.data.streak?.journeyStart ?? .distantPast)...Date.now)
                }
                Section {
                    TextField("What led up to it? (optional, only you see this)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Note")
                } footer: {
                    Text("Spotting the pattern — time, place, mood — helps you plan for next time.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Start a new run")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start again") {
                        store.slip(at: when, note: note)
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: Size.sheetWidth, minHeight: Size.sheetHeight)
        #endif
    }
}
