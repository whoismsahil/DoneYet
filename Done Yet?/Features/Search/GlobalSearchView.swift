import SwiftData
import SwiftUI

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Environment(PurchaseService.self) private var purchaseService

    @Query(sort: \Reminder.updatedAt, order: .reverse) private var reminders: [Reminder]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var history: [CompletionRecord]

    @State private var query = ""
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label("No results", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try a reminder, History, or Settings.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.hits) { hit in
                                Button {
                                    select(hit)
                                } label: {
                                    searchRow(hit)
                                }
                                .listRowBackground(AppColors.cardBackground)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.pageBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .toolbarBackground(AppColors.pageBackground, for: .navigationBar)
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(
                    purchaseService: purchaseService,
                    message: "The free plan includes \(ProLimits.freeReminderLimit) reminders."
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var liveReminders: [Reminder] {
        reminders.filter { $0.isActive || $0.repeats }
    }

    private var sections: [SearchSection] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinations = SearchDestination.allCases.filter { $0.matches(needle) }
        let reminderHits: [Reminder] = {
            if needle.isEmpty {
                return Array(liveReminders.prefix(6))
            }
            return Array(liveReminders.filter { matches($0.title, needle: needle) }.prefix(20))
        }()
        let historyHits = needle.isEmpty
            ? []
            : Array(history.filter { matches($0.storedTitle, needle: needle) }.prefix(12))

        var result: [SearchSection] = []
        if !reminderHits.isEmpty {
            result.append(SearchSection(
                id: "reminders",
                title: needle.isEmpty ? "Recents" : "Reminders",
                hits: reminderHits.map { .reminder($0.id) }
            ))
        }
        if !destinations.isEmpty {
            result.append(SearchSection(
                id: "go",
                title: "Places",
                hits: destinations.map { .destination($0) }
            ))
        }
        if !historyHits.isEmpty {
            result.append(SearchSection(
                id: "history",
                title: "History",
                hits: historyHits.map { .history($0.id) }
            ))
        }
        return result
    }

    @ViewBuilder
    private func searchRow(_ hit: SearchHit) -> some View {
        switch hit {
        case .destination(let destination):
            HStack(spacing: 12) {
                NotionLeadingIcon(systemName: destination.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(destination.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
        case .reminder(let id):
            if let reminder = liveReminders.first(where: { $0.id == id }) {
                HStack(spacing: 12) {
                    emojiOrPlaceholder(reminder.iconEmoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(reminder.isActive ? reminder.metadataLine : "Paused · \(reminder.metadataLine)")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
        case .history(let id):
            if let record = history.first(where: { $0.id == id }) {
                HStack(spacing: 12) {
                    emojiOrPlaceholder(record.iconEmoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.storedTitle.isEmpty ? "Reminder" : record.storedTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text("History")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func emojiOrPlaceholder(_ raw: String) -> some View {
        Group {
            if let emoji = ReminderEmojiStyle.normalized(raw) {
                Text(emoji)
                    .font(.system(size: 18))
                    .frame(width: 26, height: 26)
            } else {
                NotionLeadingIcon(systemName: "checkmark")
            }
        }
    }

    private func select(_ hit: SearchHit) {
        switch hit {
        case .destination(let destination):
            switch destination {
            case .newReminder:
                let activeCount = liveReminders.filter(\.isActive).count
                if purchaseService.canCreateReminder(currentCount: activeCount) {
                    navigation.openNewReminder()
                } else {
                    showingPaywall = true
                }
            case .reminders:
                navigation.open(.reminders)
            case .history:
                navigation.open(.history)
            case .settings:
                navigation.open(.settings)
            case .widgetColor:
                navigation.openSheet(.widgetColor)
            case .pet:
                navigation.openSheet(.pets)
            case .pro:
                navigation.openSheet(.paywall)
            }
        case .reminder(let id):
            guard let reminder = liveReminders.first(where: { $0.id == id }) else { return }
            navigation.openReminder(reminder)
        case .history:
            navigation.open(.history)
        }
    }

    private func matches(_ text: String, needle: String) -> Bool {
        let trimmed = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let haystack = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(separator: " ")
            .allSatisfy { haystack.contains($0) }
    }
}

private struct SearchSection: Identifiable {
    let id: String
    let title: String
    let hits: [SearchHit]
}

private enum SearchHit: Identifiable {
    case destination(SearchDestination)
    case reminder(UUID)
    case history(UUID)

    var id: String {
        switch self {
        case .destination(let destination): "dest-\(destination.rawValue)"
        case .reminder(let id): "reminder-\(id.uuidString)"
        case .history(let id): "history-\(id.uuidString)"
        }
    }
}

private enum SearchDestination: String, CaseIterable {
    case newReminder
    case reminders
    case history
    case settings
    case widgetColor
    case pet
    case pro

    var title: String {
        switch self {
        case .newReminder: "New reminder"
        case .reminders: "Reminders"
        case .history: "History"
        case .settings: "Settings"
        case .widgetColor: "Widget color"
        case .pet: "Pet"
        case .pro: "Done Yet? Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .newReminder: "Add a reminder"
        case .reminders: "Open Reminders"
        case .history: "Open History"
        case .settings: "Open Settings"
        case .widgetColor: "Widget color"
        case .pet: "Widget pet"
        case .pro: "Pro"
        }
    }

    var systemImage: String {
        switch self {
        case .newReminder: "plus"
        case .reminders: "list.bullet"
        case .history: "clock"
        case .settings: "slider.horizontal.3"
        case .widgetColor: "paintpalette"
        case .pet: "pawprint"
        case .pro: "sparkle"
        }
    }

    var keywords: [String] {
        switch self {
        case .newReminder: ["new", "add", "create", "reminder"]
        case .reminders: ["reminders", "home", "list"]
        case .history: ["history", "completed", "done"]
        case .settings: ["settings", "preferences"]
        case .widgetColor: ["widget", "color", "theme", "automatic"]
        case .pet: ["pet", "pets", "animal"]
        case .pro: ["pro", "upgrade", "subscription", "paywall"]
        }
    }

    func matches(_ needle: String) -> Bool {
        let trimmed = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let folded = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if title.localizedCaseInsensitiveContains(folded) { return true }
        return keywords.contains { $0.localizedCaseInsensitiveContains(folded) || folded.contains($0) }
    }
}
