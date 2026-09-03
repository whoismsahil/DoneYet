import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NotificationService.self) private var notificationService
    @Environment(PurchaseService.self) private var purchaseService
    @Environment(AppNavigation.self) private var navigation
    @Environment(AppToastBanner.self) private var toast
    @State private var viewModel = HomeViewModel()
    @State private var showingPaywall = false
    @State private var pendingDelete: Reminder?

    private var reminderService: ReminderService {
        ReminderService(
            modelContext: modelContext,
            notificationService: notificationService
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasAnyReminders {
                    ContentUnavailableView {
                        Label("No reminders", systemImage: "list.bullet")
                    } description: {
                        Text("Add a reminder.")
                    }
                } else {
                    reminderList
                }
            }
            .background(AppColors.pageBackground)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.pageBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        navigation.openSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let activeCount = viewModel.reminders.count + viewModel.pausedReminders.count
                        if purchaseService.canCreateReminder(currentCount: activeCount) {
                            navigation.editorMode = .add
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Reminder")
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(
                    purchaseService: purchaseService,
                    message: "The free plan includes \(ProLimits.freeReminderLimit) reminders."
                )
            }
            .onAppear {
                ReminderChangeNotifier.startObserving()
                reloadReminders()
            }
            .onReceive(NotificationCenter.default.publisher(for: ReminderChangeNotifier.localName)) { _ in
                reloadReminders()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                reloadReminders()
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert(
                "Delete this reminder?",
                isPresented: pendingDeleteBinding,
                presenting: pendingDelete
            ) { reminder in
                Button("Delete", role: .destructive) {
                    confirmDelete(reminder)
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: { reminder in
                Text("Are you sure you want to delete “\(reminder.title)”? It will be moved to History.")
            }
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(viewModel.availableFilters) { filter in
                    let isSelected = viewModel.filter == filter
                    Button {
                        viewModel.filter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? AppColors.hover : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Filter reminders")
    }

    private var reminderList: some View {
        List {
            if !viewModel.availableFilters.isEmpty {
                Section {
                    filterTabs
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if !viewModel.hasVisibleReminders {
                ContentUnavailableView(
                    "No matching reminders",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Nothing in \(viewModel.filter.title.lowercased()).")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                if !viewModel.filteredActiveReminders.isEmpty {
                    Section {
                        ForEach(viewModel.filteredActiveReminders, id: \.id) { reminder in
                            reminderRow(reminder, isPaused: false)
                        }
                    }
                }

                if !viewModel.filteredPausedReminders.isEmpty {
                    Section("Paused") {
                        ForEach(viewModel.filteredPausedReminders, id: \.id) { reminder in
                            reminderRow(reminder, isPaused: true)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.pageBackground)
    }

    private func reminderRow(_ reminder: Reminder, isPaused: Bool) -> some View {
        ReminderRow(
            reminder: reminder,
            isPaused: isPaused,
            onEdit: { navigation.editorMode = .edit(reminder) },
            onComplete: (!isPaused && reminder.isPending()) ? { complete(reminder) } : nil
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                pendingDelete = reminder
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            .tint(.red)

            Button {
                navigation.editorMode = .edit(reminder)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

            if isPaused {
                Button {
                    viewModel.resume(reminder, using: reminderService)
                    toast.show("Resumed")
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .tint(.green)
            } else if reminder.repeats {
                Button {
                    viewModel.pause(reminder, using: reminderService)
                    toast.show("Paused")
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .tint(.orange)
            }
        }
        .contextMenu {
            Button("Edit") {
                navigation.editorMode = .edit(reminder)
            }
            if !isPaused, reminder.isPending() {
                Button("Mark Complete") {
                    complete(reminder)
                }
            }
            if isPaused {
                Button("Resume") {
                    viewModel.resume(reminder, using: reminderService)
                    toast.show("Resumed")
                }
            } else if reminder.repeats {
                Button("Pause") {
                    viewModel.pause(reminder, using: reminderService)
                    toast.show("Paused")
                }
            }
            Button("Delete", role: .destructive) {
                pendingDelete = reminder
            }
        }
    }

    private func complete(_ reminder: Reminder) {
        let repeats = reminder.repeats
        viewModel.complete(reminder, using: reminderService)

        if repeats {
            toast.show(reminder.repeatingCompletionToast())
        } else {
            toast.show("Moved to History")
        }
    }

    private func confirmDelete(_ reminder: Reminder) {
        viewModel.delete(reminder, using: reminderService)
        pendingDelete = nil
        toast.show("Deleted")
    }

    private var pendingDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }

    private func reloadReminders() {
        viewModel.loadReminders(using: reminderService)
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    var isPaused = false
    let onEdit: () -> Void
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let emoji = ReminderEmojiStyle.normalized(reminder.iconEmoji) {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 28, height: 28)
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppColors.hover)
                        .frame(width: 28, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(reminder.metadataLine)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)

                        if isPaused {
                            Text("Paused")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                        } else if reminder.repeats, !reminder.isPending(), let nextSummary = reminder.nextOccurrenceSummary() {
                            Text("Next \(nextSummary)")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let onComplete {
                    Button(action: onComplete) {
                        Text(reminder.completionButtonText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                    .accessibilityLabel(reminder.completionButtonText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .listRowBackground(AppColors.cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(reminder.title), \(reminder.metadataLine)")
    }
}

#Preview {
    HomeView()
        .modelContainer(AppSchema.modelContainer)
        .environment(NotificationService())
        .environment(PurchaseService())
        .environment(AppNavigation())
}
