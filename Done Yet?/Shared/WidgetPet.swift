import SwiftUI
import WidgetKit

enum WidgetPet: String, CaseIterable, Identifiable, Codable {
    case cat
    case dog
    case bird
    case seal
    case lion
    case wolf
    case fish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .bird: "Bird"
        case .seal: "Seal"
        case .lion: "Lion"
        case .wolf: "Wolf"
        case .fish: "Fish"
        }
    }

    var isPremium: Bool {
        switch self {
        case .fish, .bird: false
        case .cat, .dog, .seal, .lion, .wolf: true
        }
    }

    var assetName: String? {
        switch self {
        case .cat: "PetCat"
        case .dog: "PetDog"
        default: nil
        }
    }

    var outlinedSymbol: String? {
        switch self {
        case .bird: "bird"
        case .fish: "fish"
        default: nil
        }
    }

    var outlinedEmoji: String {
        switch self {
        case .cat: "🐱"
        case .dog: "🐶"
        case .bird: "🐦"
        case .seal: "🦭"
        case .lion: "🦁"
        case .wolf: "🐺"
        case .fish: "🐟"
        }
    }

    static var included: [WidgetPet] { allCases.filter { !$0.isPremium } }
    static var premium: [WidgetPet] { allCases.filter(\.isPremium) }
}

enum WidgetPetMotion: String, Equatable {
    case still
    case idle
    case tap

    static let tapDuration: TimeInterval = 2.8

    static func resolved(at date: Date, tapStartedAt: Date?) -> WidgetPetMotion {
        if let tapStartedAt {
            let elapsed = date.timeIntervalSince(tapStartedAt)
            if elapsed >= 0, elapsed < tapDuration {
                return .tap
            }
        }
        return .idle
    }
}

enum WidgetPetStore {
    static let storageKey = "widget_pet"
    static let tapAtKey = "widget_pet_tap_at"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.identifier)
    }

    static var current: WidgetPet {
        guard let raw = defaults?.string(forKey: storageKey) else {
            return .fish
        }
        return WidgetPet(rawValue: raw) ?? .fish
    }

    static var lastTapAt: Date? {
        defaults?.object(forKey: tapAtKey) as? Date
    }

    static func set(_ pet: WidgetPet) {
        defaults?.set(pet.rawValue, forKey: storageKey)
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func recordTap(at date: Date = .now) {
        defaults?.set(date, forKey: tapAtKey)
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum WidgetDisplayText {
    static func wrappingTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed.split(separator: " ", omittingEmptySubsequences: false).map { token in
            insertSoftHyphens(in: String(token))
        }.joined(separator: " ")
    }

    static func truncatedTitle(_ title: String, limit: Int) -> String {
        wrappingTitle(title)
    }

    private static func insertSoftHyphens(in word: String) -> String {
        let characters = Array(word)
        let letters = characters.filter(\.isLetter)
        guard letters.count > 5 else { return word }

        var result = ""
        var lettersSeen = 0
        for (index, character) in characters.enumerated() {
            if character.isLetter {
                if lettersSeen > 0, lettersSeen % 3 == 0, index < characters.count - 1 {
                    result.append("\u{00AD}")
                }
                lettersSeen += 1
            }
            result.append(character)
        }
        return result
    }
}

struct WidgetPetSprite: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pet: WidgetPet
    let color: Color
    var height: CGFloat = WidgetLayout.petHeight
    var motion: WidgetPetMotion = .idle

    var body: some View {
        Group {
            if reduceMotion || motion == .still {
                sprite
            } else {
                TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { context in
                    sprite.modifier(WidgetPetMotionModifier(motion: motion, date: context.date))
                }
            }
        }
        .accessibilityLabel(pet.title)
    }

    private var sprite: some View {
        Group {
            if let assetName = pet.assetName {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
            } else if let symbol = pet.outlinedSymbol {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
            } else {
                Text(pet.outlinedEmoji)
                    .font(.system(size: height * 0.72))
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(height: height)
    }
}

struct WidgetPetTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.3 : 1.0)
            .offset(y: configuration.isPressed ? -16 : 0)
            .animation(.spring(duration: 0.25, bounce: 0.65), value: configuration.isPressed)
    }
}

private struct WidgetPetMotionModifier: ViewModifier {
    let motion: WidgetPetMotion
    let date: Date

    func body(content: Content) -> some View {
        let time = date.timeIntervalSinceReferenceDate
        switch motion {
        case .still, .idle:
            content
        case .tap:
            let bounce = abs(sin(time * 12))
            content
                .scaleEffect(1 + 0.32 * bounce)
                .offset(y: -24 * bounce)
        }
    }
}
