import Foundation
import Testing
@testable import Done_Yet_

struct WidgetNextOccurrenceCopyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func dailyUsesTomorrow() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2026, 8, 20, hour: 22)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .everyDay,
            nextOccurrence: next,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "Tomorrow")
        #expect(copy?.timeDigits == "10:00")
        #expect(copy?.meridiem == "PM")
    }

    @Test func weeklyUsesWeekdayName() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2026, 8, 26, hour: 9, minute: 30)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .everyWeek,
            nextOccurrence: next,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "26th, Wednesday")
        #expect(copy?.timeDigits == "09:30")
        #expect(copy?.meridiem == "AM")
    }

    @Test func monthlyUsesMonthName() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2026, 12, 19, hour: 8)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .everyMonth,
            nextOccurrence: next,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "19th Dec")
        #expect(copy?.timeDigits == "08:00")
        #expect(copy?.meridiem == "AM")
    }

    @Test func yearlyUsesYear() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2027, 8, 19, hour: 9)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .everyYear,
            nextOccurrence: next,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "19th Aug. 2027")
        #expect(copy?.meridiem == "AM")
    }

    @Test func neverUpcomingWithoutDateUsesUpcoming() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2026, 8, 19, hour: 22)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .never,
            nextOccurrence: next,
            hasScheduledDate: false,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "Upcoming")
        #expect(copy?.timeDigits == "10:00")
        #expect(copy?.meridiem == "PM")
    }

    @Test func neverUpcomingWithDateUsesWeekdayDayMonth() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2026, 8, 28, hour: 9)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .never,
            nextOccurrence: next,
            hasScheduledDate: true,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "Fri 28th Aug")
    }

    @Test func neverRepeatInThePastReturnsNil() {
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .never,
            nextOccurrence: date(2026, 8, 19, hour: 8),
            now: date(2026, 8, 19, hour: 9),
            calendar: calendar
        )

        #expect(copy == nil)
    }

    @Test func customUsesCompactDate() {
        let now = date(2026, 8, 19, hour: 9)
        let next = date(2026, 8, 24, hour: 9)
        let copy = WidgetNextOccurrenceCopy.make(
            repeatType: .custom,
            nextOccurrence: next,
            now: now,
            calendar: calendar
        )

        #expect(copy?.dayLabel == "Mon, 24th Aug")
    }

    @Test func upcomingNeverShowsDoneYetAtScheduledTime() {
        let next = date(2026, 8, 19, hour: 14)
        let reminder = WidgetReminder(
            id: UUID(),
            title: "LOCK UP",
            pickerLabel: "Lock up",
            buttonText: "DONE YET?",
            status: .pending,
            nextOccurrence: next,
            repeatType: .never,
            hasScheduledDate: false,
            showsUpcomingSchedule: true
        )

        let before = reminder.resolved(at: date(2026, 8, 19, hour: 13, minute: 59))
        #expect(before.showsUpcomingSchedule)
        #expect(before.status == .pending)

        let atTime = reminder.resolved(at: next)
        #expect(!atTime.showsUpcomingSchedule)
        #expect(atTime.status == .pending)
    }

    @Test func repeatingCompletedFlipsPendingAtNextOccurrence() {
        let next = date(2026, 8, 19, hour: 14)
        let reminder = WidgetReminder(
            id: UUID(),
            title: "LOCK UP",
            pickerLabel: "Lock up",
            buttonText: "DONE YET?",
            status: .completed,
            nextOccurrence: next,
            repeatType: .everyDay
        )

        #expect(reminder.resolved(at: date(2026, 8, 19, hour: 13)).status == .completed)
        #expect(reminder.resolved(at: next).status == .pending)
    }
}
