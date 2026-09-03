import AppIntents
import WidgetKit

struct PokeWidgetPetIntent: AppIntent {
    static var title: LocalizedStringResource = "Done Yet Widget Pet"
    static var description = IntentDescription("Play a short pet animation on the widget.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetPetStore.recordTap()
        }
        return .result()
    }
}
