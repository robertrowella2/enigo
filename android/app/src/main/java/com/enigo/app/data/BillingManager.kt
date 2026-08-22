package com.enigo.app.data

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

object BillingProductID {
    const val proMonthly = "com.enigo.pro.monthly"
    const val boost = "com.enigo.boost.rematch"
}

/**
 * Thin wrapper around Play Billing Library (billing-ktx). Real purchase
 * flow — same intent as iOS's StoreKit integration, but with no local-only
 * equivalent to Products.storekit: this will only actually resolve products
 * and complete a purchase once the two ids above are created as a
 * subscription (proMonthly) and a managed in-app product (boost) in Play
 * Console for this app's package (com.enigo.app), and the build is
 * installed via at least an internal testing track.
 */
class BillingManager(
    context: Context,
    private val onPurchase: (productId: String, purchaseToken: String) -> Unit,
) {
    private var client: BillingClient? = BillingClient.newBuilder(context)
        .setListener(purchasesUpdatedListener())
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    private val _proDetails = MutableStateFlow<ProductDetails?>(null)
    val proDetails: StateFlow<ProductDetails?> = _proDetails
    private val _boostDetails = MutableStateFlow<ProductDetails?>(null)
    val boostDetails: StateFlow<ProductDetails?> = _boostDetails
    private val _connectionError = MutableStateFlow<String?>(null)
    val connectionError: StateFlow<String?> = _connectionError

    init {
        client?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryProducts()
                } else {
                    _connectionError.value = result.debugMessage
                }
            }

            override fun onBillingServiceDisconnected() {}
        })
    }

    private fun purchasesUpdatedListener() = PurchasesUpdatedListener { result, purchases ->
        if (result.responseCode == BillingClient.BillingResponseCode.OK) {
            purchases?.forEach { handlePurchase(it) }
        }
    }

    private fun queryProducts() {
        val subParams = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(BillingProductID.proMonthly)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                )
            ).build()
        client?.queryProductDetailsAsync(subParams) { result, productDetailsList ->
            val details = productDetailsList.firstOrNull()
            _proDetails.value = details
            if (result.responseCode != BillingClient.BillingResponseCode.OK || details == null) {
                _connectionError.value = "No products found — configure ${BillingProductID.proMonthly} in Play Console."
            }
        }

        val inAppParams = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(BillingProductID.boost)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                )
            ).build()
        client?.queryProductDetailsAsync(inAppParams) { _, productDetailsList ->
            _boostDetails.value = productDetailsList.firstOrNull()
        }
    }

    fun launchPurchase(activity: Activity, details: ProductDetails) {
        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
        val paramsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details)
        if (offerToken != null) paramsBuilder.setOfferToken(offerToken)
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(paramsBuilder.build()))
            .build()
        client?.launchBillingFlow(activity, flowParams)
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        val productId = purchase.products.firstOrNull() ?: return
        onPurchase(productId, purchase.purchaseToken)

        if (productId == BillingProductID.proMonthly) {
            if (!purchase.isAcknowledged) {
                val ackParams = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
                client?.acknowledgePurchase(ackParams) {}
            }
        } else {
            val consumeParams = ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
            client?.consumeAsync(consumeParams) { _, _ -> }
        }
    }

    /** Re-checks Play's own entitlement records and re-reports an active Pro
     * subscription if found — covers a reinstall or a new device. */
    fun restorePurchases(onFound: (productId: String, purchaseToken: String) -> Unit) {
        client?.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
        ) { _, purchases ->
            purchases.firstOrNull { it.products.contains(BillingProductID.proMonthly) }?.let {
                onFound(BillingProductID.proMonthly, it.purchaseToken)
            }
        }
    }

    fun close() {
        client?.endConnection()
        client = null
    }
}
