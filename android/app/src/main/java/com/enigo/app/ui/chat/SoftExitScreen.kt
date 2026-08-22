package com.enigo.app.ui.chat

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.enigo.app.AppState
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

/** "This isn't quite it" — states plainly that the other person won't be
 * notified: no notification, no last-seen. Optional reason chips are sent
 * to the backend as soft_exit_reason. Shows remaining free rematches. */
@Composable
fun SoftExitScreen(appState: AppState, matchId: String) {
    val dark = isSystemInDarkTheme()
    var reason by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val reasons = listOf("Didn't click", "Too slow", "Not what I expected", "Just not feeling it")

    EnigoScreen {
        ScreenTitle("This isn't quite it")
        Text(
            "They won't be notified — no notification, no last-seen. This just clears a slot for your next connection.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )

        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 130.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.height(96.dp)
        ) {
            items(reasons.size) { i ->
                val r = reasons[i]
                SelectableChip(r, reason == r) { reason = r }
            }
        }

        appState.rematchCreditsRemaining?.let { remaining ->
            Text(
                if (appState.rematchUnlimited) "Unlimited fresh starts with Pro." else "$remaining free rematches remaining.",
                color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize
            )
        }

        Spacer(Modifier.height(20.dp))

        PrimaryButton("End this connection", isLoading = appState.isBusy) {
            scope.launch { appState.confirmSoftExit(matchId, reason) }
        }
        SecondaryLink("Never mind") { appState.openChat(matchId) }
    }
}
