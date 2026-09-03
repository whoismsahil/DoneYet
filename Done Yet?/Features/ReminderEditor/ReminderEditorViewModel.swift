import Foundation
import SwiftUI

@Observable
@MainActor
final class ReminderEditorViewModel {
    static let titleLimit = 40
    var title: String = ""
    var repeatType: RepeatType = .never
    var repeatInterval: Int = 2
    var selectedWeekdays: Set<Int> = []
    var hasScheduledTime: Bool = false
    var scheduledTime: Date = ReminderEditorViewModel.defaultScheduledTime
    var hasScheduledDate: Bool = false
    var scheduledDate: Date = Calendar.current.startOfDay(for: .now)
    var completionButtonText: String = "DONE YET?"
    var iconEmoji: String = ""
    var showsIconOnWidget = true
    var iconIsSuggested = false

    private var userLockedIcon = false
    private let mode: ReminderEditorMode

    init(mode: ReminderEditorMode) {
        self.mode = mode

        if case .edit(let reminder) = mode {
            title = String(reminder.title.prefix(Self.titleLimit))
            repeatType = reminder.repeatType
            repeatInterval = max(reminder.repeatInterval ?? 2, 2)
            if let weekdays = reminder.weekdays {
                selectedWeekdays = Set(weekdays)
            }
            if let hour = reminder.reminderHour, let minute = reminder.reminderMinute {
                hasScheduledTime = true
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                scheduledTime = Calendar.current.date(from: components) ?? Self.defaultScheduledTime
            }
            if let date = reminder.scheduledDate {
                hasScheduledDate = true
                scheduledDate = Calendar.current.startOfDay(for: date)
            }
            completionButtonText = reminder.completionButtonText
            iconEmoji = ReminderEmojiStyle.normalized(reminder.iconEmoji) ?? ""
            showsIconOnWidget = reminder.showsIconOnWidget
            userLockedIcon = !iconEmoji.isEmpty
        }
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    var hasEnteredTitle: Bool {
        !trimmedTitle.isEmpty
    }

    var showsDatePicker: Bool {
        true
    }

    var previewTitle: String {
        trimmedTitle.isEmpty ? "YOUR REMINDER" : trimmedTitle.uppercased()
    }

    var previewButtonText: String {
        completionButtonText.isEmpty ? "DONE YET?" : completionButtonText.uppercased()
    }

    func save(using service: ReminderService) throws {
        let hourMinute = hasScheduledTime ? Self.hourMinute(from: scheduledTime) : nil
        let dateValue = resolvedScheduledDate

        switch mode {
        case .add:
            _ = try service.create(
                title: trimmedTitle,
                completionButtonText: normalizedButtonText,
                repeatType: repeatType,
                repeatInterval: repeatIntervalValue,
                weekdays: weekdaysValue,
                reminderHour: hourMinute?.hour,
                reminderMinute: hourMinute?.minute,
                scheduledDate: dateValue,
                iconEmoji: iconEmoji,
                showsIconOnWidget: showsIconOnWidget
            )

        case .edit(let reminder):
            reminder.title = trimmedTitle
            reminder.completionButtonText = normalizedButtonText
            reminder.repeatType = repeatType
            reminder.repeatInterval = repeatIntervalValue
            reminder.weekdays = weekdaysValue
            reminder.reminderHour = hourMinute?.hour
            reminder.reminderMinute = hourMinute?.minute
            reminder.scheduledDate = dateValue
            reminder.iconEmoji = ReminderEmojiStyle.normalized(iconEmoji) ?? ""
            reminder.showsIconOnWidget = showsIconOnWidget
            try service.save(reminder)
        }
    }

    func setIconEmoji(_ raw: String) {
        iconEmoji = ReminderEmojiStyle.normalized(raw) ?? ""
        iconIsSuggested = false
        userLockedIcon = true
    }

    func updateSuggestedIcon(enabled: Bool) {
        guard enabled, !userLockedIcon else { return }
        if let suggested = ReminderEmojiSuggestion.emoji(for: title) {
            iconEmoji = suggested
            iconIsSuggested = true
        } else if iconIsSuggested {
            iconEmoji = ""
            iconIsSuggested = false
        }
    }

    func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private var resolvedScheduledDate: Date? {
        guard hasScheduledDate else { return nil }
        return Calendar.current.startOfDay(for: scheduledDate)
    }

    private var trimmedTitle: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.titleLimit))
    }

    private var normalizedButtonText: String {
        let trimmed = completionButtonText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "DONE YET?" : trimmed.uppercased()
    }

    private var repeatIntervalValue: Int? {
        guard repeatType == .custom else { return nil }
        return repeatInterval
    }

    private var weekdaysValue: [Int]? {
        guard repeatType == .custom, !selectedWeekdays.isEmpty else { return nil }
        return selectedWeekdays.sorted()
    }

    private static var defaultScheduledTime: Date {
        var components = DateComponents()
        components.hour = 21
        components.minute = 0
        return Calendar.current.date(from: components) ?? .now
    }

    private static func hourMinute(from date: Date) -> (hour: Int, minute: Int) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
}
