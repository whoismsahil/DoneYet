import Foundation
import UserNotifications

@MainActor
protocol ReminderNotificationScheduling: AnyObject {
    func schedule(for reminder: Reminder) async
    func cancel(for reminder: Reminder) async
}

enum ReminderNotificationIDs {
    static func requestID(for reminderID: UUID) -> String {
        "reminder-\(reminderID.uuidString)"
    }
}

struct ReminderNotificationSnapshot: Sendable {
    let id: UUID
    let title: String
    let isActive: Bool
    let hasScheduledTime: Bool
    let fireDate: Date?
    let iconEmoji: String?

    @MainActor
    init(_ reminder: Reminder) {
        id = reminder.id
        title = reminder.title
        isActive = reminder.isActive
        hasScheduledTime = reminder.hasScheduledTime
        iconEmoji = reminder.iconEmoji.isEmpty ? nil : reminder.iconEmoji
        if reminder.repeats {
            fireDate = reminder.nextOccurrence
        } else {
            fireDate = reminder.scheduledFireDate()
        }
    }
}

@MainActor
final class DefaultReminderNotificationScheduling: ReminderNotificationScheduling {
    func schedule(for reminder: Reminder) async {
        let snapshot = ReminderNotificationSnapshot(reminder)
        await ReminderNotificationScheduler.schedule(snapshot)
    }

    func cancel(for reminder: Reminder) async {
        await ReminderNotificationScheduler.cancelAll(id: reminder.id)
    }
}

enum ReminderNotificationScheduler {
    static func schedule(_ snapshot: ReminderNotificationSnapshot) async {
        guard snapshot.isActive, snapshot.hasScheduledTime else {
            await cancelPending(id: snapshot.id)
            return
        }

        guard let fireDate = snapshot.fireDate else {
            await cancelPending(id: snapshot.id)
            return
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }

        let authorized = await UNUserNotificationCenter.current().notificationSettings()
        guard authorized.authorizationStatus == .authorized || authorized.authorizationStatus == .provisional else {
            return
        }

        await cancelPending(id: snapshot.id)

        let content = makeContent(title: snapshot.title, reminderID: snapshot.id, iconEmoji: snapshot.iconEmoji)

        if fireDate > .now {
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            components.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: ReminderNotificationIDs.requestID(for: snapshot.id),
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            return
        }

        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let identifier = ReminderNotificationIDs.requestID(for: snapshot.id)
        if delivered.contains(where: { $0.request.identifier == identifier }) {
            return
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelPending(id: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ReminderNotificationIDs.requestID(for: id)]
        )
    }

    static func cancelAll(id: UUID) async {
        let identifiers = [ReminderNotificationIDs.requestID(for: id)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func makeContent(title: String, reminderID: UUID, iconEmoji: String? = nil) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if let iconEmoji, !iconEmoji.isEmpty {
            content.title = "\(iconEmoji) \(title)"
        } else {
            content.title = title
        }
        content.body = "DONE YET?"
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["reminderID": reminderID.uuidString]

        if let iconURL = Bundle.main.url(forResource: "AppIconBlack", withExtension: "png")
            ?? Bundle.main.url(forResource: "AppIconSage", withExtension: "png") {
            if let attachment = try? UNNotificationAttachment(identifier: "appIcon", url: iconURL, options: nil) {
                content.attachments = [attachment]
            }
        }

        return content
    }
}
