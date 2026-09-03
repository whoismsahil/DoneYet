import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(AppToastBanner.self) private var toast

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Reminders", systemImage: "list.bullet")
                }
                .tag(AppTab.reminders)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(AppTab.history)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.settings)
        }
        .tint(AppColors.textPrimary)
        .overlay(alignment: .bottom) {
            if let message = toast.message {
                ProminentToastBar(message: message)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.38, bounce: 0.22), value: toast.message)
    }
}
