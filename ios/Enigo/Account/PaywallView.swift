import StoreKit
import SwiftUI

/// Pro: three conversations at once, unlimited fresh starts,
/// shared-interest matching. Secondary: a one-time boost for one extra
/// rematch after the free tier's 3 declines. Real StoreKit 2 purchase flow —
/// see Products.storekit for local testing and README-ios-iap.md (below)
/// for what you need to configure in App Store Connect before this can
/// actually charge anyone.
enum StoreProductID {
    static let proMonthly = "com.enigo.pro.monthly"
    static let boost = "com.enigo.boost.rematch"
}

struct PaywallView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var products: [Product] = []
    @State private var loadError: String?

    /// The price comes from StoreKit, so the figure on screen is the one the
    /// user will actually be charged, in their own currency. It used to read
    /// a hardcoded "$8/month" while App Store Connect charged $5.99 in the US
    /// — and different amounts again in every other territory, so an
    /// Australian saw "$8" and would have been billed A$9.99. Stating a price
    /// that does not match what is charged is a Guideline 3.1.2 rejection.
    ///
    /// When StoreKit has not returned the product there is no price to state,
    /// so none is claimed — the subscription cannot be bought in that state
    /// anyway, and a stale number is worse than no number.
    private var proDescription: String {
        let features = "three conversations at once, unlimited fresh starts, and shared-interest matching."
        guard let price = products.first(where: { $0.id == StoreProductID.proMonthly })?.displayPrice else {
            return features.prefix(1).uppercased() + features.dropFirst()
        }
        return "\(price)/month — \(features)"
    }

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openDashboard() }) {
                    Image(systemName: "xmark").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }

            ScreenTitle(text: "Enigo Pro")
            Text(proDescription)
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            if appState.subscriptionStatus?.isPro == true {
                Text("You're already Pro.")
                    .font(EnigoFont.chipLabel)
                    .foregroundStyle(EnigoColor.accent(scheme))
            } else if let proProduct = products.first(where: { $0.id == StoreProductID.proMonthly }) {
                PrimaryButton(title: "Subscribe — \(proProduct.displayPrice)/month", isLoading: appState.isBusy) {
                    Task { await purchase(proProduct) }
                }
            } else if let loadError {
                Text(loadError).font(EnigoFont.meta).foregroundStyle(EnigoColor.danger(scheme))
            } else {
                ProgressView()
            }

            Text("Cancel any time.")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Out of free rematches?")
                if let boostProduct = products.first(where: { $0.id == StoreProductID.boost }) {
                    PrimaryButton(title: "One-time boost — \(boostProduct.displayPrice)", isLoading: appState.isBusy) {
                        Task { await purchaseBoost(boostProduct) }
                    }
                }
            }
        }
        .task { await loadProducts() }
    }

    private func loadProducts() async {
        do {
            products = try await Product.products(for: [StoreProductID.proMonthly, StoreProductID.boost])
            if products.isEmpty {
                // Users saw build instructions here — "configure them in App
                // Store Connect", naming a local .storekit file. StoreKit
                // returns nothing for perfectly ordinary reasons too: an App
                // Store outage, no network, or purchases restricted on the
                // device. The diagnostic is worth keeping for development,
                // but only where a developer will see it.
                #if DEBUG
                loadError = "No products returned by StoreKit — configure them in App Store Connect, or select Products.storekit as this scheme's StoreKit Configuration for local testing."
                #else
                loadError = "Pro isn't available right now. Check your connection and try again in a moment."
                #endif
            }
        } catch {
            #if DEBUG
            loadError = error.localizedDescription
            #else
            loadError = "Pro isn't available right now. Check your connection and try again in a moment."
            #endif
        }
    }

    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await appState.recordPurchase(
                    productId: transaction.productID,
                    transactionId: String(transaction.id),
                    expiresAt: transaction.expirationDate
                )
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func purchaseBoost(_ product: Product) async {
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result {
                let transaction = try checkVerified(verification)
                await appState.redeemBoost(productId: transaction.productID, transactionId: String(transaction.id))
                await transaction.finish()
            }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw BackendError.purchaseUnverified
        case .verified(let safe):
            return safe
        }
    }
}
