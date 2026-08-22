package com.enigo.app.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enigo.app.AppState
import com.enigo.app.data.Backend
import com.enigo.app.data.MatchStateResponse
import com.enigo.app.data.UnlockField
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun DashboardScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    var rows by remember { mutableStateOf(listOf<MatchStateResponse>()) }
    var isLoadingRows by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    suspend fun loadRows() {
        isLoadingRows = true
        val newRows = mutableListOf<MatchStateResponse>()
        for (id in appState.activeMatchIds) {
            try {
                newRows.add(Backend.getMatchState(id))
            } catch (_: Exception) {
            }
        }
        rows = newRows
        isLoadingRows = false
    }

    LaunchedEffect(Unit) {
        appState.refreshDashboard()
        appState.loadSubscriptionStatus()
        loadRows()
    }
    LaunchedEffect(appState.activeMatchIds) { loadRows() }

    EnigoScreen(topPadding = 70) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ScreenTitle("Your connections")
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Icon(
                    Icons.Filled.Settings, contentDescription = "Settings",
                    tint = EnigoColor.body(dark),
                    modifier = Modifier.clickable { appState.openSettings() }
                )
                Icon(
                    Icons.Filled.AccountCircle, contentDescription = "Profile",
                    tint = EnigoColor.body(dark),
                    modifier = Modifier.clickable { appState.openProfile() }
                )
            }
        }

        if (rows.isEmpty() && !isLoadingRows) {
            Text(
                "No active connections yet.",
                color = EnigoColor.fgAlpha(dark, 0.6f),
                fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
            )
        }

        rows.forEach { row ->
            ConnectionRow(row) { appState.openChat(row.matchId) }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(EnigoRadius.control.dp))
                .border(1.dp, EnigoColor.fgAlpha(dark, 0.2f), RoundedCornerShape(EnigoRadius.control.dp))
                .clickable { scope.launch { appState.startNewConnection(); loadRows() } }
                .padding(vertical = 16.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = EnigoColor.fgAlpha(dark, 0.6f))
            Spacer(Modifier.width(8.dp))
            Text("Start a new connection", color = EnigoColor.fgAlpha(dark, 0.6f), fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize)
        }

        if (appState.subscriptionStatus?.isPro != true) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(EnigoRadius.card.dp))
                    .background(EnigoColor.goldAlpha(dark, 0.1f))
                    .clickable { appState.openPaywall() }
                    .padding(16.dp)
            ) {
                Text("Go Pro", fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize)
                Text(
                    "Three conversations at once, unlimited fresh starts.",
                    color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize
                )
            }
        }
    }
}

@Composable
private fun ConnectionRow(state: MatchStateResponse, onTap: () -> Unit) {
    val dark = isSystemInDarkTheme()
    val stages = listOf("INTERESTS", "BIO", "PLACE", "PHOTO")
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(EnigoRadius.card.dp))
            .background(EnigoColor.fgAlpha(dark, 0.05f))
            .clickable(onClick = onTap)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("@${state.partnerUsername}", fontFamily = EnigoFont.frauncesFamily(600), fontSize = 18.sp)
            state.distanceKm?.let { km ->
                Text("~$km km", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            UnlockField.ORDER.forEachIndexed { index, field ->
                val on = state.unlocked.contains(field.key)
                Text(
                    stages[index],
                    color = if (on) EnigoColor.accent(dark) else EnigoColor.fgAlpha(dark, 0.4f),
                    fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (on) EnigoColor.goldAlpha(dark, 0.15f) else EnigoColor.fgAlpha(dark, 0.06f))
                        .padding(vertical = 4.dp, horizontal = 8.dp)
                )
            }
        }
    }
}
