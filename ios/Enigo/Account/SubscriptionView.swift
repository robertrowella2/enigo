import StoreKit
import SwiftUI

/// Subscription — active-plan card, manage in store, restore purchases,
/// cancel. Cancelling keeps existing connections until they end naturally.
struct SubscriptionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openDashboard() }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: "Subscription")

            if let status = appState.subscriptionStatus, status.isPro {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Current plan")
                    Text("Enigo Pro").font(EnigoFont.fraunces(size: 20, weight: 600))
                    Text("Manage or cancel any time in the App Store. Cancelling keeps existing connections until they end naturally — nothing is cut off mid-conversation.")
                        .font(EnigoFont.body)
                        .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.card).fill(EnigoColor.fgAlpha(scheme, 0.05)))

                Button("Manage in App Store") {
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(EnigoFont.chipLabel)
                .foregroundStyle(EnigoColor.accent(scheme))
            } else {
                Text("You're on the free plan.")
                    .font(EnigoFont.body)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
                PrimaryButton(title: "See Pro") { appState.openPaywall() }
            }

            SecondaryLink(title: "Restore purchases") {
                Task { await restorePurchases() }
            }
        }
        .task { await appState.loadSubscriptionStatus() }
    }

    /// Re-checks StoreKit's own entitlement records (not just our backend's
    /// copy) and re-reports an active Pro entitlement if found — covers a
    /// reinstall or a new device.
    private func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.productID == StoreProductID.proMonthly else { continue }
            await appState.recordPurchase(
                productId: transaction.productID,
                transactionId: String(transaction.id),
                expiresAt: transaction.expirationDate
            )
            return
        }
        await appState.loadSubscriptionStatus()
    }
}
