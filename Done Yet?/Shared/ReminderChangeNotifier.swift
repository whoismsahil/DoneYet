import Foundation

enum ReminderChangeNotifier {
    static let darwinName = CFNotificationName("DoneYet.reminderDidChange" as CFString)
    static let localName = Notification.Name("DoneYet.reminderDidChange")

    private static var isObserving = false

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            darwinName,
            nil,
            nil,
            true
        )
        NotificationCenter.default.post(name: localName, object: nil)
    }

    static func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: ReminderChangeNotifier.localName, object: nil)
                }
            },
            darwinName.rawValue,
            nil,
            .deliverImmediately
        )
    }
}
