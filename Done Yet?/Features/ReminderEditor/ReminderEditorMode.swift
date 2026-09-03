import Foundation
import SwiftUI

enum ReminderEditorMode: Identifiable {
    case add
    case edit(Reminder)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let reminder):
            return reminder.id.uuidString
        }
    }

    var navigationTitle: String {
        switch self {
        case .add:
            return "Add Reminder"
        case .edit:
            return "Edit Reminder"
        }
    }
}
