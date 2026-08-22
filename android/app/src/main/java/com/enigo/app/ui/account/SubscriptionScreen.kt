package com.enigo.app.ui.account

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enigo.app.AppState
import com.enigo.app.data.BillingManager
import com.enigo.app.data.BillingProductID
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

/** Subscription — active-plan card, manage in Play Store, restore
 * purchases. Cancelling keeps existing connections until they end
 * naturally. */
@Composable
fun SubscriptionScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val billing = remember {
        BillingManager(context) { productId, purchaseToken ->
            scope.launch {
                if (productId == BillingProductID.proMonthly) {
                    appState.recordPurchase(productId, purchaseToken, null)
                }
            }
        }
    }
    DisposableEffect(Unit) { onDispose { billing.close() } }

    LaunchedEffect(Unit) { appState.loadSubscriptionStatus() }

    EnigoScreen {
        Icon(
            Icons.Filled.ArrowBack, contentDescription = "Back",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clip(CircleShape).clickable { appState.openDashboard() }
        )
        ScreenTitle("Subscription")

        val status = appState.subscriptionStatus
        if (status != null && status.isPro) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(EnigoRadius.card.dp))
                    .background(EnigoColor.fgAlpha(dark, 0.05f))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Eyebrow("Current plan")
                Text("Enigo Pro", fontFamily = EnigoFont.frauncesFamily(600), fontSize = 20.sp)
                Text(
                    "Manage or cancel any time in Google Play. Cancelling keeps existing connections until they end naturally — nothing is cut off mid-conversation.",
                    color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
                )
            }

            Text(
                "Manage in Google Play",
                color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize,
                modifier = Modifier.clickable {
                    val intent = Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("https://play.google.com/store/account/subscriptions?package=${context.packageName}")
                    )
                    context.startActivity(intent)
                }
            )
        } else {
            Text("You're on the free plan.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
            PrimaryButton("See Pro") { appState.openPaywall() }
        }

        SecondaryLink("Restore purchases") {
            billing.restorePurchases { productId, purchaseToken ->
                scope.launch { appState.recordPurchase(productId, purchaseToken, null) }
            }
        }
    }
}
