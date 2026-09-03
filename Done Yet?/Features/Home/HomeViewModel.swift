import SwiftUI

@Observable
@MainActor
final class HomeViewModel {
    private(set) var reminders: [Reminder] = []
    private(set) var pausedReminders: [Reminder] = []
    private(set) var errorMessage: String?
    var filter: ReminderListFilter = .all

    var filteredActiveReminders: [Reminder] {
        guard filter != .paused else { return [] }
        return reminders.filter { filter.matchesType($0.repeatType) }
    }

    var filteredPausedReminders: [Reminder] {
        switch filter {
        case .all, .paused:
            return pausedReminders
        default:
            return pausedReminders.filter { filter.matchesType($0.repeatType) }
        }
    }

    var hasAnyReminders: Bool {
        !reminders.isEmpty || !pausedReminders.isEmpty
    }

    var hasVisibleReminders: Bool {
        !filteredActiveReminders.isEmpty || !filteredPausedReminders.isEmpty
    }

    var availableFilters: [ReminderListFilter] {
        guard hasAnyReminders else { return [] }

        let types = Set((reminders + pausedReminders).map(\.repeatType))
        var filters: [ReminderListFilter] = [.all]

        for filter in ReminderListFilter.allCases {
            guard let type = filter.matchingRepeatType, types.contains(type) else { continue }
            filters.append(filter)
        }

        if !pausedReminders.isEmpty {
            filters.append(.paused)
        }

        return filters
    }

    func loadReminders(using service: ReminderService) {
        do {
            reminders = try service.fetchActiveReminders()
            pausedReminders = try service.fetchPausedReminders()
            errorMessage = nil
            if !availableFilters.contains(filter) {
                filter = .all
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ reminder: Reminder, using service: ReminderService) {
        let id = reminder.id
        reminders.removeAll { $0.id == id }
        pausedReminders.removeAll { $0.id == id }

        do {
            try service.deleteReminder(id: id)
            loadReminders(using: service)
        } catch {
            errorMessage = error.localizedDescription
            loadReminders(using: service)
        }
    }

    func pause(_ reminder: Reminder, using service: ReminderService) {
        do {
            try service.pause(reminder)
            loadReminders(using: service)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resume(_ reminder: Reminder, using service: ReminderService) {
        do {
            try service.resume(reminder)
            loadReminders(using: service)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete(_ reminder: Reminder, using service: ReminderService) {
        do {
            try service.complete(reminder)
            loadReminders(using: service)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
