import SwiftUI

struct NotionLeadingIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppColors.textSecondary)
            .frame(width: 26, height: 26)
            .background(AppColors.hover, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct NotionValueLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(AppColors.textSecondary)
            .lineLimit(1)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AppTypography.buttonLabel())
                .tracking(AppTextStyle.uppercaseTracking)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.buttonBackground)
                .foregroundStyle(AppColors.buttonForeground)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct WidgetPreviewCard: View {
    let title: String
    let buttonText: String
    var status: WidgetReminderStatus = .pending
    var completedDisplayText: String?
    var nextOccurrenceSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.widgetPreviewTitle())
                .tracking(AppTextStyle.headlineTracking)
                .foregroundStyle(AppColors.foreground)
                .multilineTextAlignment(.leading)

            if status == .pending {
                Text(buttonText.uppercased())
                    .font(AppTypography.widgetPreviewButton())
                    .tracking(AppTextStyle.uppercaseTracking)
                    .foregroundStyle(AppColors.foreground)
            } else {
                Text(completedDisplayText ?? "\(buttonText) ✓")
                    .font(AppTypography.widgetPreviewButton())
                    .tracking(AppTextStyle.uppercaseTracking)
                    .foregroundStyle(AppColors.secondary)

                if let nextOccurrenceSummary {
                    Text("NEXT")
                        .font(AppTypography.pixelLabel())
                        .foregroundStyle(AppColors.tertiary)
                        .padding(.top, AppSpacing.xs)

                    Text(nextOccurrenceSummary.uppercased())
                        .font(AppTypography.metadata())
                        .foregroundStyle(AppColors.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .overlay {
            Rectangle()
                .stroke(AppColors.divider, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        switch status {
        case .pending:
            return "Widget preview: \(title), tap \(buttonText) when done"
        case .completed:
            let completed = completedDisplayText ?? "\(buttonText) ✓"
            if let nextOccurrenceSummary {
                return "Widget preview: \(title), completed \(completed), next \(nextOccurrenceSummary)"
            }
            return "Widget preview: \(title), completed \(completed)"
        }
    }
}

struct CompletionActionButton: View {
    let title: String
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AppTypography.widgetPreviewButton())
                .tracking(AppTextStyle.uppercaseTracking)
                .foregroundStyle(isCompleted ? AppColors.secondary : AppColors.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
        .accessibilityLabel(isCompleted ? "Completed: \(title)" : "Mark \(title) complete")
        .accessibilityAddTraits(isCompleted ? [] : .isButton)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTypography.metadata())
            .tracking(AppTextStyle.uppercaseTracking)
            .foregroundStyle(AppColors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditorialDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 1)
    }
}

struct PixelGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 6
            let dotSize: CGFloat = 1

            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(rect), with: .color(AppColors.pixel))
                }
            }
        }
        .opacity(0.35)
        .allowsHitTesting(false)
    }
}
