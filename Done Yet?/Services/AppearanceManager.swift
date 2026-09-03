import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
@MainActor
final class AppearanceManager {
    private static let storageKey = "app_appearance"

    var selection: AppAppearance {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    var colorScheme: ColorScheme? {
        selection.colorScheme
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let stored = AppAppearance(rawValue: raw) {
            selection = stored
        } else {
            selection = .system
        }
    }
}
