package com.enigo.app.ui.onboarding

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.enigo.app.AppState
import com.enigo.app.data.ContentData
import com.enigo.app.ui.account.LegalDocument
import com.enigo.app.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun IntroScreen(appState: AppState, slideIndex: Int) {
    val dark = isSystemInDarkTheme()
    val slide = ContentData.introSlides[slideIndex]
    EnigoScreen(topPadding = 64) {
        Spacer(Modifier.height(24.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(210.dp)
                .clip(RoundedCornerShape(EnigoRadius.card.dp))
                .background(EnigoColor.fgAlpha(dark, 0.06f)),
            contentAlignment = Alignment.Center
        ) {
            Text(slide.art, color = EnigoColor.fgAlpha(dark, 0.4f), fontFamily = EnigoFont.interFamily(500), fontSize = EnigoFont.eyebrowSize, letterSpacing = 3.sp)
        }
        Text(slide.title, color = EnigoColor.dominant(dark), fontFamily = EnigoFont.frauncesFamily(600), fontSize = 33.sp)
        Text(slide.body, color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        ProgressDots(count = ContentData.introSlides.size, index = slideIndex)
        Spacer(Modifier.height(20.dp))
        PrimaryButton(title = slide.cta) { appState.advanceIntro() }
        if (slideIndex == 0) {
            SecondaryLink("I already have an account") {}
        }
    }
}

@Composable
fun PhoneScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()
    EnigoScreen {
        Eyebrow("Step 1")
        ScreenTitle("What's your number?")
        Text("Used to sign in and to confirm you're 18+. It's never shown to a match.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        OutlinedTextField(
            value = appState.phoneNumber,
            onValueChange = { appState.phoneNumber = it },
            placeholder = { Text("15555550100") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(20.dp))
        PrimaryButton(
            title = "Send code",
            disabled = appState.phoneNumber.length < 8,
            isLoading = appState.isBusy
        ) { scope.launch { appState.submitPhone() } }

        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("By continuing, you agree to our", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            Text(
                "Terms",
                color = EnigoColor.fgAlpha(dark, 0.75f),
                fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize,
                textDecoration = androidx.compose.ui.text.style.TextDecoration.Underline,
                modifier = Modifier.clickable { appState.presentedLegalDocument = LegalDocument.TERMS }
            )
            Text("and", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            Text(
                "Privacy Policy.",
                color = EnigoColor.fgAlpha(dark, 0.75f),
                fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize,
                textDecoration = androidx.compose.ui.text.style.TextDecoration.Underline,
                modifier = Modifier.clickable { appState.presentedLegalDocument = LegalDocument.PRIVACY }
            )
        }
    }
}

@Composable
fun VerifyScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()
    EnigoScreen {
        Eyebrow("Step 2")
        ScreenTitle("Enter the code")
        Text("We texted a 6-digit code to ${appState.phoneNumber}.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        OutlinedTextField(
            value = appState.verifyCode,
            onValueChange = { appState.verifyCode = it },
            placeholder = { Text("123456") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(20.dp))
        PrimaryButton(
            title = "Verify",
            disabled = appState.verifyCode.length < 6,
            isLoading = appState.isBusy
        ) { scope.launch { appState.submitVerify() } }
    }
}

@Composable
fun PhotoScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            context.contentResolver.openInputStream(uri)?.use { appState.photoBytes = it.readBytes() }
        }
    }
    EnigoScreen {
        Eyebrow("Photo · step 1 of 3")
        ScreenTitle("Add a photo nobody sees yet")
        Text("It stays completely private until graduation — the very last thing that unlocks.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)

        val bitmap = remember(appState.photoBytes) {
            appState.photoBytes?.let { android.graphics.BitmapFactory.decodeByteArray(it, 0, it.size) }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(196.dp)
                .clip(RoundedCornerShape(EnigoRadius.photoWell.dp))
                .border(1.5.dp, EnigoColor.fgAlpha(dark, 0.2f), RoundedCornerShape(EnigoRadius.photoWell.dp))
                .clickable { launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
            contentAlignment = Alignment.Center
        ) {
            if (bitmap != null) {
                Image(bitmap.asImageBitmap(), contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("SEALED", color = EnigoColor.fgAlpha(dark, 0.45f), fontFamily = EnigoFont.interFamily(500), fontSize = EnigoFont.eyebrowSize, letterSpacing = 2.sp)
                    Text("Tap to choose a photo", color = EnigoColor.fgAlpha(dark, 0.45f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
                }
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(EnigoRadius.control.dp))
                .background(EnigoColor.goldAlpha(dark, 0.08f))
                .padding(12.dp)
        ) {
            Text("Hidden until graduation. Always.", color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
        }

        Spacer(Modifier.height(20.dp))
        PrimaryButton(title = if (appState.photoBytes == null) "Skip for now" else "Continue") { appState.submitPhoto() }
    }
}

@Composable
fun InterestsScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val minimum = 3
    EnigoScreen {
        Eyebrow("Step 2 of 3")
        ScreenTitle("What do you like?")
        Text("Pick at least three — more if you like. These unlock first, so they're the first real thing your match learns about you.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        Text("${appState.selectedInterests.size} chosen", color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)

        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 90.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.height(420.dp)
        ) {
            items(ContentData.interests) { tag ->
                SelectableChip(text = tag, selected = appState.selectedInterests.contains(tag)) {
                    appState.selectedInterests = if (appState.selectedInterests.contains(tag)) {
                        appState.selectedInterests - tag
                    } else {
                        appState.selectedInterests + tag
                    }
                }
            }
        }

        val remaining = (minimum - appState.selectedInterests.size).coerceAtLeast(0)
        PrimaryButton(
            title = if (remaining > 0) "Pick $remaining more" else "Continue",
            disabled = remaining > 0
        ) { appState.submitInterests() }
    }
}

@Composable
fun BioScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val limit = 240
    EnigoScreen {
        Eyebrow("Step 3 of 3")
        ScreenTitle("Write a little about yourself")
        Text("The only free-text field in the whole app. Unlocks after your interests do.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
        OutlinedTextField(
            value = appState.bio,
            onValueChange = { if (it.length <= limit) appState.bio = it },
            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = EnigoFont.frauncesFamily(400), fontSize = 16.sp, fontStyle = FontStyle.Normal),
            modifier = Modifier.fillMaxWidth().height(140.dp)
        )
        Text("${appState.bio.length}/$limit", color = EnigoColor.fgAlpha(dark, 0.45f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
        Spacer(Modifier.height(20.dp))
        PrimaryButton(title = "Continue") { appState.submitBio() }
    }
}
