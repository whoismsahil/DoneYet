import AppIntents
import Foundation
import WidgetKit

struct ReminderOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        let titles = SharedWidgetStore().pickerTitles()
        if !titles.isEmpty { return titles }
        return ((try? SharedWidgetStore().load()) ?? [])
            .filter(\.appearsInWidgetPicker)
            .map(\.pickerLabel)
    }

    func defaultResult() async -> String? {
        nil
    }
}

struct SelectReminderIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Reminder"
    static var description = IntentDescription("Choose the reminder this widget shows.")

    @Parameter(title: "Select Reminder", optionsProvider: ReminderOptionsProvider())
    var reminderTitle: String?

    init() {
        self.reminderTitle = nil
    }

    init(reminderTitle: String?) {
        self.reminderTitle = reminderTitle
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Select \(\.$reminderTitle)")
    }
}

extension SelectReminderIntent {
    var configuredSelection: String {
        reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
