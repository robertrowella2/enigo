package com.enigo.app.ui.account

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.enigo.app.AppState
import com.enigo.app.data.ProfilePatch
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

/** Settings — Matching (LGBTQ+ preference, radius), Notifications
 * (messages/unlocks, everything else off always), Account. */
@Composable
fun SettingsScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()
    val radii = listOf(25, 50, 100)
    val communityOptions = listOf(
        "in_community" to "Match me inside the community",
        "open" to "It matters but I'm open either way",
        "not_looking" to "Not what I'm looking for",
        "rather_not_say" to "Rather not say",
    )

    LaunchedEffect(Unit) { appState.loadOwnProfile() }

    EnigoScreen {
        Icon(
            Icons.Filled.ArrowBack, contentDescription = "Back",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clip(CircleShape).clickable { appState.openDashboard() }
        )
        ScreenTitle("Settings")

        val profile = appState.ownProfile
        if (profile != null) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Eyebrow("Matching")
                communityOptions.forEach { (value, label) ->
                    SelectableRow(label, profile.community == value) {
                        scope.launch { appState.patchProfile(ProfilePatch(community = value)) }
                    }
                }
                Text("Order: closest first", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    radii.forEach { radius ->
                        SelectableChip("$radius km", profile.radiusKm == radius) {
                            scope.launch { appState.patchProfile(ProfilePatch(radiusKm = radius)) }
                        }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 8.dp)) {
                Eyebrow("Notifications")
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Messages", fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
                    Switch(checked = profile.notifyMessages, onCheckedChange = { v ->
                        scope.launch { appState.patchProfile(ProfilePatch(notifyMessages = v)) }
                    })
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Unlock moments", fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
                    Switch(checked = profile.notifyUnlocks, onCheckedChange = { v ->
                        scope.launch { appState.patchProfile(ProfilePatch(notifyUnlocks = v)) }
                    })
                }
                Text("Everything else — Off, always", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 8.dp)) {
            Eyebrow("Account")
            SecondaryLink("Subscription") { appState.openSubscription() }
            SecondaryLink("Sign-in help") { appState.openSignInHelp() }
            SecondaryLink("Sign out") { scope.launch { appState.signOut() } }
            Text(
                "Delete account",
                color = EnigoColor.danger(dark),
                fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize,
                modifier = Modifier.clickable { appState.openDeleteAccountConfirm() }
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 8.dp)) {
            Eyebrow("Legal")
            SecondaryLink("Terms of Service") { appState.presentedLegalDocument = LegalDocument.TERMS }
            SecondaryLink("Privacy Policy") { appState.presentedLegalDocument = LegalDocument.PRIVACY }
        }
    }
}
