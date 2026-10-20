import Foundation
import UserNotifications

/// Local notifications only. Nothing is sent to a server.
enum Reminders {
    static let dailyID = "daily-reminder"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(minutes: Int?, discreet: Bool, days: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
        guard let minutes else { return }

        let content = UNMutableNotificationContent()
        if discreet {
            content.title = "A minute for you"
            content.body = "Quick check-in. Open when you have a second."
        } else {
            content.title = days == 1 ? "1 day strong" : "\(days) days strong"
            content.body = "Keep the run going. If it gets hard, open the app and take a minute."
        }
        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        let request = UNNotificationRequest(
            identifier: dailyID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyID])
    }
}
