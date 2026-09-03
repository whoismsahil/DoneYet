import Foundation

enum ReminderOccurrenceStatus {
    case pending
    case completed
}

struct RecurrenceService {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func occurrenceStatus(for reminder: Reminder, at date: Date = .now) -> ReminderOccurrenceStatus {
        isPending(reminder: reminder, at: date) ? .pending : .completed
    }

    func isPending(reminder: Reminder, at date: Date = .now) -> Bool {
        switch reminder.repeatType {
        case .never:
            return reminder.lastCompletedAt == nil
        case .everyDay, .everyWeek, .everyMonth, .everyYear, .custom:
            guard reminder.lastCompletedAt != nil else { return true }
            guard let nextOccurrence = reminder.nextOccurrence else { return true }
            return date >= nextOccurrence
        }
    }

    func firstOccurrence(for reminder: Reminder, from date: Date = .now) -> Date? {
        guard reminder.repeatType != .never else { return nil }

        if reminder.repeatType == .everyYear {
            return nextYearlyOccurrence(for: reminder, onOrAfter: date)
        }

        if let scheduled = scheduledDate(onOrAfter: date, for: reminder) {
            return scheduled
        }

        return startOfNextDay(from: date)
    }

    func nextOccurrence(for reminder: Reminder, after date: Date) -> Date? {
        guard reminder.repeatType != .never else { return nil }

        switch reminder.repeatType {
        case .never:
            return nil
        case .everyDay:
            return nextDailyOccurrence(for: reminder, after: date)
        case .everyWeek:
            return nextWeeklyOccurrence(for: reminder, after: date)
        case .everyMonth:
            return nextCalendarOccurrence(for: reminder, after: date, component: .month)
        case .everyYear:
            return nextYearlyOccurrence(for: reminder, after: date)
        case .custom:
            if let interval = reminder.repeatInterval, interval > 1 {
                return nextIntervalOccurrence(interval: interval, for: reminder, after: date)
            }
            if let weekdays = reminder.weekdays, !weekdays.isEmpty {
                return nextWeekdayOccurrence(weekdays: weekdays, for: reminder, after: date)
            }
            return nextDailyOccurrence(for: reminder, after: date)
        }
    }

    private func nextDailyOccurrence(for reminder: Reminder, after date: Date) -> Date? {
        let searchStart = calendar.date(byAdding: .second, value: 1, to: date) ?? date

        if let scheduled = scheduledDate(onOrAfter: searchStart, for: reminder) {
            return scheduled
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay(for: searchStart)) ?? searchStart
        return scheduledDate(onOrAfter: tomorrow, for: reminder) ?? startOfDay(for: tomorrow)
    }

    private func nextWeeklyOccurrence(for reminder: Reminder, after date: Date) -> Date? {
        let searchStart = calendar.date(byAdding: .second, value: 1, to: date) ?? date
        let anchorWeekday = reminderWeekday(for: reminder, fallbackDate: reminder.createdAt)

        for dayOffset in 0..<14 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay(for: searchStart)) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: candidateDay)
            guard weekday == anchorWeekday else { continue }

            if let scheduled = scheduledDate(on: candidateDay, for: reminder), scheduled > date {
                return scheduled
            }

            if !reminder.hasScheduledTime, candidateDay > searchStart {
                return candidateDay
            }
        }

        return nil
    }

    private func nextCalendarOccurrence(for reminder: Reminder, after date: Date, component: Calendar.Component) -> Date? {
        let anchor = reminder.lastCompletedAt ?? reminder.createdAt
        guard let nextDay = calendar.date(byAdding: component, value: 1, to: startOfDay(for: anchor)) else {
            return nil
        }

        var candidate = nextDay
        while candidate <= date {
            guard let stepped = calendar.date(byAdding: component, value: 1, to: candidate) else {
                return nil
            }
            candidate = stepped
        }

        if let scheduled = scheduledDate(on: candidate, for: reminder), scheduled > date {
            return scheduled
        }

        return scheduledDate(on: candidate, for: reminder) ?? candidate
    }

    private func nextIntervalOccurrence(interval: Int, for reminder: Reminder, after date: Date) -> Date? {
        let anchor = reminder.lastCompletedAt ?? reminder.createdAt
        let anchorDay = startOfDay(for: anchor)
        let afterDay = startOfDay(for: date)

        var candidateDay = anchorDay
        while candidateDay <= afterDay {
            guard let next = calendar.date(byAdding: .day, value: interval, to: candidateDay) else { break }
            candidateDay = next
        }

        if let scheduled = scheduledDate(on: candidateDay, for: reminder), scheduled > date {
            return scheduled
        }

        if !reminder.hasScheduledTime, candidateDay > date {
            return candidateDay
        }

        guard let nextDay = calendar.date(byAdding: .day, value: interval, to: candidateDay) else {
            return nil
        }
        return scheduledDate(on: nextDay, for: reminder) ?? nextDay
    }

    private func nextWeekdayOccurrence(weekdays: [Int], for reminder: Reminder, after date: Date) -> Date? {
        let searchStart = calendar.date(byAdding: .second, value: 1, to: date) ?? date
        let sortedWeekdays = weekdays.sorted()

        for dayOffset in 0..<14 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay(for: searchStart)) else {
                continue
            }

            let weekdayIndex = calendar.component(.weekday, from: candidateDay)
            guard sortedWeekdays.contains(weekdayIndex) else { continue }

            if let scheduled = scheduledDate(on: candidateDay, for: reminder), scheduled > date {
                return scheduled
            }

            if !reminder.hasScheduledTime, candidateDay > searchStart {
                return candidateDay
            }
        }

        return nil
    }

    private func reminderWeekday(for reminder: Reminder, fallbackDate: Date) -> Int {
        if let weekdays = reminder.weekdays, let first = weekdays.sorted().first {
            return first
        }
        return calendar.component(.weekday, from: fallbackDate)
    }

    private func scheduledDate(onOrAfter date: Date, for reminder: Reminder) -> Date? {
        let dayStart = startOfDay(for: date)

        if let onDay = scheduledDate(on: dayStart, for: reminder), onDay >= date {
            return onDay
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        return scheduledDate(on: tomorrow, for: reminder)
    }

    private func scheduledDate(on day: Date, for reminder: Reminder) -> Date? {
        let dayStart = startOfDay(for: day)

        guard reminder.hasScheduledTime,
              let hour = reminder.reminderHour,
              let minute = reminder.reminderMinute else {
            return dayStart
        }

        var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }

    private func nextYearlyOccurrence(for reminder: Reminder, after date: Date) -> Date? {
        let searchStart = calendar.date(byAdding: .second, value: 1, to: date) ?? date
        return nextYearlyOccurrence(for: reminder, onOrAfter: searchStart)
    }

    private func nextYearlyOccurrence(for reminder: Reminder, onOrAfter date: Date) -> Date? {
        let anchor = reminder.scheduledDate ?? reminder.createdAt
        let month = calendar.component(.month, from: anchor)
        let day = calendar.component(.day, from: anchor)
        let startYear = calendar.component(.year, from: date)

        for year in startYear...(startYear + 8) {
            guard let candidate = yearlyDate(
                year: year,
                month: month,
                day: day,
                hour: reminder.reminderHour ?? 0,
                minute: reminder.reminderMinute ?? 0
            ) else {
                continue
            }
            if candidate >= date {
                return candidate
            }
        }

        return nil
    }

    private func yearlyDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0

        if let date = calendar.date(from: components) {
            return date
        }

        components.day = 28
        return calendar.date(from: components)
    }

    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func startOfNextDay(from date: Date) -> Date {
        let dayStart = startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }
}
