import SwiftData
import SwiftUI

struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Environment(PurchaseService.self) private var purchaseService

    let mode: ReminderEditorMode
    let onSave: () -> Void

    @State private var viewModel: ReminderEditorViewModel
    @State private var errorMessage: String?
    @State private var showingPaywall = false
    @State private var showingEmojiPicker = false

    init(mode: ReminderEditorMode, onSave: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        _viewModel = State(initialValue: ReminderEditorViewModel(mode: mode))
    }

    private var reminderService: ReminderService {
        ReminderService(
            modelContext: modelContext,
            notificationService: notificationService
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("What you want to be reminded of", text: titleBinding)
                        .font(.system(size: 17))
                        .foregroundStyle(AppColors.textPrimary)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(1)
                }

                if viewModel.hasEnteredTitle {
                    Section {
                        iconRow
                        if purchaseService.canUseReminderEmoji, !viewModel.iconEmoji.isEmpty {
                            Toggle(isOn: showOnWidgetBinding) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Show on widget")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("Hide the emoji. Color still follows it.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            .tint(AppColors.accent)
                        }
                    } header: {
                        Text("Icon")
                    } footer: {
                        Text(iconFooter)
                    }

                    Section("Repeat") {
                        Picker("Repeat", selection: $viewModel.repeatType) {
                            ForEach(RepeatType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .onChange(of: viewModel.repeatType) { _, newValue in
                            if newValue == .everyYear, !viewModel.hasScheduledDate {
                                viewModel.hasScheduledDate = true
                            }
                        }

                        if viewModel.repeatType == .custom {
                            Stepper(
                                "Every \(viewModel.repeatInterval) days",
                                value: $viewModel.repeatInterval,
                                in: 2...30
                            )

                            Text("Or select weekdays")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            WeekdaySelector(selectedWeekdays: $viewModel.selectedWeekdays) { weekday in
                                viewModel.toggleWeekday(weekday)
                            }
                        }
                    }

                    Section("Reminder Time") {
                        Toggle("Schedule a time", isOn: $viewModel.hasScheduledTime)

                        if viewModel.hasScheduledTime {
                            DatePicker(
                                "Time",
                                selection: $viewModel.scheduledTime,
                                displayedComponents: .hourAndMinute
                            )
                        }

                        Toggle("Schedule a date", isOn: $viewModel.hasScheduledDate)

                        if viewModel.hasScheduledDate {
                            DatePicker(
                                "Date",
                                selection: $viewModel.scheduledDate,
                                displayedComponents: .date
                            )
                        }
                    }

                    Section {
                        TextField("DONE YET?", text: $viewModel.completionButtonText)
                            .textInputAutocapitalization(.characters)
                    } header: {
                        Text("Completion")
                    } footer: {
                        Text("Shown on the widget.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.pageBackground)
            .animation(.easeInOut(duration: 0.22), value: viewModel.hasEnteredTitle)
            .onAppear {
                viewModel.updateSuggestedIcon(enabled: purchaseService.canUseReminderEmoji)
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerSheet(current: viewModel.iconEmoji) { emoji in
                    viewModel.setIconEmoji(emoji)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(
                    purchaseService: purchaseService,
                    headline: "Reminder icons",
                    message: "Add an emoji to a reminder. The widget can use its color."
                )
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private var iconRow: some View {
        Button {
            if purchaseService.canUseReminderEmoji {
                showingEmojiPicker = true
            } else {
                showingPaywall = true
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.hover)
                        .frame(width: 52, height: 52)

                    if viewModel.iconEmoji.isEmpty {
                        Image(systemName: "face.smiling")
                            .font(.title3)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text(viewModel.iconEmoji)
                            .font(.system(size: 28))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.iconEmoji.isEmpty ? "Choose emoji" : (viewModel.iconIsSuggested ? "Suggested" : "Change emoji"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(iconSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reminder icon")
    }

    private var showOnWidgetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showsIconOnWidget },
            set: { viewModel.showsIconOnWidget = $0 }
        )
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.title },
            set: { newValue in
                let singleLine = newValue
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                viewModel.title = String(singleLine.prefix(ReminderEditorViewModel.titleLimit))
                viewModel.updateSuggestedIcon(enabled: purchaseService.canUseReminderEmoji)
            }
        )
    }

    private var iconSubtitle: String {
        if viewModel.iconEmoji.isEmpty {
            return "Shown on the widget"
        }
        if viewModel.iconIsSuggested {
            return "From the title · \(viewModel.iconEmoji)"
        }
        return viewModel.iconEmoji
    }

    private var iconFooter: String {
        if !purchaseService.canUseReminderEmoji {
            return "Icons are included with Pro."
        }
        if viewModel.iconEmoji.isEmpty {
            return "The icon updates as you type."
        }
        if viewModel.showsIconOnWidget {
            return "Shown on the widget. Automatic color uses it too."
        }
        return "Hidden on the widget. Automatic color still uses it."
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func save() {
        do {
            try viewModel.save(using: reminderService)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WeekdaySelector: View {
    @Binding var selectedWeekdays: Set<Int>
    let onToggle: (Int) -> Void

    private let weekdays: [(Int, String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack {
            ForEach(weekdays, id: \.0) { weekday, label in
                let isSelected = selectedWeekdays.contains(weekday)

                Button {
                    onToggle(weekday)
                } label: {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? AppColors.textPrimary : AppColors.hover, in: Circle())
                        .foregroundStyle(isSelected ? AppColors.pageBackground : AppColors.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

#Preview("Add") {
    ReminderEditorView(mode: .add) {}
        .modelContainer(AppSchema.modelContainer)
        .environment(NotificationService())
        .environment(PurchaseService())
}
