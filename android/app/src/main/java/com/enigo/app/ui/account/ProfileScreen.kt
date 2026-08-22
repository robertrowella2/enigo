package com.enigo.app.ui.account

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
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

/** Own profile — username prominent as the default identity, first-name
 * display as a toggle, interests/bio/location/photo rows, and a way back
 * into the eleven questions. */
@Composable
fun ProfileScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { appState.loadOwnProfile() }

    EnigoScreen {
        Icon(
            Icons.Filled.ArrowBack, contentDescription = "Back",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clip(CircleShape).clickable { appState.openDashboard() }
        )

        val profile = appState.ownProfile
        if (profile != null) {
            ProfileAvatar(appState.ownPhotoURL, size = 72.dp)

            Text("@${profile.username}", color = EnigoColor.dominant(dark), fontFamily = EnigoFont.frauncesFamily(600), fontSize = EnigoFont.matchUsernameSize)

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Show first name alongside username", fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
                Switch(checked = profile.showFirstName, onCheckedChange = { v ->
                    scope.launch { appState.patchProfile(ProfilePatch(showFirstName = v)) }
                })
            }

            ProfileRow("INTERESTS", profile.interests.joinToString(" · "))
            ProfileRow("BIO", profile.bio ?: "Not written yet")
            ProfileRow("LOCATION", if (profile.locationGranted) "Shared, ${profile.radiusKm?.toString() ?: "Anywhere"} km radius" else "Not shared")
            ProfileRow("PHOTO", if (profile.photoPath == null) "Not added" else "Added — hidden until graduation")

            SecondaryLink("Retake the eleven questions") { appState.retakeQuestions() }
        } else {
            CircularProgressIndicator()
        }
    }
}

@Composable
private fun ProfileRow(label: String, value: String) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(EnigoRadius.control.dp))
            .background(EnigoColor.fgAlpha(dark, 0.05f))
            .padding(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(label, color = EnigoColor.fgAlpha(dark, 0.45f), fontFamily = EnigoFont.interFamily(500), fontSize = EnigoFont.eyebrowSize, modifier = Modifier.width(90.dp))
        Text(value, fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
    }
}
