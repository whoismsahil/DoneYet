import Foundation
import UserNotifications

@Observable
@MainActor
final class NotificationService: ReminderNotificationScheduling {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        ReminderNotificationCenterDelegate.shared.activate()
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func schedule(for reminder: Reminder) async {
        let snapshot = ReminderNotificationSnapshot(reminder)
        await ReminderNotificationScheduler.schedule(snapshot)
        await refreshAuthorizationStatus()
    }

    func cancel(for reminder: Reminder) async {
        await ReminderNotificationScheduler.cancelAll(id: reminder.id)
    }
}

final class ReminderNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderNotificationCenterDelegate()

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {}
}
