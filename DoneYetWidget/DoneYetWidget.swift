import AppIntents
import SwiftUI
import WidgetKit

struct DoneYetReminderWidget: Widget {
    static let kind = AppGroupConstants.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectReminderIntent.self,
            provider: DoneYetWidgetProvider()
        ) { entry in
            DoneYetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Reminder")
        .description("Shows one reminder. Tap Done Yet? when you’re finished.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
