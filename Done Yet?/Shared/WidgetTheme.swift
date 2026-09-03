import SwiftUI
import WidgetKit

enum WidgetTheme: String, CaseIterable, Identifiable, Codable {
    case sage
    case willow
    case tide
    case blush
    case ember
    case lagoon
    case dusk
    case iris
    case coral
    case apricot
    case honey
    case lilac
    case mist
    case slate
    case cocoa
    case rose
    case moss

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sage: "Sage"
        case .willow: "Willow"
        case .tide: "Tide"
        case .blush: "Blush"
        case .ember: "Ember"
        case .lagoon: "Lagoon"
        case .dusk: "Dusk"
        case .iris: "Iris"
        case .coral: "Coral"
        case .apricot: "Apricot"
        case .honey: "Honey"
        case .lilac: "Lilac"
        case .mist: "Mist"
        case .slate: "Slate"
        case .cocoa: "Cocoa"
        case .rose: "Rose"
        case .moss: "Moss"
        }
    }

    var isPremium: Bool {
        switch self {
        case .sage, .willow, .tide, .blush, .ember:
            return false
        default:
            return true
        }
    }

    var backgroundHex: UInt32 {
        switch self {
        case .sage: 0xCFD4BB
        case .willow: 0xCFDE8D
        case .tide: 0xB7D7F0
        case .blush: 0xF3C4D4
        case .ember: 0xF5C89A
        case .lagoon: 0x9FD6D2
        case .dusk: 0xC5B8E8
        case .iris: 0xC9C4F0
        case .coral: 0xF2A8A0
        case .apricot: 0xF3C7A8
        case .honey: 0xEED889
        case .lilac: 0xE2C6E8
        case .mist: 0xD5DDE6
        case .slate: 0xB8C4CE
        case .cocoa: 0xD4B89A
        case .rose: 0xE8A8B8
        case .moss: 0xB7C98A
        }
    }

    var textHex: UInt32 {
        switch self {
        case .sage: 0x4F5A22
        case .willow: 0x7C9F5B
        case .tide: 0x2F5F8A
        case .blush: 0xA85A78
        case .ember: 0xC46A2D
        case .lagoon: 0x2F6F6C
        case .dusk: 0x5A4A8A
        case .iris: 0x4A48A0
        case .coral: 0xB04A42
        case .apricot: 0xB05A2C
        case .honey: 0x8A6A18
        case .lilac: 0x7A4A86
        case .mist: 0x4A5A6A
        case .slate: 0x3A4A58
        case .cocoa: 0x6A4A2C
        case .rose: 0x8A3A52
        case .moss: 0x4A6A32
        }
    }

    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }

    static var included: [WidgetTheme] { allCases.filter { !$0.isPremium } }
    static var premium: [WidgetTheme] { allCases.filter(\.isPremium) }
}

enum WidgetThemeStore {
    static let storageKey = "widget_theme"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.identifier)
    }

    static var current: WidgetTheme {
        guard let raw = defaults?.string(forKey: storageKey) else {
            return .sage
        }
        if raw == "green" || raw == "willow" { return .sage }
        return WidgetTheme(rawValue: raw) ?? .sage
    }

    static func set(_ theme: WidgetTheme) {
        defaults?.set(theme.rawValue, forKey: storageKey)
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var usesEmojiColor: Bool {
        guard let defaults else { return true }
        if defaults.object(forKey: AppGroupConstants.widgetUsesEmojiColorKey) == nil {
            return true
        }
        return defaults.bool(forKey: AppGroupConstants.widgetUsesEmojiColorKey)
    }

    static func setUsesEmojiColor(_ enabled: Bool) {
        defaults?.set(enabled, forKey: AppGroupConstants.widgetUsesEmojiColorKey)
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

@Observable
@MainActor
final class WidgetThemeManager {
    var selection: WidgetTheme {
        didSet {
            guard oldValue != selection else { return }
            WidgetThemeStore.set(selection)
        }
    }

    var pet: WidgetPet {
        didSet {
            guard oldValue != pet else { return }
            WidgetPetStore.set(pet)
        }
    }

    var usesEmojiColor: Bool {
        didSet {
            guard oldValue != usesEmojiColor else { return }
            WidgetThemeStore.setUsesEmojiColor(usesEmojiColor)
        }
    }

    init() {
        selection = WidgetThemeStore.current
        pet = WidgetPetStore.current
        usesEmojiColor = WidgetThemeStore.usesEmojiColor
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
