import Foundation

enum WidgetReminderStatus: String, Codable {
    case pending
    case completed
}

struct WidgetReminder: Codable, Identifiable {
    let id: UUID
    let title: String
    let pickerLabel: String
    let buttonText: String
    let status: WidgetReminderStatus
    let completedDisplayText: String?
    let nextOccurrence: Date?
    let repeatType: RepeatType
    let hasScheduledDate: Bool
    let showsUpcomingSchedule: Bool
    let iconEmoji: String?
    let showsIconOnWidget: Bool
    let accentHex: UInt32?
    let textHex: UInt32?

    init(
        id: UUID,
        title: String,
        pickerLabel: String,
        buttonText: String,
        status: WidgetReminderStatus,
        completedDisplayText: String? = nil,
        nextOccurrence: Date? = nil,
        repeatType: RepeatType = .never,
        hasScheduledDate: Bool = false,
        showsUpcomingSchedule: Bool = false,
        iconEmoji: String? = nil,
        showsIconOnWidget: Bool = true,
        accentHex: UInt32? = nil,
        textHex: UInt32? = nil
    ) {
        self.id = id
        self.title = title
        self.pickerLabel = pickerLabel
        self.buttonText = buttonText
        self.status = status
        self.completedDisplayText = completedDisplayText
        self.nextOccurrence = nextOccurrence
        self.repeatType = repeatType
        self.hasScheduledDate = hasScheduledDate
        self.showsUpcomingSchedule = showsUpcomingSchedule
        self.iconEmoji = iconEmoji
        self.showsIconOnWidget = showsIconOnWidget
        self.accentHex = accentHex
        self.textHex = textHex
    }

    var appearsInWidgetPicker: Bool {
        if repeatType.isRepeating { return true }
        return status == .pending || showsUpcomingSchedule
    }

    func resolved(at date: Date) -> WidgetReminder {
        if !repeatType.isRepeating {
            if status == .completed {
                return replacing(status: .completed, showsUpcomingSchedule: false)
            }
            let isUpcoming = nextOccurrence.map { $0 > date } ?? false
            return replacing(status: .pending, showsUpcomingSchedule: isUpcoming)
        }

        if status == .completed, let nextOccurrence, date >= nextOccurrence {
            return replacing(status: .pending, showsUpcomingSchedule: false)
        }

        return self
    }

    private func replacing(
        status: WidgetReminderStatus,
        showsUpcomingSchedule: Bool
    ) -> WidgetReminder {
        WidgetReminder(
            id: id,
            title: title,
            pickerLabel: pickerLabel,
            buttonText: buttonText,
            status: status,
            completedDisplayText: completedDisplayText,
            nextOccurrence: nextOccurrence,
            repeatType: repeatType,
            hasScheduledDate: hasScheduledDate,
            showsUpcomingSchedule: showsUpcomingSchedule,
            iconEmoji: iconEmoji,
            showsIconOnWidget: showsIconOnWidget,
            accentHex: accentHex,
            textHex: textHex
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        pickerLabel = try container.decode(String.self, forKey: .pickerLabel)
        buttonText = try container.decode(String.self, forKey: .buttonText)
        status = try container.decode(WidgetReminderStatus.self, forKey: .status)
        completedDisplayText = try container.decodeIfPresent(String.self, forKey: .completedDisplayText)
        nextOccurrence = try container.decodeIfPresent(Date.self, forKey: .nextOccurrence)
        repeatType = try container.decodeIfPresent(RepeatType.self, forKey: .repeatType) ?? .never
        hasScheduledDate = try container.decodeIfPresent(Bool.self, forKey: .hasScheduledDate) ?? false
        showsUpcomingSchedule = try container.decodeIfPresent(Bool.self, forKey: .showsUpcomingSchedule) ?? false
        iconEmoji = try container.decodeIfPresent(String.self, forKey: .iconEmoji)
        showsIconOnWidget = try container.decodeIfPresent(Bool.self, forKey: .showsIconOnWidget) ?? true
        accentHex = try container.decodeIfPresent(UInt32.self, forKey: .accentHex)
        textHex = try container.decodeIfPresent(UInt32.self, forKey: .textHex)
    }
}

struct WidgetNextOccurrenceCopy {
    let dayLabel: String
    let timeDigits: String
    let meridiem: String

