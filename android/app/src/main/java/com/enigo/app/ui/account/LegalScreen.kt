package com.enigo.app.ui.account

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.enigo.app.ui.theme.*

/** Shown as a full-screen overlay from Settings and from the pre-account
 * consent links on PhoneScreen — see [AppState.presentedLegalDocument]. */
@Composable
fun LegalScreen(document: LegalDocument, onBack: () -> Unit) {
    val dark = isSystemInDarkTheme()
    EnigoScreen {
        Icon(
            Icons.Filled.ArrowBack, contentDescription = "Back",
            tint = EnigoColor.body(dark),
            modifier = Modifier.clip(CircleShape).clickable { onBack() }
        )
        ScreenTitle(document.title)
        Text(
            "Last updated ${LegalContent.lastUpdated}",
            color = EnigoColor.fgAlpha(dark, 0.5f),
            fontFamily = EnigoFont.interFamily(400),
            fontSize = EnigoFont.metaSize
        )

        LegalContent.sections(document).forEach { section ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp)) {
                Eyebrow(section.heading)
                Text(
                    section.body,
                    color = EnigoColor.body(dark),
                    fontFamily = EnigoFont.interFamily(400),
                    fontSize = EnigoFont.bodySize
                )
            }
        }
        Spacer(Modifier.height(1.dp))
    }
}
