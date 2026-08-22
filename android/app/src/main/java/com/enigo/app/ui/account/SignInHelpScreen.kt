package com.enigo.app.ui.account

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.enigo.app.AppState
import com.enigo.app.ui.theme.*

/** Sign-in help — no passwords exist; a code is texted to the signup number.
 * Support never asks for a photo of a face. */
@Composable
fun SignInHelpScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()

    EnigoScreen {
        Icon(
            Icons.Filled.ArrowBack, contentDescription = "Back",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clip(CircleShape).clickable { appState.openSettings() }
        )
        ScreenTitle("Sign-in help")
        Text(
            "There are no passwords on Enigo. Every sign-in sends a fresh 6-digit code by text to your signup number.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )
        Text(
            "Lost access to that number? Contact support from the email you used to sign up. Support will never ask you for a photo of your face — that's not how identity works here.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )
        Spacer(Modifier.height(20.dp))
        PrimaryButton("Back to settings") { appState.openSettings() }
    }
}
