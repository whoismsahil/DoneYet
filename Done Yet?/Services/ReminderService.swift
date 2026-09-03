import Foundation
import SwiftData
import WidgetKit

@MainActor
struct ReminderService {
    let modelContext: ModelContext
    private let recurrenceService: RecurrenceService
    private let widgetStore: SharedWidgetStore
    private let notificationService: ReminderNotificationScheduling?

    init(
        modelContext: ModelContext,
        recurrenceService: RecurrenceService? = nil,
        widgetStore: SharedWidgetStore? = nil,
        notificationService: ReminderNotificationScheduling? = nil
    ) {
        self.modelContext = modelContext
        self.recurrenceService = recurrenceService ?? RecurrenceService()
        self.widgetStore = widgetStore ?? SharedWidgetStore()
        self.notificationService = notificationService
    }

    func fetchActiveReminders() throws -> [Reminder] {
        try mergeExternalChanges()
        try reconcileCompletionsFromWidgetStore()

        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func mergeExternalChanges() throws {
        let sideContext = ModelContext(AppSchema.modelContainer)
        let allDescriptor = FetchDescriptor<Reminder>()
        let fresh = try sideContext.fetch(allDescriptor)
        let current = try modelContext.fetch(allDescriptor)

        let freshByID = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for reminder in current {
            guard let updated = freshByID[reminder.id] else { continue }
            if reminder.isActive, reminder.lastCompletedAt == nil,
               !updated.isActive, updated.lastCompletedAt != nil {
                continue
            }
            // Stale side-context reads can wipe a completion we just saved in this context.
            if reminder.lastCompletedAt != nil, updated.lastCompletedAt == nil {
                continue
            }
            if updated.updatedAt < reminder.updatedAt {
                continue
            }
            reminder.lastCompletedAt = updated.lastCompletedAt
            reminder.nextOccurrence = updated.nextOccurrence
            reminder.updatedAt = updated.updatedAt
            reminder.isActive = updated.isActive
        }
    }

    /// Widget extensions update the shared JSON snapshot reliably; SwiftData may lag across processes.
    /// Treat a completed widget snapshot as source of truth when the app still shows pending.
    private func reconcileCompletionsFromWidgetStore() throws {
        let snapshots = (try? widgetStore.load()) ?? []
        guard !snapshots.isEmpty else { return }

        let reminders = try modelContext.fetch(FetchDescriptor<Reminder>())
        var didChange = false

        for snapshot in snapshots where snapshot.status == .completed {
            guard let reminder = reminders.first(where: { $0.id == snapshot.id }) else { continue }
            reminder.syncRepeatFields()

            if !reminder.repeats {
                guard reminder.lastCompletedAt == nil else { continue }
                // A restore reactivates the reminder; don't immediately archive it again
                // from a stale completed widget snapshot.
                if reminder.isActive { continue }
                let now = Date()
                reminder.lastCompletedAt = now
                reminder.updatedAt = now
                reminder.nextOccurrence = nil
                reminder.isActive = false

                let existingRecords = try modelContext.fetch(FetchDescriptor<CompletionRecord>())
                let alreadyArchived = existingRecords.contains { $0.reminderID == reminder.id }
                if !alreadyArchived {
                    modelContext.insert(CompletionRecord.snapshot(from: reminder, completedAt: now))
                }

                cancelNotification(for: reminder)
                didChange = true
                continue
            }

            guard reminder.isPending(recurrenceService: recurrenceService) else { continue }
            let now = Date()
            reminder.lastCompletedAt = now
            reminder.updatedAt = now
            reminder.nextOccurrence = snapshot.nextOccurrence
                ?? recurrenceService.nextOccurrence(for: reminder, after: now)
                ?? recurrenceService.firstOccurrence(for: reminder, from: now)
            syncNotification(for: reminder)
            didChange = true
        }

        guard didChange else { return }
        try modelContext.save()
        try persistWidgetStoreFromContext()
    }

    private func persistWidgetStoreFromContext() throws {
        let descriptor = FetchDescriptor<Reminder>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let reminders = try modelContext.fetch(descriptor)
        try widgetStore.save(reminders: widgetRemindersPreservingCompleted(from: reminders))
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
    }

    /// Prefer an existing completed snapshot over a stale remap back to pending.
    private func widgetRemindersPreservingCompleted(from reminders: [Reminder]) -> [WidgetReminder] {
        let existing = (try? widgetStore.load()) ?? []
        let completedByID = Dictionary(
            uniqueKeysWithValues: existing.filter { $0.status == .completed }.map { ($0.id, $0) }
        )

        return reminders.map { reminder in
            let mapped = WidgetReminder.from(reminder: reminder, recurrenceService: recurrenceService)
            guard mapped.status == .pending, let prior = completedByID[reminder.id] else {
                return mapped
            }

            // Restored / still-open reminders must not keep a stale completed snapshot.
            if reminder.isActive, reminder.lastCompletedAt == nil {
                return mapped
            }

            // One-off: keep celebration state on the widget after Done Yet?
            if !prior.repeatType.isRepeating {
                return prior
            }

            // Repeating: keep completed until the stored next occurrence is due.
            if let next = prior.nextOccurrence, next > .now {
                return prior
            }

            return mapped
        }
    }

    func save(_ reminder: Reminder) throws {
        reminder.updatedAt = Date()
        reminder.syncRepeatFields()
        refreshOccurrence(for: reminder)
        try modelContext.save()
        try syncWidgetStore()
        syncNotification(for: reminder)
        ReminderChangeNotifier.post()
    }

    func delete(_ reminder: Reminder) throws {
        try deleteReminder(id: reminder.id)
    }

    func deleteReminder(id: UUID) throws {
        let reminders = try modelContext.fetch(FetchDescriptor<Reminder>())
        guard let reminder = reminders.first(where: { $0.id == id }) else { return }

        cancelNotification(for: reminder)

        let records = try modelContext.fetch(FetchDescriptor<CompletionRecord>())
            .filter { $0.reminderID == id }

        if records.isEmpty {
            modelContext.insert(CompletionRecord.snapshot(from: reminder))
        } else {
            for record in records {
                record.applySnapshot(from: reminder)
            }
        }

        modelContext.delete(reminder)
        try modelContext.save()
        try syncWidgetStore()
        ReminderChangeNotifier.post()
    }

    func pause(_ reminder: Reminder) throws {
        reminder.isActive = false
        reminder.updatedAt = Date()
        try modelContext.save()
        try syncWidgetStore()
        cancelNotification(for: reminder)
        ReminderChangeNotifier.post()
    }

    func fetchPausedReminders() throws -> [Reminder] {
        try mergeExternalChanges()
        try reconcileCompletionsFromWidgetStore()

        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).filter { $0.repeats }
    }

