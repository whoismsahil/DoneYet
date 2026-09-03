import SwiftUI

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var purchaseService: PurchaseService
    var headline: String = "Done Yet? Pro"
    var message: String = "More reminders, widgets, colors, pets, and icons."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if purchaseService.hasPurchasedPro {
                        membershipContent
                    } else {
                        purchaseContent
                    }

                    if let error = purchaseService.lastErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(AppColors.pageBackground)
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.pageBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await purchaseService.refresh()
            }
        }
    }

    private var membershipContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your plan")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("You’re on Pro.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                labeledRow("Plan", purchaseService.activePlan?.membershipTitle ?? "Pro")
                labeledRow("Status", purchaseService.membershipStatusText)

                if let plan = purchaseService.activePlan, plan.isSubscription {
                    labeledRow(
                        "Billing",
                        purchaseService.willAutoRenew ? "Auto-renew on" : "Auto-renew off"
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.hover, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if purchaseService.activePlan?.isSubscription == true {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { await purchaseService.openManageSubscriptions() }
                    } label: {
                        Text("Manage Subscription")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.textPrimary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(AppColors.pageBackground)
                    }
                    .buttonStyle(.plain)

                    Text("Change or cancel this plan in Apple’s subscription settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("A lifetime purchase does not renew.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Restore Purchases") {
                Task { await purchaseService.restore() }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var purchaseContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                benefit("Unlimited reminders. Free includes \(ProLimits.freeReminderLimit).")
                benefit("Unlimited widgets. Free includes \(ProLimits.freeWidgetLimit).")
                benefit("Extra widget colors")
                benefit("Extra pets. Fish and Bird stay free.")
                benefit("Emoji icons on reminders")
                benefit("Additional app icons, coming later")
            }

            VStack(spacing: 12) {
                ForEach(ProPlan.allCases) { plan in
                    planButton(plan)
                }
            }

            Button("Restore Purchases") {
                Task { await purchaseService.restore() }
            }
            .frame(maxWidth: .infinity)

            if !ProLimits.enforceLimits {
                Text("Limits are off in this build.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func planButton(_ plan: ProPlan) -> some View {
        Button {
            Task { await purchaseService.purchase(plan) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.headline)
                    Text(plan.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(purchaseService.price(for: plan))
                        .font(.headline)
                    Text(plan.periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.hover, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchaseService.isLoading)
    }
}
