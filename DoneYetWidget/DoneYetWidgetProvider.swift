import WidgetKit

struct DoneYetWidgetEntry: TimelineEntry {
    let date: Date
    let reminderID: String
    let reminder: WidgetReminder?
    let configuration: SelectReminderIntent
    let theme: WidgetTheme
    let pet: WidgetPet
    let petMotion: WidgetPetMotion
    let isCelebrating: Bool
}

struct DoneYetWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = DoneYetWidgetEntry
    typealias Intent = SelectReminderIntent

    func placeholder(in context: Context) -> DoneYetWidgetEntry {
        galleryEntry()
    }

    func snapshot(for configuration: SelectReminderIntent, in context: Context) async -> DoneYetWidgetEntry {
        if context.isPreview {
            return galleryEntry()
        }
        return entry(for: configuration, date: .now)
    }

    func timeline(for configuration: SelectReminderIntent, in context: Context) async -> Timeline<DoneYetWidgetEntry> {
        let now = Date()
        let reminder = WidgetReminderLoader.reminder(for: configuration.configuredSelection)
        let dates = timelineDates(from: now, reminder: reminder)
        let entries = dates.map { entry(for: configuration, date: $0) }
        return Timeline(entries: entries, policy: .after(reloadPolicyDate(from: now, reminder: reminder, dates: dates)))
    }

    private func galleryEntry() -> DoneYetWidgetEntry {
        DoneYetWidgetEntry(
            date: .now,
            reminderID: "gallery-preview",
            reminder: WidgetReminder(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                title: "LOCKED MY DOOR?",
                pickerLabel: "Locked my Door?",
                buttonText: "DONE YET?",
                status: .pending,
                repeatType: .never
            ),
            configuration: SelectReminderIntent(reminderTitle: "Locked my Door?"),
            theme: .willow,
            pet: .cat,
            petMotion: .still,
            isCelebrating: false
        )
    }

    private func entry(for configuration: SelectReminderIntent, date: Date) -> DoneYetWidgetEntry {
        let selection = configuration.configuredSelection
        let reminder = WidgetReminderLoader.reminder(for: selection)?.resolved(at: date)
        let reminderID = reminder?.id.uuidString
            ?? WidgetReminderLoader.reminderID(forSelection: selection)
            ?? ""

        return DoneYetWidgetEntry(
            date: date,
            reminderID: reminderID,
            reminder: reminder,
            configuration: configuration,
            theme: WidgetThemeStore.current,
            pet: WidgetPetStore.current,
            petMotion: WidgetCelebrationStore.isCelebrating(at: date)
                ? .tap
                : WidgetPetMotion.resolved(at: date, tapStartedAt: WidgetPetStore.lastTapAt),
            isCelebrating: WidgetCelebrationStore.isCelebrating(at: date)
        )
    }

    private func timelineDates(from now: Date, reminder: WidgetReminder?) -> [Date] {
        var dates: [Date] = [now]

        if let tapAt = WidgetPetStore.lastTapAt {
            let tapEnd = tapAt.addingTimeInterval(WidgetPetMotion.tapDuration)
            if tapEnd > now {
                dates.append(tapEnd)
            }
        }

        if let celebrationEnd = WidgetCelebrationStore.celebrationEnd(after: now) {
            dates.append(celebrationEnd)
        }

        if let fireDate = reminder?.nextOccurrence, fireDate > now {
            dates.append(fireDate)
        }

        return Array(Set(dates.map { $0.timeIntervalSinceReferenceDate.rounded() }))
            .sorted()
            .map { Date(timeIntervalSinceReferenceDate: $0) }
            .filter { $0 >= now.addingTimeInterval(-0.05) }
    }

    private func reloadPolicyDate(from now: Date, reminder: WidgetReminder?, dates: [Date]) -> Date {
        if let nextOccurrence = reminder?.nextOccurrence, nextOccurrence > now {
            return nextOccurrence.addingTimeInterval(1)
        }

        if let tapEnd = dates.first(where: { $0 > now }) {
            return tapEnd
        }

        return now.addingTimeInterval(3600)
    }
}