    func resume(_ reminder: Reminder) throws {
        reminder.syncRepeatFields()
        reminder.isActive = true
        reminder.updatedAt = Date()
        refreshOccurrence(for: reminder)
        try modelContext.save()
        try syncWidgetStore()
        syncNotification(for: reminder)
        ReminderChangeNotifier.post()
    }

    func create(
        title: String,
        completionButtonText: String = "DONE YET?",
        repeatType: RepeatType = .never,
        repeatInterval: Int? = nil,
        weekdays: [Int]? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        scheduledDate: Date? = nil,
        iconEmoji: String = "",
        showsIconOnWidget: Bool = true
    ) throws -> Reminder {
        let reminder = Reminder(
            title: title,
            completionButtonText: completionButtonText,
            isRepeating: repeatType != .never,
            repeatType: repeatType,
            repeatInterval: repeatInterval,
            weekdays: weekdays,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            scheduledDate: scheduledDate,
            iconEmoji: iconEmoji,
            showsIconOnWidget: showsIconOnWidget
        )
        reminder.syncRepeatFields()
        refreshOccurrence(for: reminder)
        modelContext.insert(reminder)
        try modelContext.save()
        try syncWidgetStore()
        syncNotification(for: reminder)
        ReminderChangeNotifier.post()
        return reminder
    }

