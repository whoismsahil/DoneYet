import Foundation
import SwiftData

@Model
final class CompletionRecord {
    var id: UUID
    var reminderID: UUID
    var completedAt: Date
    var title: String = ""
    var reminderTitle: String = ""
    var capturedName: String = ""
    var completionText: String
    var repeatTypeRaw: String = RepeatType.never.rawValue
    var repeatInterval: Int?
    var weekdays: [Int]?
    var reminderHour: Int?
    var reminderMinute: Int?
    var scheduledDate: Date?
    var iconEmoji: String = ""
    var showsIconOnWidget: Bool = true

    init(
        id: UUID = UUID(),
        reminderID: UUID,
        completedAt: Date = Date(),
        title: String,
        completionText: String,
        repeatType: RepeatType = .never,
        repeatInterval: Int? = nil,
        weekdays: [Int]? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        scheduledDate: Date? = nil,
        iconEmoji: String = "",
        showsIconOnWidget: Bool = true
    ) {
        self.id = id
        self.reminderID = reminderID
        self.completedAt = completedAt
        self.title = title
        self.reminderTitle = title
        self.capturedName = title
        self.completionText = completionText
        self.repeatTypeRaw = repeatType.rawValue
        self.repeatInterval = repeatInterval
        self.weekdays = weekdays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.scheduledDate = scheduledDate
        self.iconEmoji = ReminderEmojiStyle.normalized(iconEmoji) ?? ""
        self.showsIconOnWidget = showsIconOnWidget
    }

    var repeatType: RepeatType {
        RepeatType(rawValue: repeatTypeRaw) ?? .never
    }

    var storedTitle: String {
        let names = [capturedName, reminderTitle, title]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare("Reminder") != .orderedSame }
        return names.first ?? ""
    }

    func applySnapshot(from reminder: Reminder) {
        let name = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            capturedName = name
            reminderTitle = name
            title = name
        }
        if !reminder.completionButtonText.isEmpty {
            completionText = reminder.completionButtonText
        }
        reminder.syncRepeatFields()
        repeatTypeRaw = reminder.repeatType.rawValue
        repeatInterval = reminder.repeatInterval
        weekdays = reminder.weekdays
        reminderHour = reminder.reminderHour
        reminderMinute = reminder.reminderMinute
        scheduledDate = reminder.scheduledDate
        iconEmoji = ReminderEmojiStyle.normalized(reminder.iconEmoji) ?? ""
        showsIconOnWidget = reminder.showsIconOnWidget
    }

    static func snapshot(from reminder: Reminder, completedAt: Date = Date()) -> CompletionRecord {
        reminder.syncRepeatFields()
        return CompletionRecord(
            reminderID: reminder.id,
            completedAt: completedAt,
            title: reminder.title,
            completionText: reminder.completionButtonText,
            repeatType: reminder.resolvedRepeatType,
            repeatInterval: reminder.repeatInterval,
            weekdays: reminder.weekdays,
            reminderHour: reminder.reminderHour,
            reminderMinute: reminder.reminderMinute,
            scheduledDate: reminder.scheduledDate,
            iconEmoji: reminder.iconEmoji,
            showsIconOnWidget: reminder.showsIconOnWidget
        )
    }
}
