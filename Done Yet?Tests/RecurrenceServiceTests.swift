import Foundation
import Testing

@testable import Done_Yet_

struct RecurrenceServiceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeReminder(
        repeatType: RepeatType,
        hour: Int? = 22,
        minute: Int? = 0,
        repeatInterval: Int? = nil,
        weekdays: [Int]? = nil,
        createdAt: Date
    ) -> Reminder {
        let reminder = Reminder(
            title: "Test",
            repeatType: repeatType,
            repeatInterval: repeatInterval,
            weekdays: weekdays,
            reminderHour: hour,
            reminderMinute: minute
        )
        reminder.createdAt = createdAt
        return reminder
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    @Test func dailyFirstOccurrenceBeforeScheduledTime() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .everyDay, createdAt: date(2026, 8, 17, hour: 9))

        let now = date(2026, 8, 17, hour: 21)
        let first = service.firstOccurrence(for: reminder, from: now)

        #expect(first == date(2026, 8, 17, hour: 22))
    }

    @Test func dailyFirstOccurrenceAfterScheduledTime() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .everyDay, createdAt: date(2026, 8, 17, hour: 9))

        let now = date(2026, 8, 17, hour: 22, minute: 30)
        let first = service.firstOccurrence(for: reminder, from: now)

        #expect(first == date(2026, 8, 18, hour: 22))
    }

    @Test func dailyNextOccurrenceAfterCompletion() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .everyDay, createdAt: date(2026, 8, 17, hour: 9))

        let completion = date(2026, 8, 17, hour: 22, minute: 4)
        let next = service.nextOccurrence(for: reminder, after: completion)

        #expect(next == date(2026, 8, 18, hour: 22))
    }

    @Test func weeklyNextOccurrence() {
        let service = RecurrenceService(calendar: calendar)
        // August 17, 2026 is a Monday
        let reminder = makeReminder(repeatType: .everyWeek, createdAt: date(2026, 8, 17, hour: 9))

        let completion = date(2026, 8, 17, hour: 22, minute: 5)
        let next = service.nextOccurrence(for: reminder, after: completion)

        #expect(next == date(2026, 8, 24, hour: 22))
    }

    @Test func customWeekdayNextOccurrence() {
        let service = RecurrenceService(calendar: calendar)
        // Wednesday = 4 in Calendar weekday (Sunday=1)
        let reminder = makeReminder(
            repeatType: .custom,
            weekdays: [4],
            createdAt: date(2026, 8, 17, hour: 9)
        )

        let completion = date(2026, 8, 17, hour: 10) // Monday
        let next = service.nextOccurrence(for: reminder, after: completion)

        #expect(next == date(2026, 8, 19, hour: 22))
    }

    @Test func customIntervalNextOccurrence() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(
            repeatType: .custom,
            repeatInterval: 3,
            createdAt: date(2026, 8, 17, hour: 9)
        )

        let completion = date(2026, 8, 17, hour: 22, minute: 4)
        let next = service.nextOccurrence(for: reminder, after: completion)

        #expect(next == date(2026, 8, 20, hour: 22))
    }

    @Test func pendingAfterCompletionUntilNextOccurrence() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .everyDay, createdAt: date(2026, 8, 17, hour: 9))
        reminder.lastCompletedAt = date(2026, 8, 17, hour: 22, minute: 4)
        reminder.nextOccurrence = date(2026, 8, 18, hour: 22)

        #expect(service.isPending(reminder: reminder, at: date(2026, 8, 17, hour: 23)) == false)
        #expect(service.isPending(reminder: reminder, at: date(2026, 8, 18, hour: 22)) == true)
    }

    @Test func oneTimeReminderPendingUntilCompleted() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .never, createdAt: date(2026, 8, 17, hour: 9))

        #expect(service.isPending(reminder: reminder) == true)

        reminder.lastCompletedAt = date(2026, 8, 17, hour: 10)
        #expect(service.isPending(reminder: reminder) == false)
    }

    @Test func yearlyUsesScheduledMonthAndDay() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .everyYear, hour: 14, minute: 0, createdAt: date(2026, 8, 17, hour: 9))
        reminder.scheduledDate = date(2026, 12, 25)

        let first = service.firstOccurrence(for: reminder, from: date(2026, 8, 22, hour: 9))
        #expect(first == date(2026, 12, 25, hour: 14))

        let afterThisYear = service.nextOccurrence(for: reminder, after: date(2026, 12, 25, hour: 14, minute: 1))
        #expect(afterThisYear == date(2027, 12, 25, hour: 14))
    }

    @Test func yearlyFirstOccurrenceRollsToNextYearAfterTheDate() {
        let service = RecurrenceService(calendar: calendar)
        let reminder = makeReminder(repeatType: .everyYear, hour: 9, minute: 0, createdAt: date(2026, 8, 17, hour: 9))
        reminder.scheduledDate = date(2026, 8, 1)

        let first = service.firstOccurrence(for: reminder, from: date(2026, 8, 22, hour: 9))
        #expect(first == date(2027, 8, 1, hour: 9))
    }
}
