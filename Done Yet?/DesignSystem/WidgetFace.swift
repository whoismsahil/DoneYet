import SwiftUI

enum WidgetLayout {
    static let margin: CGFloat = 16

    static let smallCircleSize: CGFloat = 124
    static let smallCircleTop: CGFloat = 64
    static let smallCircleLeft: CGFloat = 58
    static let smallTitleSize: CGFloat = 14
    static let smallActionSize: CGFloat = 24

    static let mediumCircleLeft: CGFloat = 240
    static let mediumTitleSize: CGFloat = 18

    static let largeCircleSize: CGFloat = 220
    static let largeCircleTop: CGFloat = 194
    static let largeCircleLeft: CGFloat = 168
    static let largeTitleSize: CGFloat = 32
    static let largeActionSize: CGFloat = 44

    static let checkmarkSize: CGFloat = 24
    static let mediumCheckmarkSize: CGFloat = 32
    static let largeCheckmarkSize: CGFloat = 44
    static let smallPreviewSize: CGFloat = 158

    static let titleCheckmarkSpacing: CGFloat = 12
    static let titleCheckmarkSpacingLarge: CGFloat = 20
    static let petTopSmall: CGFloat = 102
    static let petTopMedium: CGFloat = 100
    static let petTrailingSmall: CGFloat = 104
    static let petTrailingMedium: CGFloat = 273
    static let petTopLarge: CGFloat = 224
    static let petTrailingLarge: CGFloat = 203
    static let petHeight: CGFloat = 65
    static let petScaleLarge: CGFloat = 2.2

    static let nextCaptionSize: CGFloat = 12
    static let nextCaptionSizeLarge: CGFloat = 14
    static let nextCaptionOpacity: Double = 0.7
}

struct WidgetFace: View {
    enum Style {
        case small
        case medium
        case large
    }

    let title: String
    let buttonText: String
    let isCompleted: Bool
    let theme: WidgetTheme
    var pet: WidgetPet = WidgetPetStore.current
    var style: Style = .small
    var showsInteractiveButton: Bool = false
    var onComplete: (() -> Void)? = nil
    var nextOccurrence: Date? = nil
    var repeatType: RepeatType = .never
    var hasScheduledDate: Bool = false
    var showsUpcomingSchedule: Bool = false
    var iconEmoji: String? = nil
    var showsIconOnWidget: Bool = true
    var usesEmojiColor: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var petTapAt: Date?
    @State private var localPetMotion: WidgetPetMotion = .idle

    private var previewEmoji: String? {
        ReminderEmojiStyle.normalized(iconEmoji)
    }

    private var canvasBackground: Color {
        if usesEmojiColor, let previewEmoji, let palette = ReminderEmojiStyle.palette(for: previewEmoji) {
            return Color(hex: palette.backgroundHex)
        }
        return theme.background
    }

    private var canvasForeground: Color {
        if usesEmojiColor, let previewEmoji, let palette = ReminderEmojiStyle.palette(for: previewEmoji) {
            return Color(hex: palette.textHex)
        }
        return theme.text
    }

    private var showsDoneYetButton: Bool {
        !isCompleted && !showsUpcomingSchedule
    }

    private var titleSize: CGFloat {
        switch style {
        case .small: WidgetLayout.smallTitleSize
        case .medium: WidgetLayout.mediumTitleSize
        case .large: WidgetLayout.largeTitleSize
        }
    }

    private var completedCheckmarkSize: CGFloat {
        switch style {
        case .small: WidgetLayout.checkmarkSize
        case .medium: WidgetLayout.mediumCheckmarkSize
        case .large: WidgetLayout.largeCheckmarkSize
        }
    }

    private var actionSize: CGFloat {
        switch style {
        case .small, .medium: WidgetLayout.smallActionSize
        case .large: WidgetLayout.largeActionSize
        }
    }

