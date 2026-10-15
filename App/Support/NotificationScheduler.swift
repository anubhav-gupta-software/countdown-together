import Foundation
import UserNotifications

enum NotificationScheduler {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func reschedule(countdowns: [Countdown], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let ids = Set(countdowns.map(\.id.uuidString))
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { identifier in
            UUID(uuidString: identifier) != nil && !ids.contains(identifier)
        }
        center.removePendingNotificationRequests(withIdentifiers: stale + Array(ids))
        guard enabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let now = Date()
        for countdown in countdowns where countdown.targetDate > now {
            let content = UNMutableNotificationContent()
            content.title = countdown.title
            content.body = body(for: countdown)
            content.sound = .default
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: countdown.targetDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: countdown.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func body(for countdown: Countdown) -> String {
        switch countdown.kind {
        case .trip: "Your trip is here."
        case .date: "It's date night."
        case .event: "This one is today."
        case .anniversary: "Today's the day."
        case .custom: "Your countdown just hit zero."
        }
    }
}
