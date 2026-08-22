package com.enigo.app.ui.chat

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enigo.app.AppState
import com.enigo.app.data.Backend
import com.enigo.app.data.ChatMessage
import com.enigo.app.data.MatchStateResponse
import com.enigo.app.data.UnlockField
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private fun isReadByPartner(message: ChatMessage, partnerReadAt: String?): Boolean {
    if (partnerReadAt == null) return false
    return try {
        !java.time.Instant.parse(message.createdAt).isAfter(java.time.Instant.parse(partnerReadAt))
    } catch (_: Exception) {
        false
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(appState: AppState, matchId: String) {
    val dark = isSystemInDarkTheme()
    var messages by remember { mutableStateOf(listOf<ChatMessage>()) }
    var matchState by remember { mutableStateOf<MatchStateResponse?>(null) }
    var draft by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var showKnownSheet by remember { mutableStateOf(false) }
    var celebrationField by remember { mutableStateOf<UnlockField?>(null) }
    var previouslyUnlocked by remember { mutableStateOf(setOf<String>()) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    suspend fun refresh() {
        try {
            val activeIds = Backend.listActiveMatchIds()
            if (!activeIds.contains(matchId)) {
                appState.openDashboard()
                return
            }
            messages = Backend.listMessages(matchId)
            val state = Backend.getMatchState(matchId)
            val newlyUnlocked = state.unlocked.toSet() - previouslyUnlocked
            matchState = state
            UnlockField.ORDER.firstOrNull { newlyUnlocked.contains(it.key) }?.let { celebrationField = it }
            previouslyUnlocked = state.unlocked.toSet()
        } catch (_: Exception) {
        }
    }

    LaunchedEffect(matchId) {
        while (true) {
            refresh()
            delay(2000)
        }
    }

    fun send() {
        val text = draft.trim()
        if (text.isEmpty()) return
        draft = ""
        isSending = true

        // Show it immediately rather than waiting on the round trip — for an
        // AI match that round trip includes the persona's own reply
        // generation, which can take a couple of seconds on its own. The id
        // is generated here and sent to the server as-is (clientMessageId),
        // so the row that comes back from the next refresh() has the *same*
        // identity as this optimistic one instead of a server-generated id
        // — otherwise the list (keyed by id) sees a real delete+insert and
        // visibly flashes even though nothing actually changed from the
        // user's point of view.
        val optimisticId = java.util.UUID.randomUUID().toString()
        val optimistic = ChatMessage(
            id = optimisticId, matchId = matchId, senderId = Backend.userId.value,
            body = text, isHeavy = false, isSystem = false,
            createdAt = java.time.Instant.now().toString()
        )
        messages = messages + optimistic

        scope.launch {
            try {
                Backend.sendMessage(matchId, text, optimisticId)
                refresh()
            } catch (e: Exception) {
                // Roll back the optimistic bubble and restore the draft —
                // e.g. a blocked message (phone number, photo link) shouldn't
                // look like it sent, and shouldn't force the user to retype it.
                messages = messages.filterNot { it.id == optimisticId }
                draft = text
                errorMessage = Backend.friendlyMessage(e)
            }
            isSending = false
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(EnigoColor.background(dark))) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(EnigoColor.sheetBase(dark))
                .padding(horizontal = EnigoSpacing.listHorizontal.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "‹",
                fontSize = 26.sp,
                color = EnigoColor.body(dark),
                modifier = Modifier.clickable { appState.openDashboard() }
            )
            Column {
                Text("@${matchState?.partnerUsername ?: "…"}", fontFamily = EnigoFont.frauncesFamily(600), fontSize = 19.sp)
                Text(
                    "${messages.count { !it.isSystem }} messages",
                    color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize
                )
            }
            Text(
                "Known",
                color = EnigoColor.accent(dark),
                fontFamily = EnigoFont.interFamily(600),
                fontSize = EnigoFont.chipLabelSize,
                modifier = Modifier.clickable { showKnownSheet = true }
            )
        }

        val listState = rememberLazyListState()
        LaunchedEffect(messages.size) {
            if (messages.isNotEmpty()) listState.animateScrollToItem(messages.size - 1)
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = EnigoSpacing.listHorizontal.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (messages.isEmpty()) {
                item {
                    Text(
                        "You know each other's usernames. Everything else arrives in its own time.",
                        color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize
                    )
                }
            }
            val lastMineId = messages.lastOrNull { it.senderId == Backend.userId.value }?.id
            items(messages) { message ->
                val isMine = message.senderId == Backend.userId.value
                MessageBubble(message, isMine, dark)
                if (isMine && message.id == lastMineId && isReadByPartner(message, matchState?.partnerReadAt)) {
                    Text(
                        "Read",
                        color = EnigoColor.fgAlpha(dark, 0.4f),
                        fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.End
                    )
                }
            }
        }

        // Composer
        Row(
            modifier = Modifier.fillMaxWidth().padding(EnigoSpacing.listHorizontal.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = { Text("Type something real...") },
                modifier = Modifier.weight(1f)
            )
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(CircleShape)
                    .background(EnigoColor.primaryFill(dark))
                    .clickable(enabled = draft.isNotBlank() && !isSending) { send() },
                contentAlignment = Alignment.Center
            ) {
                Text("↑", color = EnigoColor.primaryLabel(dark), fontSize = 20.sp)
            }
        }
    }

    if (showKnownSheet) {
        ModalBottomSheet(onDismissRequest = { showKnownSheet = false }) {
            KnownSheetContent(
                matchState,
                onClose = { showKnownSheet = false },
                onReport = { showKnownSheet = false; appState.openReport(matchId) },
                onSoftExit = { showKnownSheet = false; appState.openSoftExit(matchId) }
            )
        }
    }

    celebrationField?.let { field ->
        UnlockCelebration(field) { celebrationField = null }
    }

    errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { errorMessage = null },
            confirmButton = {
                TextButton(onClick = { errorMessage = null }) { Text("OK") }
            },
            title = { Text("Message not sent") },
            text = { Text(message) }
        )
    }
}

