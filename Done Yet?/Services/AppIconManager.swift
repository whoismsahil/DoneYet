import SwiftUI
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case defaultSage = "default"
    case black = "AppIconBlack"
    case original = "AppIconOriginal"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultSage: "Default (Sage)"
        case .black: "Dark / Black"
        case .original: "Classic Green"
        }
    }

    var backgroundHex: UInt32 {
        switch self {
        case .defaultSage: 0xCFD4BB
        case .black: 0x141414
        case .original: 0xCFDE8D
        }
    }

    var textHex: UInt32 {
        switch self {
        case .defaultSage: 0x4F5A22
        case .black: 0xCFD4BB
        case .original: 0x7C9F5B
        }
    }

    var iconName: String? {
        switch self {
        case .defaultSage: nil
        case .black: "AppIconBlack"
        case .original: "AppIconOriginal"
        }
    }

    static func from(iconName: String?) -> AppIconOption {
        guard let name = iconName else { return .defaultSage }
        return allCases.first { $0.iconName == name } ?? .defaultSage
    }
}

@Observable
@MainActor
final class AppIconManager {
    private static let storageKey = "selected_app_icon"

    var currentIcon: AppIconOption {
        didSet {
            apply(currentIcon)
        }
    }

    init() {
        if UIApplication.shared.supportsAlternateIcons {
            let activeName = UIApplication.shared.alternateIconName
            currentIcon = AppIconOption.from(iconName: activeName)
        } else {
            let stored = UserDefaults.standard.string(forKey: Self.storageKey)
            currentIcon = AppIconOption(rawValue: stored ?? "") ?? .defaultSage
        }
    }

    func select(_ option: AppIconOption) {
        currentIcon = option
    }

    private func apply(_ option: AppIconOption) {
        UserDefaults.standard.set(option.rawValue, forKey: Self.storageKey)

        guard UIApplication.shared.supportsAlternateIcons else { return }
        guard UIApplication.shared.alternateIconName != option.iconName else { return }

        UIApplication.shared.setAlternateIconName(option.iconName) { _ in }
    }
}
