import SwiftUI

enum AppTab: Hashable {
    case reminders
    case history
    case settings
}

enum AppSheet: Identifiable {
    case widgetColor
    case pets
    case appIcon
    case paywall

    var id: String {
        switch self {
        case .widgetColor: "widgetColor"
        case .pets: "pets"
        case .appIcon: "appIcon"
        case .paywall: "paywall"
        }
    }
}

@Observable
@MainActor
final class AppNavigation {
    var selectedTab: AppTab = .reminders
    var isSearchPresented = false
    var editorMode: ReminderEditorMode?
    var sheet: AppSheet?

    func openSearch() {
        isSearchPresented = true
    }

    func open(_ tab: AppTab) {
        selectedTab = tab
        isSearchPresented = false
    }

    func openNewReminder() {
        selectedTab = .reminders
        presentEditor(.add)
    }

    func openReminder(_ reminder: Reminder) {
        selectedTab = .reminders
        presentEditor(.edit(reminder))
    }

    func openSheet(_ sheet: AppSheet) {
        if sheet != .paywall {
            selectedTab = .settings
        }
        presentAfterSearch { self.sheet = sheet }
    }

    private func presentEditor(_ mode: ReminderEditorMode) {
        presentAfterSearch { self.editorMode = mode }
    }

    private func presentAfterSearch(_ action: @escaping () -> Void) {
        if isSearchPresented {
            isSearchPresented = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(320))
                action()
            }
        } else {
            action()
        }
    }
}
