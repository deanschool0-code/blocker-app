import Foundation

/// Streak and calendar maths. A "day" is the person's local calendar day.
public struct StreakMath: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) { self.calendar = calendar }

    /// Whole days since the run started. Starting today = 0.
    public func days(from start: Date, to now: Date) -> Int {
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    public func currentDays(_ streak: StreakInfo?, now: Date = .now) -> Int {
        guard let streak else { return 0 }
        return days(from: streak.currentStart, to: now)
    }

    public func bestDays(_ streak: StreakInfo?, now: Date = .now) -> Int {
        guard let streak else { return 0 }
        return max(streak.bestDays, currentDays(streak, now: now))
    }

    /// Applies "I slipped": keeps history, starts a new run at `at`.
    public func reset(_ streak: StreakInfo, at: Date, now: Date = .now) -> StreakInfo {
        var s = streak
        s.bestDays = max(s.bestDays, days(from: s.currentStart, to: at))
        s.currentStart = at
        s.updatedAt = now
        return s
    }

    public enum DayState: Equatable, Sendable { case beforeStart, clean, reset, today, future }

    public func state(of day: Date, streak: StreakInfo?, resets: [ResetItem], now: Date = .now) -> DayState {
        let d = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: now)
        if d > today { return .future }
        guard let streak else { return d == today ? .today : .beforeStart }
        if d < calendar.startOfDay(for: streak.journeyStart) { return .beforeStart }
        if resets.contains(where: { calendar.isDate($0.at, inSameDayAs: d) }) { return .reset }
        return d == today ? .today : .clean
    }

    /// Days of the month containing `month`, padded so the grid starts on the locale's first weekday.
    public func monthGrid(for month: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for i in 0..<count { cells.append(calendar.date(byAdding: .day, value: i, to: interval.start)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    public func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Milestones worth a quiet moment.
    public static let milestones: [Int] = [1, 3, 7, 14, 30, 60, 90, 180, 365]
}