@Composable
private fun MessageBubble(message: ChatMessage, isMine: Boolean, dark: Boolean) {
    if (message.isSystem) {
        Text(
            message.body,
            color = EnigoColor.fgAlpha(dark, 0.5f),
            fontFamily = EnigoFont.interFamily(400),
            fontSize = EnigoFont.metaSize,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
    } else {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(EnigoRadius.input.dp))
                    .background(if (isMine) EnigoColor.goldAlpha(dark, 0.14f) else EnigoColor.fgAlpha(dark, 0.06f))
                    .padding(12.dp)
                    .widthIn(max = 260.dp)
            ) {
                Text(message.body, fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.chatMessageSize)
            }
        }
    }
}

@Composable
private fun KnownSheetContent(
    state: MatchStateResponse?,
    onClose: () -> Unit,
    onReport: () -> Unit,
    onSoftExit: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val unlocked = state?.unlocked?.toSet() ?: emptySet()
    val rows = listOf(
        "INTERESTS" to (if (unlocked.contains("interests")) state?.interests?.joinToString(" · ").orEmpty() else "Not yet"),
        "BIO" to (if (unlocked.contains("bio")) state?.bio.orEmpty() else "Not yet"),
        "LOCATION" to (if (unlocked.contains("location")) state?.distanceKm?.let { "~$it km away" } ?: "Not yet" else "Not yet"),
        "PHOTO" to (if (unlocked.contains("photo")) "Revealed" else "Not yet"),
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(EnigoColor.sheetBase(dark))
            .padding(EnigoSpacing.screenHorizontal.dp),
        verticalArrangement = Arrangement.spacedBy(EnigoSpacing.stackGap.dp)
    ) {
        Text("What you know so far", fontFamily = EnigoFont.frauncesFamily(600), fontSize = 22.sp)
        rows.forEach { (label, value) ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(EnigoRadius.control.dp))
                    .background(EnigoColor.fgAlpha(dark, 0.05f))
                    .padding(12.dp)
            ) {
                Text(label, color = EnigoColor.fgAlpha(dark, 0.45f), fontFamily = EnigoFont.interFamily(500), fontSize = EnigoFont.eyebrowSize, modifier = Modifier.width(90.dp))
                Text(value, fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
            }
        }
        Text(
            "Both of you have to keep showing up for the next one. We don't say how close it is — that's the point.",
            color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize
        )
        Text("Report", color = EnigoColor.danger(dark), fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize, modifier = Modifier.clickable { onReport() })
        Text("This isn't quite it", color = EnigoColor.fgAlpha(dark, 0.6f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize, modifier = Modifier.clickable { onSoftExit() })
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun UnlockCelebration(field: UnlockField, onDismiss: () -> Unit) {
    val dark = isSystemInDarkTheme()
    val transition = rememberInfiniteTransition(label = "celebrationBreathe")
    val scale by transition.animateFloat(0.85f, 1f, infiniteRepeatable(tween(1800, easing = LinearOutSlowInEasing), RepeatMode.Reverse), label = "scale")

    val badge = when (field) {
        UnlockField.INTERESTS -> "INTERESTS"
        UnlockField.BIO -> "BIO"
        UnlockField.LOCATION -> "PLACE"
        UnlockField.PHOTO -> "PHOTO"
    }
    val note = when (field) {
        UnlockField.INTERESTS -> "The first real thing you've learned about each other."
        UnlockField.BIO -> "The only free-text thing they wrote in the whole app."
        UnlockField.LOCATION -> "Rough area only. Never an address, never live location."
        UnlockField.PHOTO -> "You got here by showing up, both of you. Nothing was rushed."
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.6f)),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Box(
                modifier = Modifier
                    .size(120.dp * scale)
                    .clip(CircleShape)
                    .border(1.5.dp, EnigoColor.accent(dark), CircleShape)
            )
            Text("SOMETHING UNLOCKED", color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(500), fontSize = EnigoFont.eyebrowSize, letterSpacing = 3.sp)
            Text(badge, color = androidx.compose.ui.graphics.Color.White, fontFamily = EnigoFont.frauncesFamily(600), fontSize = 28.sp)
            Text(
                note,
                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.7f),
                fontFamily = EnigoFont.interFamily(400),
                fontSize = EnigoFont.bodySize,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 40.dp)
            )
            Text(
                "Continue",
                color = EnigoColor.accent(dark),
                fontFamily = EnigoFont.interFamily(600),
                fontSize = EnigoFont.chipLabelSize,
                modifier = Modifier.padding(top = 12.dp).clickable { onDismiss() }
            )
        }
    }
}
