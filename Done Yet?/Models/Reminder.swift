import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var title: String
    var completionButtonText: String

    var isRepeating: Bool
    var repeatType: RepeatType

    var repeatInterval: Int?
    var weekdays: [Int]?

    var reminderHour: Int?
    var reminderMinute: Int?
    var scheduledDate: Date?

    var createdAt: Date
    var updatedAt: Date

    var isActive: Bool

    var lastCompletedAt: Date?
    var nextOccurrence: Date?
    var repeatTypeRaw: String = ""
    var iconEmoji: String = ""
    var showsIconOnWidget: Bool = true

    init(
        id: UUID = UUID(),
        title: String,
        completionButtonText: String = "DONE YET?",
        isRepeating: Bool = false,
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
        self.title = title
        self.completionButtonText = completionButtonText
        self.isRepeating = isRepeating
        self.repeatType = repeatType
        self.repeatInterval = repeatInterval
        self.weekdays = weekdays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.scheduledDate = scheduledDate
        self.iconEmoji = ReminderEmojiStyle.normalized(iconEmoji) ?? ""
        self.showsIconOnWidget = showsIconOnWidget
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
        self.repeatTypeRaw = repeatType.rawValue
    }
}

extension Reminder {
    var repeats: Bool {
        isRepeating || repeatType.isRepeating || RepeatType(rawValue: repeatTypeRaw)?.isRepeating == true
    }

    var resolvedRepeatType: RepeatType {
        if repeatType.isRepeating { return repeatType }
        if let stored = RepeatType(rawValue: repeatTypeRaw), stored.isRepeating { return stored }
        return .never
    }

    func syncRepeatFields() {
        if repeatType == .never, let stored = RepeatType(rawValue: repeatTypeRaw), stored.isRepeating {
            repeatType = stored
        }
        isRepeating = repeatType.isRepeating
        repeatTypeRaw = repeatType.rawValue
    }
    var hasScheduledDate: Bool {
        scheduledDate != nil
    }

    func scheduledFireDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let hour = reminderHour, let minute = reminderMinute else { return nil }

        var components: DateComponents
        if let scheduledDate {
            components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        } else {
            components = calendar.dateComponents([.year, .month, .day], from: now)
        }
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    var isUpcomingNeverSchedule: Bool {
        guard !repeats, hasScheduledTime, lastCompletedAt == nil else { return false }
        guard let fireDate = scheduledFireDate() else { return false }
        return fireDate > .now
    }

    var hasScheduledTime: Bool {
        reminderHour != nil && reminderMinute != nil
    }

    var scheduleSummary: String? {
        guard hasScheduledTime,
              let hour = reminderHour,
              let minute = reminderMinute else { return nil }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return nil }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var repeatSummary: String {
        switch repeatType {
        case .never:
            return "Never"
        case .everyDay:
            return "Daily"
        case .everyWeek:
            return "Weekly"
        case .everyMonth:
            return "Monthly"
        case .everyYear:
            return "Yearly"
        case .custom:
            if let interval = repeatInterval, interval > 1 {
                return "Every \(interval) days"
            }
            if let weekdays, !weekdays.isEmpty {
                let symbols = Calendar.current.shortWeekdaySymbols
                let names = weekdays.sorted().compactMap { (day: Int) -> String? in
                    guard day >= 1, day <= 7 else { return nil }
                    return symbols[day - 1]
                }
                if names.isEmpty {
                    return "Custom"
                }
                return names.joined(separator: ", ")
            }
            return "Custom"
        }
    }

    var metadataLine: String {
        var parts = [repeatSummary]
        if hasScheduledDate, let date = scheduledDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            parts.append(formatter.string(from: date))
        }
        if let time = scheduleSummary {
            parts.append(time)
        }
        return parts.joined(separator: " · ")
    }

    var displayTitle: String {
        title.uppercased()
    }

    var completedDisplayText: String {
        "\(completionButtonText) ✓"
    }

    func isPending(at date: Date = .now, recurrenceService: RecurrenceService = RecurrenceService()) -> Bool {
        recurrenceService.isPending(reminder: self, at: date)
    }

    func occurrenceStatus(at date: Date = .now, recurrenceService: RecurrenceService = RecurrenceService()) -> ReminderOccurrenceStatus {
        recurrenceService.occurrenceStatus(for: self, at: date)
    }

    func nextOccurrenceSummary(relativeTo date: Date = .now, calendar: Calendar = .current) -> String? {
        guard let nextOccurrence else { return nil }

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let dayStart = calendar.startOfDay(for: date)
        let nextDayStart = calendar.startOfDay(for: nextOccurrence)

        let dayLabel: String
        if nextDayStart == dayStart {
            dayLabel = "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart),
                  nextDayStart == calendar.startOfDay(for: tomorrow) {
            dayLabel = "Tomorrow"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            dayLabel = formatter.string(from: nextOccurrence)
            formatter.dateStyle = .none
        }

        if hasScheduledTime {
            return "\(dayLabel) · \(formatter.string(from: nextOccurrence))"
        }

        return dayLabel
    }

    func repeatingCompletionToast(relativeTo date: Date = .now, calendar: Calendar = .current) -> String {
        let type = resolvedRepeatType

        guard let nextOccurrence else {
            switch type {
            case .everyDay:
                return "Done. Repeats tomorrow."
            case .everyWeek:
                return "Done. Repeats next week."
            case .everyMonth:
                return "Done. Repeats next month."
            case .everyYear:
                return "Done. Repeats next year."
            case .custom:
                if let interval = repeatInterval, interval > 1 {
                    return "Done. Repeats in \(interval) days."
                }
                return "Done. Repeats later."
            case .never:
                return "Done."
            }
        }

        return "Done. Next: \(nextOccurrencePhrase(for: nextOccurrence, relativeTo: date, calendar: calendar))."
    }

    private func nextOccurrencePhrase(for nextOccurrence: Date, relativeTo date: Date, calendar: Calendar) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dayStart = calendar.startOfDay(for: date)
        let nextDayStart = calendar.startOfDay(for: nextOccurrence)
        let days = calendar.dateComponents([.day], from: dayStart, to: nextDayStart).day ?? 0

        let dayPhrase: String
        if days == 0 {
            dayPhrase = "today"
        } else if days == 1 {
            dayPhrase = "tomorrow"
        } else if days < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            dayPhrase = weekdayFormatter.string(from: nextOccurrence)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            dayPhrase = dateFormatter.string(from: nextOccurrence)
        }

        if hasScheduledTime {
            return "\(dayPhrase) at \(timeFormatter.string(from: nextOccurrence))"
        }

        return dayPhrase
    }
}
