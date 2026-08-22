package com.enigo.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.enigo.app.ui.account.DeleteAccountConfirmScreen
import com.enigo.app.ui.account.PaywallScreen
import com.enigo.app.ui.account.ProfileScreen
import com.enigo.app.ui.account.SettingsScreen
import com.enigo.app.ui.account.SignInHelpScreen
import com.enigo.app.ui.account.SubscriptionScreen
import com.enigo.app.ui.chat.ChatScreen
import com.enigo.app.ui.chat.ReportScreen
import com.enigo.app.ui.chat.SoftExitScreen
import com.enigo.app.ui.dashboard.DashboardScreen
import com.enigo.app.ui.identity.*
import com.enigo.app.ui.match.MatchRevealScreen
import com.enigo.app.ui.match.SearchingScreen
import com.enigo.app.ui.onboarding.*

class MainActivity : ComponentActivity() {
    private val appState: AppState by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface {
                    RootView(appState)
                }
            }
        }
    }
}

@Composable
fun RootView(appState: AppState) {
    LaunchedEffect(Unit) { appState.bootstrap() }

    when (val step = appState.step) {
        is Step.IntroSlide -> IntroScreen(appState, step.index)
        Step.Phone -> PhoneScreen(appState)
        Step.Verify -> VerifyScreen(appState)
        Step.Photo -> PhotoScreen(appState)
        Step.Interests -> InterestsScreen(appState)
        Step.Bio -> BioScreen(appState)
        Step.Gender -> GenderScreen(appState)
        Step.MatchedWith -> MatchedWithScreen(appState)
        Step.ShownTo -> ShownToScreen(appState)
        Step.Community -> CommunityScreen(appState)
        Step.Location -> LocationScreen(appState)
        Step.Intent -> IntentScreen(appState)
        is Step.QuestionStep -> QuestionScreen(appState, step.index)
        Step.NotificationPermission -> NotificationPermissionScreen(appState)
        Step.Searching -> SearchingScreen()
        Step.MatchReveal -> MatchRevealScreen(appState)
        Step.Dashboard -> DashboardScreen(appState)
        is Step.Chat -> ChatScreen(appState, step.matchId)
        is Step.Report -> ReportScreen(appState, step.matchId)
        is Step.SoftExit -> SoftExitScreen(appState, step.matchId)
        Step.Profile -> ProfileScreen(appState)
        Step.Settings -> SettingsScreen(appState)
        Step.Paywall -> PaywallScreen(appState)
        Step.Subscription -> SubscriptionScreen(appState)
        Step.SignInHelp -> SignInHelpScreen(appState)
        Step.DeleteAccountConfirm -> DeleteAccountConfirmScreen(appState)
    }

    appState.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { appState.errorMessage = null },
            confirmButton = {
                TextButton(onClick = { appState.errorMessage = null }) { Text("OK") }
            },
            title = { Text("Something went wrong") },
            text = { Text(message) }
        )
    }
}
