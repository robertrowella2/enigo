import StoreKit
import SwiftUI

/// Pro $8/month: three conversations at once, unlimited fresh starts,
/// shared-interest matching. Secondary: a one-time $2 boost for one extra
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

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openDashboard() }) {
                    Image(systemName: "xmark").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }

            ScreenTitle(text: "Enigo Pro")
            Text("$8/month — three conversations at once, unlimited fresh starts, and shared-interest matching.")
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
                loadError = "No products found — configure them in App Store Connect (or select Products.storekit as this scheme's StoreKit Configuration for local testing)."
            }
        } catch {
            loadError = error.localizedDescription
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
