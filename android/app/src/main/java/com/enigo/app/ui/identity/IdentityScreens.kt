package com.enigo.app.ui.identity

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.enigo.app.AppState
import com.enigo.app.data.ContentData
import com.enigo.app.data.DeviceLocation
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun GenderScreen(appState: AppState) {
    val options = listOf("woman" to "Woman", "man" to "Man", "nonbinary" to "Nonbinary", "self_described" to "I'll describe it myself")
    EnigoScreen {
        ScreenTitle("How do you describe your gender?")
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEach { (value, label) ->
                SelectableRow(label, appState.gender == value) { appState.gender = value }
            }
        }
        if (appState.gender == "self_described") {
            OutlinedTextField(
                value = appState.genderSelfDescription,
                onValueChange = { appState.genderSelfDescription = it },
                placeholder = { Text("Describe it in your own words") },
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(Modifier.height(20.dp))
        PrimaryButton("Continue", disabled = appState.gender == null) { appState.submitGender() }
    }
}

@Composable
private fun GenderMultiSelect(
    title: String,
    subtitle: String,
    selection: Set<String>,
    onSelectionChange: (Set<String>) -> Unit,
    onContinue: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val options = listOf("men" to "Men", "women" to "Women", "nonbinary" to "Nonbinary people", "anyone" to "Anyone")
    EnigoScreen {
        ScreenTitle(title)
        Text(subtitle, color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEach { (value, label) ->
                SelectableRow(label, selection.contains(value)) {
                    onSelectionChange(
                        if (value == "anyone") setOf("anyone")
                        else {
                            val withoutAnyone = selection - "anyone"
                            if (withoutAnyone.contains(value)) withoutAnyone - value else withoutAnyone + value
                        }
                    )
                }
            }
        }
        Spacer(Modifier.height(20.dp))
        PrimaryButton("Continue", disabled = selection.isEmpty(), onClick = onContinue)
    }
}

@Composable
fun MatchedWithScreen(appState: AppState) {
    GenderMultiSelect(
        title = "Matched with (1 of 3)",
        subtitle = "Who would you like Enigo to match you with?",
        selection = appState.matchWith,
        onSelectionChange = { appState.matchWith = it },
        onContinue = { appState.submitMatchedWith() }
    )
}

@Composable
fun ShownToScreen(appState: AppState) {
    GenderMultiSelect(
        title = "Shown to (2 of 3)",
        subtitle = "Who should be able to be matched with you?",
        selection = appState.shownTo,
        onSelectionChange = { appState.shownTo = it },
        onContinue = { appState.submitShownTo() }
    )
}

@Composable
fun CommunityScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val options = listOf(
        Triple("in_community", "Match me inside the community", "A filter: you'll only be matched with others who chose this too."),
        Triple("open", "It matters but I'm open either way", "A lean: it can nudge a match, never a hard rule."),
        Triple("not_looking", "Not what I'm looking for", "A filter: you won't be matched into that pool."),
        Triple("rather_not_say", "Rather not say", "No effect at all — this is never shown on a profile.")
    )
    EnigoScreen {
        Eyebrow("3 of 3")
        ScreenTitle("Is Enigo an LGBTQ+ space for you?")
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEach { (value, label, _) ->
                SelectableRow(label, appState.community == value) { appState.community = value }
            }
        }
        options.firstOrNull { it.first == appState.community }?.let { (_, _, footnote) ->
            Text(footnote, color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
        }
        Spacer(Modifier.height(20.dp))
        PrimaryButton(if (appState.community == null) "Skip this one" else "Continue") { appState.submitCommunity() }
    }
}

@Composable
fun LocationScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val radii = listOf(25, 50, 100, null)

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            scope.launch {
                val coordinates = DeviceLocation.getCurrentCoordinates(context)
                if (coordinates != null) {
                    appState.lat = coordinates.first
                    appState.lng = coordinates.second
                    appState.locationGranted = true
                } else {
                    appState.locationGranted = false
                }
            }
        } else {
            appState.locationGranted = false
        }
    }

    EnigoScreen {
        ScreenTitle("Where are you?")
        Text(
            "We sort matches by distance — the closest good one first. Your area stays sealed until it unlocks for them, and it's never an address.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text("Share my rough location", fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
            Switch(checked = appState.locationGranted, onCheckedChange = { checked ->
                if (checked) {
                    permissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
                } else {
                    appState.locationGranted = false
                    appState.lat = null
                    appState.lng = null
                }
            })
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            radii.forEach { radius ->
                SelectableChip(radius?.let { "$it km" } ?: "Anywhere", appState.radiusKm == radius) { appState.radiusKm = radius }
            }
        }
        Spacer(Modifier.height(20.dp))
        PrimaryButton("Continue") { appState.submitLocation() }
    }
}

@Composable
fun IntentScreen(appState: AppState) {
    val options = listOf("close_friend" to "A close friend", "open" to "Open to wherever it goes", "not_sure" to "Not sure yet, just curious")
    EnigoScreen {
        ScreenTitle("What are you hoping to find?")
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEach { (value, label) ->
                SelectableRow(label, appState.intent == value) { appState.intent = value }
            }
        }
        Spacer(Modifier.height(20.dp))
        PrimaryButton("Continue", disabled = appState.intent == null) { appState.submitIntent() }
    }
}

@Composable
fun QuestionScreen(appState: AppState, index: Int) {
    val dark = isSystemInDarkTheme()
    val question = ContentData.questions[index]
    EnigoScreen {
        Row(modifier = Modifier.fillMaxWidth()) {
            Text("${index + 1} of ${ContentData.questions.size}", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
            repeat(ContentData.questions.size) { i ->
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(3.dp)
                        .background(if (i <= index) EnigoColor.accent(dark) else EnigoColor.fgAlpha(dark, 0.16f))
                )
            }
        }
        Eyebrow(question.category)
        Text(question.text, color = EnigoColor.dominant(dark), fontFamily = EnigoFont.frauncesFamily(600), fontSize = EnigoFont.questionTextSize)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            question.options.forEachIndexed { optionIndex, option ->
                SelectableRow(option, false) { appState.submitAnswer(optionIndex) }
            }
        }
    }
}

@Composable
fun NotificationPermissionScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()
    EnigoScreen {
        ScreenTitle("Something unlocked")
        Text(
            "New messages and unlock moments only. Never streaks, never \"someone's waiting\".",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )
        Spacer(Modifier.height(20.dp))
        PrimaryButton("Turn on notifications", isLoading = appState.isBusy) {
            scope.launch { appState.completeOnboarding() }
        }
        SecondaryLink("Not now") { scope.launch { appState.completeOnboarding() } }
    }
}
