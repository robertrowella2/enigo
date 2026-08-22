package com.enigo.app.ui.account

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.enigo.app.AppState
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

/** Delete account — irreversible, offers data export first, matches see the
 * conversation close without a reason. */
@Composable
fun DeleteAccountConfirmScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var confirmedUnderstanding by remember { mutableStateOf(false) }
    var isExporting by remember { mutableStateOf(false) }
    var exportReady by remember { mutableStateOf(false) }

    EnigoScreen {
        Icon(
            Icons.Filled.ArrowBack, contentDescription = "Back",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clip(CircleShape).clickable { appState.openSettings() }
        )
        ScreenTitle("Delete account")
        Text(
            "This is permanent. Your matches will see the conversation close without a reason — no notification, no explanation.",
            color = EnigoColor.danger(dark), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )

        PrimaryButton("Export my data first", isLoading = isExporting || appState.isBusy) {
            isExporting = true
            scope.launch {
                appState.exportAccountData()
                isExporting = false
                exportReady = appState.exportedData != null
            }
        }
        if (exportReady) {
            Text(
                "Save export",
                color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize,
                modifier = Modifier.clickable {
                    val data = appState.exportedData ?: return@clickable
                    val file = File(context.cacheDir, "enigo-export-${UUID.randomUUID()}.json")
                    file.writeBytes(data)
                    val uri = FileProvider.getUriForFile(context, "com.enigo.app.fileprovider", file)
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/json"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    context.startActivity(Intent.createChooser(intent, "Save export"))
                }
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(checked = confirmedUnderstanding, onCheckedChange = { confirmedUnderstanding = it })
            Text("I understand this can't be undone.", fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        }

        Spacer(Modifier.height(20.dp))

        PrimaryButton("Delete my account", disabled = !confirmedUnderstanding, isLoading = appState.isBusy) {
            scope.launch { appState.deleteAccount() }
        }
        SecondaryLink("Cancel") { appState.openSettings() }
    }
}
