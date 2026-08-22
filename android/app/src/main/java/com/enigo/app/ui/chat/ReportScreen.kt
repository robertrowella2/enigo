package com.enigo.app.ui.chat

import androidx.compose.foundation.background
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

/** Reporting always ends the match immediately and permanently excludes that
 * pair from rematching. A human reads every report. */
@Composable
fun ReportScreen(appState: AppState, matchId: String) {
    val dark = isSystemInDarkTheme()
    var category by remember { mutableStateOf<String?>(null) }
    var detail by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    val categories = listOf(
        "harassment" to "Harassment or threats",
        "inappropriate_content" to "Inappropriate content",
        "fake_profile" to "Fake profile",
        "money" to "Asking for money",
        "other" to "Something else",
    )

    EnigoScreen {
        ScreenTitle("Report")
        Text(
            "Reporting ends this match immediately. A human reads every report.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            categories.forEach { (value, label) ->
                SelectableRow(label, category == value) { category = value }
            }
        }

        OutlinedTextField(
            value = detail,
            onValueChange = { detail = it },
            placeholder = { Text("Optional detail") },
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(EnigoRadius.input.dp))
        )

        Spacer(Modifier.height(20.dp))

        PrimaryButton("Submit report", disabled = category == null, isLoading = appState.isBusy) {
            val c = category ?: return@PrimaryButton
            scope.launch { appState.submitReport(matchId, c, detail.ifEmpty { null }) }
        }
        SecondaryLink("Cancel") { appState.openChat(matchId) }
    }
}
