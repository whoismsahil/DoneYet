import SwiftUI

struct SettingsView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(WidgetThemeManager.self) private var widgetThemeManager
    @Environment(PurchaseService.self) private var purchaseService
    @Environment(AppNavigation.self) private var navigation

    private var widgetColorName: String {
        widgetThemeManager.usesEmojiColor ? "Automatic" : widgetThemeManager.selection.title
    }

    private var widgetColorSwatch: Color {
        widgetThemeManager.usesEmojiColor
            ? Color(hex: 0xF3C4D4)
            : widgetThemeManager.selection.background
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        NotionLeadingIcon(systemName: "bell")
                        Text("Notifications")
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        NotionValueLabel(text: notificationStatusText)
                    }

                    if notificationService.authorizationStatus == .notDetermined {
                        Button {
                            Task { await notificationService.requestPermission() }
                        } label: {
                            Text("Turn on notifications")
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        NotionLeadingIcon(systemName: "circle.lefthalf.filled")
                        Picker("Appearance", selection: Bindable(appearanceManager).selection) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.title).tag(appearance)
                            }
                        }
                    }
                } header: {
                    Text("Preferences")
                }

                Section {
                    Button {
                        navigation.sheet = .widgetColor
                    } label: {
                        HStack(spacing: 12) {
                            NotionLeadingIcon(systemName: "paintpalette")
                            Text("Widget color")
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Circle()
                                .fill(widgetColorSwatch)
                                .frame(width: 16, height: 16)
                                .overlay {
                                    Circle().strokeBorder(AppColors.divider, lineWidth: 1)
                                }
                            NotionValueLabel(text: widgetColorName)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }

                    Button {
                        navigation.sheet = .pets
                    } label: {
                        HStack(spacing: 12) {
                            NotionLeadingIcon(systemName: "pawprint")
                            Text("Pet")
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            WidgetPetSprite(
                                pet: widgetThemeManager.pet,
                                color: AppColors.textSecondary,
                                height: 18
                            )
                            NotionValueLabel(text: widgetThemeManager.pet.title)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }

                    Button {
                        navigation.sheet = .appIcon
                    } label: {
                        HStack(spacing: 12) {
                            NotionLeadingIcon(systemName: "app")
                            Text("App icon")
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            NotionValueLabel(text: "Default")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }
                } header: {
                    Text("Home Screen")
                } footer: {
                    Text("Automatic sets the widget color from each reminder’s emoji. Fish and Bird are free.")
                }

                Section {
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack(spacing: 12) {
                            NotionLeadingIcon(systemName: "hand.raised")
                            Text("Privacy")
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack(spacing: 12) {
                            NotionLeadingIcon(systemName: "doc.text")
                            Text("Terms")
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }
                    HStack(spacing: 12) {
                        NotionLeadingIcon(systemName: "info.circle")
                        Text("Version")
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        NotionValueLabel(text: appVersion)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Button {
                        navigation.sheet = .paywall
                    } label: {
                        HStack(spacing: 12) {
                            NotionLeadingIcon(systemName: "sparkle")
                            Text("Done Yet? Pro")
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            NotionValueLabel(text: purchaseService.settingsStatusText)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigation.openSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
            }
            .toolbarBackground(AppColors.pageBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(AppColors.pageBackground)
            .tint(AppColors.accent)
        }
    }

    private var notificationStatusText: String {
        switch notificationService.authorizationStatus {
        case .authorized:
            return "On"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Not set"
        case .provisional, .ephemeral:
            return "Limited"
        @unknown default:
            return "Unknown"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
