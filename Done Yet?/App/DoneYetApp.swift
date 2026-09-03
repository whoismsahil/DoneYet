import SwiftData
import SwiftUI

@main
struct DoneYetApp: App {
    init() {
        AppFont.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(AppSchema.modelContainer)
    }
}

private struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var notificationService = NotificationService()
    @State private var appearanceManager = AppearanceManager()
    @State private var widgetThemeManager = WidgetThemeManager()
    @State private var purchaseService = PurchaseService()
    @State private var navigation = AppNavigation()
    @State private var toast = AppToastBanner()

    var body: some View {
        @Bindable var navigation = navigation
        RootView()
            .environment(notificationService)
            .environment(appearanceManager)
            .environment(widgetThemeManager)
            .environment(purchaseService)
            .environment(navigation)
            .environment(toast)
            .preferredColorScheme(appearanceManager.colorScheme)
            .sheet(isPresented: $navigation.isSearchPresented) {
                GlobalSearchView()
                    .environment(navigation)
                    .environment(purchaseService)
                    .environment(notificationService)
                    .environment(\.modelContext, modelContext)
            }
            .sheet(item: $navigation.editorMode) { mode in
                ReminderEditorView(mode: mode) {
                    toast.show("Saved")
                }
                    .environment(purchaseService)
                    .environment(notificationService)
                    .environment(\.modelContext, modelContext)
            }
            .sheet(item: $navigation.sheet) { sheet in
                switch sheet {
                case .widgetColor:
                    WidgetCustomizationSheet(themeManager: widgetThemeManager, section: .color)
                        .environment(purchaseService)
                case .pets:
                    WidgetCustomizationSheet(themeManager: widgetThemeManager, section: .pets)
                        .environment(purchaseService)
                case .appIcon:
                    AppIconSelectionSheet()
                        .environment(purchaseService)
                case .paywall:
                    ProPaywallView(purchaseService: purchaseService)
                }
            }
            .task {
                ReminderChangeNotifier.startObserving()
                await syncWidgetStore()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await syncWidgetStore()
                }
            }
    }

    @MainActor
    private func syncWidgetStore() async {
        let context = AppSchema.modelContainer.mainContext
        let service = ReminderService(
            modelContext: context,
            notificationService: notificationService
        )
        try? service.syncWidgetStore()
        service.rescheduleNotifications()
    }
}
