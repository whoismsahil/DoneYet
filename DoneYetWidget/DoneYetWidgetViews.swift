import AppIntents
import SwiftUI
import WidgetKit

struct DoneYetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DoneYetWidgetEntry

    private var theme: WidgetTheme {
        WidgetThemeStore.current
    }

    private var pet: WidgetPet {
        WidgetPetStore.current
    }

    private var emojiPalette: ReminderEmojiStyle.Palette? {
        guard WidgetThemeStore.usesEmojiColor else { return nil }
        if let palette = ReminderEmojiStyle.palette(for: displayedReminder?.iconEmoji) {
            return palette
        }
        if let backgroundHex = displayedReminder?.accentHex,
           let textHex = displayedReminder?.textHex {
            return ReminderEmojiStyle.Palette(backgroundHex: backgroundHex, textHex: textHex)
        }
        return nil
    }

    private var canvasBackground: Color {
        if let hex = emojiPalette?.backgroundHex {
            return Color(hex: hex)
        }
        return theme.background
    }

    private var canvasForeground: Color {
        if let hex = emojiPalette?.textHex {
            return Color(hex: hex)
        }
        return theme.text
    }

    private var configuredSelection: String {
        entry.configuration.configuredSelection
    }

    private var displayedReminder: WidgetReminder? {
        let reminder = WidgetReminderLoader.reminder(for: entry.reminderID)
            ?? WidgetReminderLoader.reminder(for: configuredSelection)
            ?? entry.reminder
        return reminder?.resolved(at: entry.date)
    }

    var body: some View {
        Group {
            if let reminder = displayedReminder {
                reminderContent(reminder)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            canvasBackground
        }
    }

    private func reminderContent(_ reminder: WidgetReminder) -> some View {
        widgetCanvas(
            title: reminder.pickerLabel,
            buttonText: reminder.buttonText,
            isCompleted: reminder.status == .completed,
            reminderID: reminder.id.uuidString,
            nextOccurrence: reminder.nextOccurrence,
            repeatType: reminder.repeatType,
            hasScheduledDate: reminder.hasScheduledDate,
            showsUpcomingSchedule: reminder.showsUpcomingSchedule,
            iconEmoji: reminder.iconEmoji,
            showsIconOnWidget: reminder.showsIconOnWidget,
            petMotion: entry.petMotion,
            isCelebrating: entry.isCelebrating
        )
    }

    private var emptyState: some View {
        widgetCanvas(
            title: "Select a reminder",
            buttonText: "DONE YET?",
            isCompleted: false,
            reminderID: nil,
            nextOccurrence: nil,
            repeatType: .never,
            hasScheduledDate: false,
            showsUpcomingSchedule: false,
            iconEmoji: nil,
            showsIconOnWidget: false,
            petMotion: .still,
            isCelebrating: false
        )
    }

    private func widgetCanvas(
        title: String,
        buttonText: String,
        isCompleted: Bool,
        reminderID: String?,
        nextOccurrence: Date?,
        repeatType: RepeatType,
        hasScheduledDate: Bool,
        showsUpcomingSchedule: Bool,
        iconEmoji: String?,
        showsIconOnWidget: Bool,
        petMotion: WidgetPetMotion,
        isCelebrating: Bool
    ) -> some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { _ in
                ZStack(alignment: .topLeading) {
                    Circle()
                        .fill(AppColors.widgetCircle)
                        .frame(width: circleSize, height: circleSize)
                        .position(circleCenter(for: family))
                        .opacity((!isCompleted && !showsUpcomingSchedule) ? 1 : 0)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: titleCheckmarkSpacing) {
                            if showsIconOnWidget, let iconEmoji, ReminderEmojiStyle.normalized(iconEmoji) != nil {
                                ReminderEmojiGlyph(
                                    emoji: iconEmoji,
                                    size: family == .systemLarge ? 36 : 22,
                                    white: false
                                )
                                .padding(.top, 1)
                            }

                            Text(WidgetDisplayText.wrappingTitle(title))
                                .font(.system(size: titleSize, weight: .bold, design: .default))
                                .foregroundStyle(canvasForeground)
                                .multilineTextAlignment(TextAlignment.leading)
                                .lineLimit(titleLineLimit)
                                .truncationMode(Text.TruncationMode.tail)
                                .minimumScaleFactor(1)
                                .frame(maxWidth: .infinity, alignment: Alignment.topLeading)

                            if isCompleted {
                                CompletedCheckmark(foreground: canvasForeground, size: completedCheckmarkSize)
                                    .modifier(WidgetCompletionBurst(isCelebrating: isCelebrating))
                            }
                        }

                        Spacer(minLength: 0)

                        if showsUpcomingSchedule,
                           let nextOccurrence,
                           let nextCopy = WidgetNextOccurrenceCopy.make(
                                repeatType: .never,
                                nextOccurrence: nextOccurrence,
                                hasScheduledDate: hasScheduledDate
                           ) {
                            HStack {
                                Spacer(minLength: 0)
                                WidgetRepeatingNextOccurrenceView(
                                    copy: nextCopy,
                                    textColor: canvasForeground,
                                    captionSize: nextCaptionSize,
                                    timeSize: nextTimeSize
                                )
                            }
                        } else if isCompleted,
                                  let nextOccurrence,
                                  let nextCopy = WidgetNextOccurrenceCopy.make(
                                    repeatType: repeatType,
                                    nextOccurrence: nextOccurrence
                                  ) {
                            HStack {
                                Spacer(minLength: 0)
                                WidgetRepeatingNextOccurrenceView(
                                    copy: nextCopy,
                                    textColor: canvasForeground,
                                    captionSize: nextCaptionSize,
                                    timeSize: nextTimeSize
                                )
                            }
                        } else if !isCompleted {
                            Color.clear
                                .frame(height: actionSize * 2)
                        }
                    }
                    .padding(WidgetLayout.margin)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isCompleted {
                Button(intent: PokeWidgetPetIntent()) {
                    WidgetPetSprite(
                        pet: pet,
                        color: canvasForeground,
                        height: petHeight,
                        motion: petMotion
                    )
                }
                .buttonStyle(WidgetPetTapStyle())
                .padding(.top, petTop)
                .padding(.trailing, petTrailing)
                .accessibilityLabel("\(pet.title). Tap to play.")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isCompleted, !showsUpcomingSchedule {
                action(isCompleted: isCompleted, buttonText: buttonText, reminderID: reminderID)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private func action(isCompleted: Bool, buttonText: String, reminderID: String?) -> some View {
        if let reminderID, !reminderID.isEmpty {
            Button(intent: CompleteWidgetReminderIntent(reminderID: reminderID)) {
                actionLabel(for: buttonText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(WidgetDoneYetTapStyle())
            .contentShape(Rectangle())
            .accessibilityLabel(buttonText)
        } else {
            actionLabel(for: buttonText)
        }
    }

    private func actionLabel(for buttonText: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(actionLines(for: buttonText).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(AppFont.sfMono(actionSize, weight: .regular))
                    .foregroundStyle(canvasForeground)
                    .frame(height: actionSize, alignment: .center)
            }
        }
        .multilineTextAlignment(.trailing)
    }

    private var petHeight: CGFloat {
        family == .systemLarge ? WidgetLayout.petHeight * WidgetLayout.petScaleLarge : WidgetLayout.petHeight
    }

    private var petTop: CGFloat {
        switch family {
        case .systemSmall: WidgetLayout.petTopSmall
        case .systemMedium: WidgetLayout.petTopMedium
        case .systemLarge: WidgetLayout.petTopLarge
        default: WidgetLayout.petTopSmall
        }
    }

    private var petTrailing: CGFloat {
        switch family {
        case .systemSmall: WidgetLayout.petTrailingSmall
        case .systemLarge: WidgetLayout.petTrailingLarge
        default: WidgetLayout.petTrailingMedium
        }
    }

    private var titleCheckmarkSpacing: CGFloat {
        family == .systemLarge ? WidgetLayout.titleCheckmarkSpacingLarge : WidgetLayout.titleCheckmarkSpacing
    }

    private var nextCaptionSize: CGFloat {
        family == .systemLarge ? WidgetLayout.nextCaptionSizeLarge : WidgetLayout.nextCaptionSize
    }

    private var nextTimeSize: CGFloat {
        family == .systemLarge ? WidgetLayout.largeActionSize : WidgetLayout.smallActionSize
    }

    private var titleLineLimit: Int {
        switch family {
        case .systemSmall, .systemMedium: 3
        case .systemLarge: 4
        default: 2
        }
    }

    private var completedCheckmarkSize: CGFloat {
        switch family {
        case .systemSmall: WidgetLayout.checkmarkSize
        case .systemLarge: WidgetLayout.largeCheckmarkSize
        default: WidgetLayout.mediumCheckmarkSize
        }
    }

    private var circleSize: CGFloat {
        family == .systemLarge ? WidgetLayout.largeCircleSize : WidgetLayout.smallCircleSize
    }

    private var titleSize: CGFloat {
        switch family {
        case .systemLarge: WidgetLayout.largeTitleSize
        case .systemMedium: WidgetLayout.mediumTitleSize
        default: WidgetLayout.smallTitleSize
        }
    }

    private var actionSize: CGFloat {
        family == .systemLarge ? WidgetLayout.largeActionSize : WidgetLayout.smallActionSize
    }

    private func circleCenter(for family: WidgetFamily) -> CGPoint {
        switch family {
        case .systemMedium:
            return CGPoint(
                x: WidgetLayout.mediumCircleLeft + circleSize / 2,
                y: WidgetLayout.smallCircleTop + circleSize / 2
            )
        case .systemLarge:
            return CGPoint(
                x: WidgetLayout.largeCircleLeft + circleSize / 2,
                y: WidgetLayout.largeCircleTop + circleSize / 2
            )
        default:
            return CGPoint(
                x: WidgetLayout.smallCircleLeft + circleSize / 2,
                y: WidgetLayout.smallCircleTop + circleSize / 2
            )
        }
    }

    private func actionLines(for buttonText: String) -> [String] {
        let normalized = buttonText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if normalized == "DONE YET?" {
            return ["DONE", "YET?"]
        }

        let words = normalized.split(separator: " ").map(String.init)
        guard words.count > 1 else {
            return [normalized]
        }

        let midpoint = words.count / 2
        return [
            words[..<midpoint].joined(separator: " "),
            words[midpoint...].joined(separator: " ")
        ]
    }
}

private struct WidgetDoneYetTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.45), value: configuration.isPressed)
    }
}

private struct WidgetCompletionBurst: ViewModifier {
    let isCelebrating: Bool

    func body(content: Content) -> some View {
        if isCelebrating {
            TimelineView(.animation(minimumInterval: 1 / 20, paused: false)) { context in
                let wave = abs(sin(context.date.timeIntervalSinceReferenceDate * 9))
                content
                    .scaleEffect(1 + 0.42 * wave)
                    .opacity(0.75 + 0.25 * wave)
                    .overlay {
                        Circle()
                            .stroke(lineWidth: 3)
                            .scaleEffect(0.85 + 0.55 * wave)
                            .opacity(0.85 * (1 - wave))
                    }
            }
        } else {
            content
        }
    }
}
