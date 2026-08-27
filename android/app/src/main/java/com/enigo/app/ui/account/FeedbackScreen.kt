package com.enigo.app.ui.account

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.enigo.app.AppState
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun FeedbackScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    var message by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    EnigoScreen {
        BackButton { appState.step = com.enigo.app.Step.Settings }
        ScreenTitle("Send Feedback")
        Text(
            "Help us improve Enigo. What's on your mind?",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )

        OutlinedTextField(
            value = message,
            onValueChange = { message = it },
            placeholder = { Text("Your feedback...") },
            modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp).clip(RoundedCornerShape(EnigoRadius.input.dp))
        )

        Spacer(Modifier.height(20.dp))

        PrimaryButton("Send feedback", disabled = message.trim().isEmpty(), isLoading = appState.isBusy) {
            scope.launch { appState.submitFeedback(message) }
        }
        SecondaryLink("Cancel") { appState.step = com.enigo.app.Step.Settings }
    }
}
