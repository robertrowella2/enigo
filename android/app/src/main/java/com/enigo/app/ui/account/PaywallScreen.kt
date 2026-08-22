package com.enigo.app.ui.account

import android.app.Activity
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.enigo.app.AppState
import com.enigo.app.data.BillingManager
import com.enigo.app.data.BillingProductID
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

/** Pro $8/month: three conversations at once, unlimited fresh starts,
 * shared-interest matching. Secondary: a one-time $2 boost for one extra
 * rematch after the free tier's 3 declines. Real Play Billing purchase
 * flow — see BillingManager for what needs configuring in Play Console
 * before this can actually charge anyone. */
@Composable
fun PaywallScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()

    val billing = remember {
        BillingManager(context) { productId, purchaseToken ->
            scope.launch {
                if (productId == BillingProductID.proMonthly) {
                    appState.recordPurchase(productId, purchaseToken, null)
                } else {
                    appState.redeemBoost(productId, purchaseToken)
                }
            }
        }
    }
    DisposableEffect(Unit) { onDispose { billing.close() } }

    val proDetails by billing.proDetails.collectAsState()
    val boostDetails by billing.boostDetails.collectAsState()
    val connectionError by billing.connectionError.collectAsState()

    LaunchedEffect(Unit) { appState.loadSubscriptionStatus() }

    EnigoScreen {
        Icon(
            Icons.Filled.Close, contentDescription = "Close",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clickable { appState.openDashboard() }
        )

        ScreenTitle("Enigo Pro")
        Text(
            "$8/month — three conversations at once, unlimited fresh starts, and shared-interest matching.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )

        when {
            appState.subscriptionStatus?.isPro == true -> {
                Text("You're already Pro.", color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize)
            }
            proDetails != null -> {
                val price = proDetails!!.subscriptionOfferDetails
                    ?.firstOrNull()
                    ?.pricingPhases?.pricingPhaseList?.firstOrNull()
                    ?.formattedPrice ?: ""
                PrimaryButton("Subscribe — $price/month", isLoading = appState.isBusy) {
                    activity?.let { billing.launchPurchase(it, proDetails!!) }
                }
            }
            connectionError != null -> {
                Text(connectionError ?: "", color = EnigoColor.danger(dark), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            }
            else -> CircularProgressIndicator()
        }

        Text("Cancel any time.", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)

        Spacer(Modifier.height(20.dp))

        Eyebrow("Out of free rematches?")
        boostDetails?.let { details ->
            val price = details.oneTimePurchaseOfferDetails?.formattedPrice ?: ""
            PrimaryButton("One-time boost — $price", isLoading = appState.isBusy) {
                activity?.let { billing.launchPurchase(it, details) }
            }
        }
    }
}