    static func make(
        repeatType: RepeatType,
        nextOccurrence: Date,
        hasScheduledDate: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetNextOccurrenceCopy? {
        if repeatType.isRepeating {
            return WidgetNextOccurrenceCopy(
                dayLabel: dayLabel(for: repeatType, nextOccurrence: nextOccurrence, now: now, calendar: calendar),
                timeDigits: timeDigits(from: nextOccurrence, calendar: calendar),
                meridiem: meridiem(from: nextOccurrence, calendar: calendar)
            )
        }

        guard nextOccurrence > now else { return nil }

        return WidgetNextOccurrenceCopy(
            dayLabel: neverUpcomingLabel(for: nextOccurrence, hasScheduledDate: hasScheduledDate, calendar: calendar),
            timeDigits: timeDigits(from: nextOccurrence, calendar: calendar),
            meridiem: meridiem(from: nextOccurrence, calendar: calendar)
        )
    }

    private static func dayLabel(
        for repeatType: RepeatType,
        nextOccurrence: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        switch repeatType {
        case .never:
            return relativeDayLabel(for: nextOccurrence, now: now, calendar: calendar)
        case .everyDay:
            return relativeDayLabel(for: nextOccurrence, now: now, calendar: calendar)
        case .everyWeek:
            return weekDayLabel(for: nextOccurrence, calendar: calendar)
        case .everyMonth:
            return monthDayLabel(for: nextOccurrence, calendar: calendar)
        case .everyYear:
            return yearDayLabel(for: nextOccurrence, calendar: calendar)
        case .custom:
            return compactDateLabel(for: nextOccurrence, calendar: calendar)
        }
    }

    private static func neverUpcomingLabel(for date: Date, hasScheduledDate: Bool, calendar: Calendar) -> String {
        guard hasScheduledDate else { return "Upcoming" }
        return "\(formatted(date, format: "EEE", calendar: calendar)) \(ordinalDay(for: date, calendar: calendar)) \(formatted(date, format: "MMM", calendar: calendar))"
    }

    private static func relativeDayLabel(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }

        return compactDateLabel(for: date, calendar: calendar)
    }

    private static func compactDateLabel(for date: Date, calendar: Calendar) -> String {
        "\(formatted(date, format: "EEE", calendar: calendar)), \(ordinalDay(for: date, calendar: calendar)) \(formatted(date, format: "MMM", calendar: calendar))"
    }

    private static func weekDayLabel(for date: Date, calendar: Calendar) -> String {
        "\(ordinalDay(for: date, calendar: calendar)), \(formatted(date, format: "EEEE", calendar: calendar))"
    }

    private static func monthDayLabel(for date: Date, calendar: Calendar) -> String {
        "\(ordinalDay(for: date, calendar: calendar)) \(formatted(date, format: "MMM", calendar: calendar))"
    }

    private static func yearDayLabel(for date: Date, calendar: Calendar) -> String {
        "\(monthDayLabel(for: date, calendar: calendar)). \(formatted(date, format: "yyyy", calendar: calendar))"
    }

    private static func ordinalDay(for date: Date, calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }

    private static func formatted(_ date: Date, format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private static func timeDigits(from date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let hour12 = hour % 12
        let displayHour = hour12 == 0 ? 12 : hour12
        return String(format: "%02d:%02d", displayHour, minute)
    }

    private static func meridiem(from date: Date, calendar: Calendar) -> String {
        calendar.component(.hour, from: date) < 12 ? "AM" : "PM"
    }
}

struct WidgetReminderSnapshot: Codable {
    let reminders: [WidgetReminder]
    let updatedAt: Date
}