    private var circleSize: CGFloat {
        style == .large ? WidgetLayout.largeCircleSize : WidgetLayout.smallCircleSize
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                canvasBackground

                if showsDoneYetButton {
                    Circle()
                        .fill(AppColors.widgetCircle)
                        .frame(width: circleSize, height: circleSize)
                        .position(circleCenter)
                        .allowsHitTesting(false)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: titleCheckmarkSpacing) {
                        if showsIconOnWidget, let previewEmoji {
                            ReminderEmojiGlyph(
                                emoji: previewEmoji,
                                size: style == .large ? 36 : 22,
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
                        }
                    }

                    Spacer(minLength: 0)

                    if showsUpcomingSchedule, let nextCopy {
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
                        HStack {
                            Spacer(minLength: 0)
                            action
                        }
                    } else if let nextCopy {
                        HStack {
                            Spacer(minLength: 0)
                            WidgetRepeatingNextOccurrenceView(
                                copy: nextCopy,
                                textColor: canvasForeground,
                                captionSize: nextCaptionSize,
                                timeSize: nextTimeSize
                            )
                        }
                    }
                }
                .padding(WidgetLayout.margin)

                if isCompleted {
                    Button {
                        petTapAt = Date()
                        localPetMotion = .tap
                    } label: {
                        WidgetPetSprite(
                            pet: pet,
                            color: canvasForeground,
                            height: petHeight,
                            motion: displayedPetMotion
                        )
                    }
                    .buttonStyle(WidgetPetTapStyle())
                    .padding(.top, petTop)
                    .padding(.trailing, petTrailing)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
                    .accessibilityLabel("\(pet.title). Tap to play.")
                }
            }
        }
        .clipped()
        .onChange(of: petTapAt) { _, tapAt in
            guard tapAt != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(WidgetPetMotion.tapDuration))
                if localPetMotion == .tap {
                    localPetMotion = .idle
                }
            }
        }
    }

    private var displayedPetMotion: WidgetPetMotion {
        if reduceMotion { return .still }
        return localPetMotion
    }

    private var titleCheckmarkSpacing: CGFloat {
        style == .large ? WidgetLayout.titleCheckmarkSpacingLarge : WidgetLayout.titleCheckmarkSpacing
    }

    private var titleLineLimit: Int {
        switch style {
        case .small, .medium: 3
        case .large: 4
        }
    }

    private var petHeight: CGFloat {
        style == .large ? WidgetLayout.petHeight * WidgetLayout.petScaleLarge : WidgetLayout.petHeight
    }

    private var petTop: CGFloat {
        switch style {
        case .small: WidgetLayout.petTopSmall
        case .medium: WidgetLayout.petTopMedium
        case .large: WidgetLayout.petTopLarge
        }
    }

    private var petTrailing: CGFloat {
        switch style {
        case .small: WidgetLayout.petTrailingSmall
        case .medium: WidgetLayout.petTrailingMedium
        case .large: WidgetLayout.petTrailingLarge
        }
    }

    private var nextCaptionSize: CGFloat {
        style == .large ? WidgetLayout.nextCaptionSizeLarge : WidgetLayout.nextCaptionSize
    }

    private var nextTimeSize: CGFloat {
        style == .large ? WidgetLayout.largeActionSize : WidgetLayout.smallActionSize
    }

    private var nextCopy: WidgetNextOccurrenceCopy? {
        guard let nextOccurrence else { return nil }
        if showsUpcomingSchedule {
            return WidgetNextOccurrenceCopy.make(
                repeatType: .never,
                nextOccurrence: nextOccurrence,
                hasScheduledDate: hasScheduledDate
            )
        }
        guard isCompleted else { return nil }
        return WidgetNextOccurrenceCopy.make(repeatType: repeatType, nextOccurrence: nextOccurrence)
    }

    @ViewBuilder
    private var action: some View {
        if showsInteractiveButton {
            Button {
                onComplete?()
            } label: {
                actionLabel
            }
            .buttonStyle(.plain)
        } else {
            actionLabel
        }
    }

    private var actionLabel: some View {
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

    private var circleCenter: CGPoint {
        switch style {
        case .small:
            return CGPoint(
                x: WidgetLayout.smallCircleLeft + circleSize / 2,
                y: WidgetLayout.smallCircleTop + circleSize / 2
            )
        case .medium:
            return CGPoint(
                x: WidgetLayout.mediumCircleLeft + circleSize / 2,
                y: WidgetLayout.smallCircleTop + circleSize / 2
            )
        case .large:
            return CGPoint(
                x: WidgetLayout.largeCircleLeft + circleSize / 2,
                y: WidgetLayout.largeCircleTop + circleSize / 2
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

struct WidgetRepeatingNextOccurrenceView: View {
    let copy: WidgetNextOccurrenceCopy
    let textColor: Color
    var captionSize: CGFloat = WidgetLayout.nextCaptionSize
    let timeSize: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(copy.dayLabel)
                .font(AppFont.sfProText(captionSize, weight: .medium))
                .foregroundStyle(textColor.opacity(WidgetLayout.nextCaptionOpacity))

            Text(copy.timeDigits)
                .font(AppFont.sfMono(timeSize, weight: .regular))
                .foregroundStyle(textColor)
                .frame(height: timeSize, alignment: .center)

            Text(copy.meridiem)
                .font(AppFont.sfProText(captionSize, weight: .medium))
                .foregroundStyle(textColor.opacity(WidgetLayout.nextCaptionOpacity))
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next reminder \(copy.dayLabel) \(copy.timeDigits) \(copy.meridiem)")
    }
}