    func complete(_ reminder: Reminder) throws {
        let now = Date()
        reminder.syncRepeatFields()

        // One-off reminders can be completed whenever they haven't been completed yet.
        if !reminder.repeats {
            if reminder.lastCompletedAt != nil {
                try writeWidgetCompletedState(for: reminder)
                WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
                return
            }
            reminder.isActive = true
        }

        reminder.lastCompletedAt = now
        reminder.updatedAt = now

        if reminder.repeats {
            reminder.nextOccurrence = recurrenceService.nextOccurrence(for: reminder, after: now)
                ?? recurrenceService.firstOccurrence(for: reminder, from: now)
            try modelContext.save()
            try writeWidgetCompletedState(for: reminder)
            syncNotification(for: reminder)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
            ReminderChangeNotifier.post()
            return
        }

        let record = CompletionRecord.snapshot(from: reminder, completedAt: now)
        modelContext.insert(record)
        reminder.nextOccurrence = nil
        reminder.isActive = false
        cancelNotification(for: reminder)

        try modelContext.save()
        try writeWidgetCompletedState(for: reminder)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        ReminderChangeNotifier.post()
    }

    /// Writes the celebration/completed widget snapshot without remapping through a stale merge.
    private func writeWidgetCompletedState(for reminder: Reminder) throws {
        var reminders = (try? widgetStore.load()) ?? []
        let completed = WidgetReminder(
            id: reminder.id,
            title: reminder.displayTitle,
            pickerLabel: reminder.title,
            buttonText: reminder.completionButtonText,
            status: .completed,
            completedDisplayText: reminder.completedDisplayText,
            nextOccurrence: reminder.repeats ? reminder.nextOccurrence : nil,
            repeatType: reminder.resolvedRepeatType,
            hasScheduledDate: reminder.hasScheduledDate,
            showsUpcomingSchedule: false,
            iconEmoji: ReminderEmojiStyle.normalized(reminder.iconEmoji),
            showsIconOnWidget: reminder.showsIconOnWidget,
            accentHex: ReminderEmojiStyle.palette(for: reminder.iconEmoji)?.backgroundHex,
            textHex: ReminderEmojiStyle.palette(for: reminder.iconEmoji)?.textHex
        )

        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = completed
        } else {
            reminders.insert(completed, at: 0)
        }

