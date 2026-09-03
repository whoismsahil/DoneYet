import Foundation

enum RepeatType: String, Codable, CaseIterable, Identifiable {
    case never
    case everyDay
    case everyWeek
    case everyMonth
    case everyYear
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .never: "Never"
        case .everyDay: "Daily"
        case .everyWeek: "Weekly"
        case .everyMonth: "Monthly"
        case .everyYear: "Yearly"
        case .custom: "Custom"
        }
    }

    var isRepeating: Bool {
        self != .never
    }
}

enum ReminderListFilter: String, CaseIterable, Identifiable {
    case all
    case never
    case daily
    case weekly
    case monthly
    case yearly
    case custom
    case paused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .never: "Not repeating"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        case .paused: "Paused"
        }
    }

    var matchingRepeatType: RepeatType? {
        switch self {
        case .never: .never
        case .daily: .everyDay
        case .weekly: .everyWeek
        case .monthly: .everyMonth
        case .yearly: .everyYear
        case .custom: .custom
        case .all, .paused: nil
        }
    }

    func matchesType(_ type: RepeatType) -> Bool {
        switch self {
        case .all, .paused: true
        case .never: type == .never
        case .daily: type == .everyDay
        case .weekly: type == .everyWeek
        case .monthly: type == .everyMonth
        case .yearly: type == .everyYear
        case .custom: type == .custom
        }
    }
}
