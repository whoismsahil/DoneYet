import SwiftUI

struct AppIconSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseService.self) private var purchaseService
    @State private var appIconManager = AppIconManager()
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose your App Icon")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(AppIconOption.allCases) { option in
                            let isSelected = appIconManager.currentIcon == option
                            Button {
                                if purchaseService.canUseReminderEmoji {
                                    appIconManager.select(option)
                                } else {
                                    showingPaywall = true
                                }
                            } label: {
                                VStack(spacing: 12) {
                                    AppIconPreview(option: option)
                                    .overlay(alignment: .topTrailing) {
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundStyle(AppColors.accent)
                                                .background(Circle().fill(Color.white))
                                                .offset(x: 6, y: -6)
                                        }
                                    }

                                    Text(option.title)
                                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(isSelected ? AppColors.hover : AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(AppColors.pageBackground)
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(
                    purchaseService: purchaseService,
                    headline: "App Icons",
                    message: "Customize your home screen with custom App Icons."
                )
            }
        }
    }
}

private struct AppIconPreview: View {
    let option: AppIconOption

    var body: some View {
        Image(imageName(for: option))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func imageName(for option: AppIconOption) -> String {
        switch option {
        case .defaultSage: return "AppIconSage"
        case .black: return "AppIconBlack"
        case .original: return "AppIconOriginal"
        }
    }
}

#Preview {
    AppIconSelectionSheet()
        .environment(PurchaseService())
}
