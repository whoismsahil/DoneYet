import Foundation

enum WidgetReminderLoader {
    static func activeReminderIDs() -> [String] {
        ((try? SharedWidgetStore().load()) ?? []).map(\.id.uuidString)
    }

    static func activeReminderTitles() -> [String] {
        SharedWidgetStore().pickerTitles()
    }

    static func displayTitle(for selection: String) -> String {
        if let reminder = reminder(for: selection) {
            return reminder.pickerLabel
        }
        return selection.isEmpty ? "Reminder" : selection
    }

    static func pickerLabel(for reminderID: String) -> String {
        guard let uuid = UUID(uuidString: reminderID) else { return "Reminder" }
        return (try? SharedWidgetStore().reminder(id: uuid))?.pickerLabel ?? "Reminder"
    }

    static func reminderID(forSelection selection: String) -> String? {
        guard !selection.isEmpty else { return nil }

        if let uuid = UUID(uuidString: selection) {
            return uuid.uuidString
        }

        let reminders = (try? SharedWidgetStore().load()) ?? []
        if let match = reminders.first(where: { $0.pickerLabel == selection || $0.title == selection }) {
            return match.id.uuidString
        }

        // Titles may be uniqued as "Name (2)" in the picker list.
        let base = selection.replacingOccurrences(of: #" \(\d+\)$"#, with: "", options: .regularExpression)
        return reminders.first(where: { $0.pickerLabel == base || $0.title == base })?.id.uuidString
    }

    static func reminder(for selection: String) -> WidgetReminder? {
        guard !selection.isEmpty else { return nil }

        let reminders = (try? SharedWidgetStore().load()) ?? []

        if let uuid = UUID(uuidString: selection) {
            return reminders.first(where: { $0.id == uuid })
        }

        if let match = reminders.first(where: { $0.pickerLabel == selection || $0.title == selection }) {
            return match
        }

        let base = selection.replacingOccurrences(of: #" \(\d+\)$"#, with: "", options: .regularExpression)
        return reminders.first(where: { $0.pickerLabel == base || $0.title == base })
    }
}
