import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct CompleteWidgetReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Done Yet Widget Complete"
    static var description = IntentDescription("Mark this reminder as done from the widget.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Reminder ID")
    var reminderID: String

    init() {
        self.reminderID = ""
    }

    init(reminderID: String) {
        self.reminderID = reminderID
    }

    func perform() async throws -> some IntentResult {
        let selection = reminderID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else {
            await MainActor.run {
                WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
            }
            return .result()
        }

        await MainActor.run {
            try? WidgetCompletion.apply(reminderID: selection)
        }

        let uuid = await MainActor.run {
            UUID(uuidString: selection) ?? WidgetReminderLoader.reminder(for: selection).map(\.id)
        }

        if let uuid {
            await ReminderNotificationScheduler.cancelAll(id: uuid)
            await MainActor.run {
                do {
                    let context = ModelContext(AppSchema.modelContainer)
                    let reminders = try context.fetch(FetchDescriptor<Reminder>())
                    if let reminder = reminders.first(where: { $0.id == uuid }) {
                        let needsComplete = reminder.lastCompletedAt == nil
                            || (reminder.repeats && reminder.isPending())

                        if needsComplete {
                            if !reminder.isActive, !reminder.repeats {
                                reminder.isActive = true
                            }
                            let service = ReminderService(
                                modelContext: context,
                                notificationService: DefaultReminderNotificationScheduling()
                            )
                            try service.complete(reminder)
                        }
                    }
                } catch {
                    WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
                }
            }
        }

        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
            ReminderChangeNotifier.post()
        }
        return .result()
    }
}
