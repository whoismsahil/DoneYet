import Foundation
import StoreKit
import SwiftUI
import UIKit

enum ProProductID {
    static let monthly = "done_yet_pro_monthly"
    static let yearly = "done_yet_pro_yearly"
    static let lifetime = "done_yet_pro_lifetime"

    static let all: [String] = [monthly, yearly, lifetime]
}

enum ProLimits {
    static let freeReminderLimit = 10
    static let freeWidgetLimit = 3
    static let freeIconLimit = 2
    static let proIconCount = 7

    /// When false, Pro limits and locks are shown but not enforced (staging).
    static let enforceLimits = false
}

enum ProPlan: String, CaseIterable, Identifiable {
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly: ProProductID.monthly
        case .yearly: ProProductID.yearly
        case .lifetime: ProProductID.lifetime
        }
    }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var membershipTitle: String {
        switch self {
        case .monthly: "Pro Monthly"
        case .yearly: "Pro Yearly"
        case .lifetime: "Pro Lifetime"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: "Cancel anytime"
        case .yearly: "Billed yearly"
        case .lifetime: "Pay once"
        }
    }

    var displayPrice: String {
        switch self {
        case .monthly: "$4.99"
        case .yearly: "$12.99"
        case .lifetime: "$29.99"
        }
    }

    var periodLabel: String {
        switch self {
        case .monthly: "/ month"
        case .yearly: "/ year"
        case .lifetime: "one-time"
        }
    }

    var isSubscription: Bool {
        self != .lifetime
    }

    static func from(productID: String) -> ProPlan? {
        allCases.first { $0.productID == productID }
    }
}

@Observable
@MainActor
final class PurchaseService {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var activePlan: ProPlan?
    private(set) var expirationDate: Date?
    private(set) var willAutoRenew = false
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

    /// True only when StoreKit reports a real entitlement.
    var hasPurchasedPro: Bool { activePlan != nil }

    /// Development unlock: Pro features stay available until StoreKit is wired and enforceLimits is on.
    var isPro: Bool {
        if !ProLimits.enforceLimits { return true }
        return hasPurchasedPro
    }

    var membershipStatusText: String {
        guard let plan = activePlan else { return "Not subscribed" }
        if plan == .lifetime { return "Lifetime access" }
        if let expirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            if willAutoRenew {
                return "Renews \(formatter.string(from: expirationDate))"
            }
            return "Expires \(formatter.string(from: expirationDate))"
        }
        return plan.membershipTitle
    }

    var settingsStatusText: String {
        if let plan = activePlan {
            return plan.title
        }
        if !ProLimits.enforceLimits {
            return "Staging"
        }
        return "Free"
    }

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: ProProductID.all)
            await updatePurchased()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func price(for plan: ProPlan) -> String {
        if let product = products.first(where: { $0.id == plan.productID }) {
            return product.displayPrice
        }
        return plan.displayPrice
    }

    func purchase(_ plan: ProPlan) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let product = products.first(where: { $0.id == plan.productID }) else {
                lastErrorMessage = "Products are not available yet."
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchased()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchased()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Opens Apple’s subscription management UI (cancel, pause, change plan).
    func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            openSubscriptionsURL()
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            openSubscriptionsURL()
        }
    }

    func canCreateReminder(currentCount: Int) -> Bool {
        isPro || currentCount < ProLimits.freeReminderLimit
    }

    func canUsePremiumTheme(_ theme: WidgetTheme) -> Bool {
        isPro || !theme.isPremium
    }

    func canUsePremiumPet(_ pet: WidgetPet) -> Bool {
        isPro || !pet.isPremium
    }

    var canUseReminderEmoji: Bool {
        !ProLimits.enforceLimits || isPro
    }

    private func openSubscriptionsURL() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    private func updatePurchased() async {
        var purchased: Set<String> = []
        var latestPlan: ProPlan?
        var latestExpiration: Date?
        var latestPurchaseDate = Date.distantPast

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            purchased.insert(transaction.productID)

            guard let plan = ProPlan.from(productID: transaction.productID) else { continue }
            if transaction.purchaseDate >= latestPurchaseDate {
                latestPurchaseDate = transaction.purchaseDate
                latestPlan = plan
                latestExpiration = transaction.expirationDate
            }
        }

        purchasedProductIDs = purchased
        activePlan = latestPlan
        expirationDate = latestExpiration
        willAutoRenew = false

        if let plan = latestPlan, plan.isSubscription,
           let product = products.first(where: { $0.id == plan.productID }),
           let statuses = try? await product.subscription?.status {
            for status in statuses {
                guard case .verified(let renewal) = status.renewalInfo else { continue }
                willAutoRenew = renewal.willAutoRenew
                break
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
