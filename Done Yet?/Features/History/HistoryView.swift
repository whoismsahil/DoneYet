import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Environment(AppNavigation.self) private var navigation
    @Environment(AppToastBanner.self) private var toast
    @State private var viewModel = HistoryViewModel()
    @State private var confirmingDeleteSelected = false
    @State private var pendingDelete: HistoryViewModel.Item?

    private var reminderService: ReminderService {
        ReminderService(
            modelContext: modelContext,
            notificationService: notificationService
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasItems {
                    ContentUnavailableView {
                        Label("No history", systemImage: "clock")
                    } description: {
                        Text("Completed reminders show up here.")
                    }
                } else {
                    List {
                        ForEach(viewModel.sections) { section in
                            Section(section.title) {
                                ForEach(section.items) { item in
                                    historyRow(item)
                                        .listRowBackground(AppColors.cardBackground)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if !viewModel.isSelecting {
                                                Button {
                                                    pendingDelete = item
                                                } label: {
                                                    Label("Delete", systemImage: "trash.fill")
                                                }
                                                .tint(.red)

                                                Button {
                                                    addAgain(item)
                                                } label: {
                                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                                }
                                                .tint(.blue)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.pageBackground)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.pageBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isSelecting {
                        Button("Select All") {
                            viewModel.selectAll()
                        }
                        .disabled(viewModel.selectedCount == viewModel.itemCount)
                    } else {
                        Button {
                            navigation.openSearch()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("Search")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.hasItems {
                        if viewModel.isSelecting {
                            Button("Cancel") {
                                viewModel.clearSelection()
                            }
                        } else {
                            Button("Select") {
                                viewModel.isSelecting = true
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isSelecting, viewModel.hasItems {
                    Button("Delete Forever (\(viewModel.selectedCount))") {
                        confirmingDeleteSelected = true
                    }
                    .disabled(viewModel.selectedCount == 0)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.bar)
                }
            }
            .alert(
                "Delete this reminder?",
                isPresented: pendingDeleteBinding,
                presenting: pendingDelete
            ) { item in
                Button("Yes", role: .destructive) {
                    viewModel.delete(id: item.id, modelContext: modelContext)
                    pendingDelete = nil
                    toast.show("Deleted")
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: { item in
                Text("“\(item.title)” will be permanently deleted.")
            }
            .alert(
                "Delete these reminders?",
                isPresented: $confirmingDeleteSelected
            ) {
                Button("Yes", role: .destructive) {
                    viewModel.deleteSelected(modelContext: modelContext)
                    toast.show("Deleted")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = viewModel.selectedCount
                Text(count == 1
                     ? "This reminder will be permanently deleted."
                     : "\(count) reminders will be permanently deleted.")
            }
            .onAppear {
                viewModel.load(modelContext: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: ReminderChangeNotifier.localName)) { _ in
                viewModel.load(modelContext: modelContext)
            }
        }
    }

    private var pendingDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private func historyRow(_ item: HistoryViewModel.Item) -> some View {
        HStack(spacing: 12) {
            if viewModel.isSelecting {
                Image(systemName: viewModel.isSelected(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.isSelected(item.id) ? Color.accentColor : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let emoji = ReminderEmojiStyle.normalized(item.iconEmoji) {
                        Text(emoji)
                            .font(.system(size: 18))
                            .frame(width: 24, height: 24)
                    } else {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(AppColors.hover)
                            .frame(width: 24, height: 24)
                    }
                    Text(item.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Text(item.repeatType.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                Text(item.time)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isSelecting {
                viewModel.toggleSelection(item.id)
            }
        }
    }

    private func addAgain(_ item: HistoryViewModel.Item) {
        do {
            try reminderService.addAgain(
                reminderID: item.reminderID,
                title: item.title,
                completionButtonText: item.completionText,
                repeatType: item.repeatType,
                repeatInterval: item.repeatInterval,
                weekdays: item.weekdays,
                reminderHour: item.reminderHour,
                reminderMinute: item.reminderMinute,
                scheduledDate: item.scheduledDate,
                completionRecordID: item.id,
                iconEmoji: item.iconEmoji,
                showsIconOnWidget: item.showsIconOnWidget
            )
            viewModel.load(modelContext: modelContext)
            toast.show("Restored")
        } catch {
            // Keep history usable even if a single restore fails.
        }
    }
}
