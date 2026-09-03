import SwiftData
import SwiftUI

@Observable
@MainActor
final class HistoryViewModel {
    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [Item]
    }

    struct Item: Identifiable {
        let id: UUID
        let reminderID: UUID
        let title: String
        let completionText: String
        let time: String
        let repeatType: RepeatType
        let repeatInterval: Int?
        let weekdays: [Int]?
        let reminderHour: Int?
        let reminderMinute: Int?
        let scheduledDate: Date?
        let iconEmoji: String
        let showsIconOnWidget: Bool
    }

    private(set) var sections: [Section] = []
    var isSelecting = false
    var selectedIDs: Set<UUID> = []

    var hasItems: Bool { !sections.isEmpty }
    var selectedCount: Int { selectedIDs.count }
    var itemCount: Int { sections.flatMap(\.items).count }

    func load(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CompletionRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        guard let records = try? modelContext.fetch(descriptor) else {
            sections = []
            selectedIDs = []
            return
        }

        let reminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
        let widgetTitles = Dictionary(
            ((try? SharedWidgetStore().load()) ?? []).map { ($0.id, $0.title) },
            uniquingKeysWith: { _, latest in latest }
        )

        repairTitles(
            records: records,
            reminders: reminders,
            widgetTitles: widgetTitles,
            modelContext: modelContext
        )

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record -> Date in
            calendar.startOfDay(for: record.completedAt)
        }

        sections = grouped.keys.sorted(by: >).map { day in
            let items = grouped[day] ?? []
            return Section(
                id: day.formatted(date: .numeric, time: .omitted),
                title: sectionTitle(for: day, calendar: calendar),
                items: items
                    .sorted { $0.completedAt > $1.completedAt }
                    .map { record in
                    let reminder = reminders.first { $0.id == record.reminderID }
                    let title = historyTitle(
                        for: record,
                        reminder: reminder,
                        widgetTitle: widgetTitles[record.reminderID]
                    )

                    return Item(
                        id: record.id,
                        reminderID: record.reminderID,
                        title: title,
                        completionText: record.completionText.isEmpty
                            ? (reminder?.completionButtonText ?? record.completionText)
                            : record.completionText,
                        time: timeString(for: record.completedAt),
                        repeatType: record.repeatType == .never
                            ? (reminder?.resolvedRepeatType ?? .never)
                            : record.repeatType,
                        repeatInterval: record.repeatInterval ?? reminder?.repeatInterval,
                        weekdays: record.weekdays ?? reminder?.weekdays,
                        reminderHour: record.reminderHour ?? reminder?.reminderHour,
                        reminderMinute: record.reminderMinute ?? reminder?.reminderMinute,
                        scheduledDate: record.scheduledDate ?? reminder?.scheduledDate,
                        iconEmoji: ReminderEmojiStyle.normalized(record.iconEmoji)
                            ?? ReminderEmojiStyle.normalized(reminder?.iconEmoji)
                            ?? "",
                        showsIconOnWidget: record.showsIconOnWidget
                    )
                }
            )
        }

        let validIDs = Set(sections.flatMap(\.items).map(\.id))
        selectedIDs = selectedIDs.intersection(validIDs)
        if sections.isEmpty {
            isSelecting = false
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func isSelected(_ id: UUID) -> Bool {
        selectedIDs.contains(id)
    }

    func selectAll() {
        selectedIDs = Set(sections.flatMap(\.items).map(\.id))
    }

    func clearSelection() {
        selectedIDs = []
        isSelecting = false
    }

    func delete(ids: Set<UUID>, modelContext: ModelContext) {
        guard !ids.isEmpty else { return }

        let descriptor = FetchDescriptor<CompletionRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records where ids.contains(record.id) {
            modelContext.delete(record)
        }

        try? modelContext.save()
        load(modelContext: modelContext)
        ReminderChangeNotifier.post()
    }

    func delete(id: UUID, modelContext: ModelContext) {
        delete(ids: [id], modelContext: modelContext)
    }

    func deleteSelected(modelContext: ModelContext) {
        delete(ids: selectedIDs, modelContext: modelContext)
        isSelecting = false
        selectedIDs = []
    }

    func deleteAll(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CompletionRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            modelContext.delete(record)
        }

        try? modelContext.save()
        isSelecting = false
        selectedIDs = []
        load(modelContext: modelContext)
        ReminderChangeNotifier.post()
    }

    private func repairTitles(
        records: [CompletionRecord],
        reminders: [Reminder],
        widgetTitles: [UUID: String],
        modelContext: ModelContext
    ) {
        var didChange = false

        for record in records {
            if !record.storedTitle.isEmpty { continue }

            if let reminder = reminders.first(where: { $0.id == record.reminderID }),
               !reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                record.applySnapshot(from: reminder)
                didChange = true
                continue
            }

            if let widgetTitle = widgetTitles[record.reminderID],
               !widgetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               widgetTitle.caseInsensitiveCompare("Reminder") != .orderedSame {
                record.capturedName = widgetTitle
                record.reminderTitle = widgetTitle
                record.title = widgetTitle
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }

    private func historyTitle(for record: CompletionRecord, reminder: Reminder?, widgetTitle: String?) -> String {
        let names = [
            reminder?.title,
            record.storedTitle,
            widgetTitle
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare("Reminder") != .orderedSame }

        return names.first ?? record.storedTitle
    }

    private func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }

    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
