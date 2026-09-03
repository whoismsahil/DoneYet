import Foundation
import WidgetKit

enum WidgetCompletion {
    @MainActor
    static func apply(reminderID: String) throws {
        let selection = reminderID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else {
            throw WidgetCompletionError.invalidReminderID
        }

        let store = SharedWidgetStore()
        var reminders = (try? store.load()) ?? []

        let uuid = UUID(uuidString: selection)
        let index = reminders.firstIndex { reminder in
            if let uuid { return reminder.id == uuid }
            return reminder.pickerLabel == selection || reminder.title == selection
        }

        guard let index else {
            throw WidgetCompletionError.reminderNotFound
        }

        let current = reminders[index]
        let nextOccurrence: Date?
        if current.repeatType.isRepeating {
            nextOccurrence = current.nextOccurrence
                ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)
        } else {
            nextOccurrence = nil
        }

        reminders[index] = WidgetReminder(
            id: current.id,
            title: current.title,
            pickerLabel: current.pickerLabel,
            buttonText: current.buttonText,
            status: .completed,
            completedDisplayText: "\(current.buttonText) ✓",
            nextOccurrence: nextOccurrence,
            repeatType: current.repeatType,
            hasScheduledDate: current.hasScheduledDate,
            showsUpcomingSchedule: false,
            iconEmoji: current.iconEmoji,
            showsIconOnWidget: current.showsIconOnWidget,
            accentHex: current.accentHex,
            textHex: current.textHex
        )

        try store.save(reminders: reminders)
        WidgetCelebrationStore.record()
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        // Don't notify the app yet. SwiftData may still be catching up. The intent posts after.
    }
}

enum WidgetCelebrationStore {
    static let storageKey = "widget_celebrate_at"
    static let duration: TimeInterval = 2.2

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.identifier)
    }

    static func record(at date: Date = .now) {
        defaults?.set(date, forKey: storageKey)
        defaults?.synchronize()
    }

    static var lastAt: Date? {
        defaults?.object(forKey: storageKey) as? Date
    }

    static func isCelebrating(at date: Date) -> Bool {
        guard let lastAt else { return false }
        let elapsed = date.timeIntervalSince(lastAt)
        return elapsed >= 0 && elapsed < duration
    }

    static func celebrationEnd(after now: Date) -> Date? {
        guard let lastAt else { return nil }
        let end = lastAt.addingTimeInterval(duration)
        return end > now ? end : nil
    }
}

enum WidgetCompletionError: Error {
    case invalidReminderID
    case reminderNotFound
}
