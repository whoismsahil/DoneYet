import Foundation

extension WidgetReminder {
    static func from(reminder: Reminder, recurrenceService: RecurrenceService = RecurrenceService()) -> WidgetReminder {
        let isPending = recurrenceService.isPending(reminder: reminder)
        let status: WidgetReminderStatus = isPending ? .pending : .completed
        let completedText = isPending ? nil : reminder.completedDisplayText
        let emoji = ReminderEmojiStyle.normalized(reminder.iconEmoji)
        let palette = ReminderEmojiStyle.palette(for: emoji)

        return WidgetReminder(
            id: reminder.id,
            title: reminder.displayTitle,
            pickerLabel: reminder.title,
            buttonText: reminder.completionButtonText,
            status: status,
            completedDisplayText: completedText,
            nextOccurrence: reminder.nextOccurrence,
            repeatType: reminder.resolvedRepeatType,
            hasScheduledDate: reminder.hasScheduledDate,
            showsUpcomingSchedule: reminder.isUpcomingNeverSchedule,
            iconEmoji: emoji,
            showsIconOnWidget: reminder.showsIconOnWidget,
            accentHex: palette?.backgroundHex,
            textHex: palette?.textHex
        )
    }
}