        try widgetStore.save(reminders: reminders)
    }

    func addAgain(
        reminderID: UUID,
        title: String,
        completionButtonText: String,
        repeatType: RepeatType = .never,
        repeatInterval: Int? = nil,
        weekdays: [Int]? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        scheduledDate: Date? = nil,
        completionRecordID: UUID? = nil,
        iconEmoji: String? = nil,
        showsIconOnWidget: Bool? = nil
    ) throws {
        let existing = try modelContext.fetch(FetchDescriptor<Reminder>()).first { $0.id == reminderID }
        let restored: Reminder

        if let reminder = existing {
            if Self.shouldApplyRestoredTitle(title, onto: reminder, completionButtonText: completionButtonText) {
                reminder.title = title
            }
            if !completionButtonText.isEmpty {
                reminder.completionButtonText = completionButtonText
            }
            reminder.repeatType = repeatType
            reminder.isRepeating = repeatType != .never
            reminder.repeatInterval = repeatInterval ?? reminder.repeatInterval
            reminder.weekdays = weekdays ?? reminder.weekdays
            reminder.reminderHour = reminderHour ?? reminder.reminderHour
            reminder.reminderMinute = reminderMinute ?? reminder.reminderMinute
            reminder.scheduledDate = scheduledDate ?? reminder.scheduledDate
            if let iconEmoji {
                reminder.iconEmoji = ReminderEmojiStyle.normalized(iconEmoji) ?? ""
            }
            if let showsIconOnWidget {
                reminder.showsIconOnWidget = showsIconOnWidget
            }
            reminder.isActive = true
            reminder.lastCompletedAt = nil
            reminder.createdAt = Date()
            reminder.updatedAt = Date()
            reminder.syncRepeatFields()
            refreshOccurrence(for: reminder)
            restored = reminder
            syncNotification(for: reminder)
        } else {
            restored = try create(
                title: title,
                completionButtonText: completionButtonText,
                repeatType: repeatType,
                repeatInterval: repeatInterval,
                weekdays: weekdays,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                scheduledDate: scheduledDate,
                iconEmoji: iconEmoji ?? "",
                showsIconOnWidget: showsIconOnWidget ?? true
            )
        }

        let records = try modelContext.fetch(FetchDescriptor<CompletionRecord>())
        for record in records {
            let matchesItem = completionRecordID.map { record.id == $0 } ?? false
            let matchesOneOff = !restored.repeats && record.reminderID == restored.id
            if matchesItem || matchesOneOff {
                modelContext.delete(record)
            }
        }

        try modelContext.save()
        try writeWidgetPendingState(for: restored)
        try syncWidgetStore()
        ReminderChangeNotifier.post()
    }

    private func writeWidgetPendingState(for reminder: Reminder) throws {
        var reminders = (try? widgetStore.load()) ?? []
        let pending = WidgetReminder.from(reminder: reminder, recurrenceService: recurrenceService)

        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = pending
        } else {
            reminders.insert(pending, at: 0)
        }

        try widgetStore.save(reminders: reminders)
    }

    func rescheduleNotifications() {
        guard let reminders = try? fetchActiveReminders() else { return }
        for reminder in reminders {
            syncNotification(for: reminder)
        }
    }

    func syncWidgetStore() throws {
        let reminders = try fetchRemindersForWidget()
        try widgetStore.save(reminders: widgetRemindersPreservingCompleted(from: reminders))
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
    }

    private func fetchRemindersForWidget() throws -> [Reminder] {
        try mergeExternalChanges()
        try reconcileCompletionsFromWidgetStore()

        let descriptor = FetchDescriptor<Reminder>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func refreshOccurrence(for reminder: Reminder) {
        if reminder.repeatType == .never {
            reminder.scheduledDate = reminder.hasScheduledTime ? reminder.scheduledDate : nil
            reminder.nextOccurrence = reminder.hasScheduledTime ? reminder.scheduledFireDate() : nil
            return
        }


        if reminder.isPending(recurrenceService: recurrenceService) {
            reminder.nextOccurrence = recurrenceService.firstOccurrence(for: reminder)
        } else if let lastCompletedAt = reminder.lastCompletedAt {
            reminder.nextOccurrence = recurrenceService.nextOccurrence(for: reminder, after: lastCompletedAt)
        } else {
            reminder.nextOccurrence = recurrenceService.firstOccurrence(for: reminder)
        }
    }

    private func syncNotification(for reminder: Reminder) {
        guard let notificationService else { return }
        Task {
            await notificationService.schedule(for: reminder)
        }
    }

    private func cancelNotification(for reminder: Reminder) {
        guard let notificationService else { return }
        Task {
            await notificationService.cancel(for: reminder)
        }
    }

    private static func isPlaceholderTitle(_ title: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Reminder") == .orderedSame
    }

    private static func shouldApplyRestoredTitle(
        _ title: String,
        onto reminder: Reminder,
        completionButtonText: String
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isPlaceholderTitle(trimmed) else { return false }
        if trimmed.caseInsensitiveCompare(completionButtonText) == .orderedSame, !reminder.title.isEmpty {
            return false
        }
        return true
    }

    private static func keepsScheduledDate(for repeatType: RepeatType) -> Bool {
        true
    }
}
