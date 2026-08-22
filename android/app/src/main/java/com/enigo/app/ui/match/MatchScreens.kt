package com.enigo.app.ui.match

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enigo.app.AppState
import com.enigo.app.data.Backend
import com.enigo.app.ui.theme.*

@Composable
fun SearchingScreen() {
    val dark = isSystemInDarkTheme()
    val transition = rememberInfiniteTransition(label = "breathe")
    val scale by transition.animateFloat(
        initialValue = 0.8f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1800, easing = LinearOutSlowInEasing), RepeatMode.Reverse),
        label = "scale"
    )
    EnigoScreen {
        Spacer(Modifier.height(100.dp))
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(180.dp * scale)
                    .clip(CircleShape)
                    .border(1.5.dp, EnigoColor.accent(dark).copy(alpha = 0.25f), CircleShape)
            )
            Box(
                modifier = Modifier
                    .size(130.dp * scale)
                    .clip(CircleShape)
                    .border(1.5.dp, EnigoColor.accent(dark).copy(alpha = 0.4f), CircleShape)
            )
            Text("◆", color = EnigoColor.accent(dark), fontSize = 22.sp)
        }
        Text(
            "Looking for one good match",
            color = EnigoColor.dominant(dark),
            fontFamily = EnigoFont.frauncesFamily(600),
            fontSize = EnigoFont.screenTitleSize,
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        Text(
            "This can take a day or two. We'll let you know the moment it's ready.",
            color = EnigoColor.fgAlpha(dark, 0.62f),
            fontFamily = EnigoFont.interFamily(400),
            fontSize = EnigoFont.bodySize,
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

@Composable
fun MatchRevealScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    var partnerUsername by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(appState.revealedMatchId) {
        val id = appState.revealedMatchId ?: return@LaunchedEffect
        try {
            partnerUsername = Backend.getMatchState(id).partnerUsername
        } catch (_: Exception) {
        }
    }

    EnigoScreen {
        Spacer(Modifier.height(40.dp))
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(EnigoColor.fgAlpha(dark, 0.08f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    (partnerUsername?.firstOrNull() ?: '?').uppercase(),
                    fontFamily = EnigoFont.frauncesFamily(600),
                    fontSize = EnigoFont.matchUsernameSize
                )
            }
        }
        Text(
            "@${partnerUsername ?: "…"}",
            color = EnigoColor.dominant(dark),
            fontFamily = EnigoFont.frauncesFamily(600),
            fontSize = EnigoFont.matchUsernameSize,
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        Text(
            "That's everything you get for now. No photo, no name, no city.",
            color = EnigoColor.fgAlpha(dark, 0.62f),
            fontFamily = EnigoFont.interFamily(400),
            fontSize = EnigoFont.bodySize,
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(EnigoRadius.card.dp))
                .background(EnigoColor.fgAlpha(dark, 0.05f))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Eyebrow("Why you two")
            Text("You answered the eleven questions closely enough to matter.", fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
            Text("She's the closest strong match inside your radius.", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
        }

        Spacer(Modifier.height(20.dp))
        PrimaryButton("Start the conversation") { appState.enterChat() }
        SecondaryLink("Not right now") { appState.openDashboard() }
    }
}
