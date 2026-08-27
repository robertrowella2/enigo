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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalTextStyle
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
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@Composable
fun AgeVerificationScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    var selectedYear by remember { mutableStateOf(2000) }
    var selectedMonth by remember { mutableStateOf(1) }
    var selectedDay by remember { mutableStateOf(1) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    EnigoScreen {
        Eyebrow("Step 1 of 3")
        ScreenTitle("What's your birthdate?")
        Text(
            "Enigo is for people 18 and older. We'll keep this private.",
            color = EnigoColor.fgAlpha(dark, 0.62f),
            fontFamily = EnigoFont.interFamily(400),
            fontSize = EnigoFont.bodySize
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Month picker
            Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Month", fontSize = 12.sp, color = EnigoColor.fgAlpha(dark, 0.5f))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { selectedMonth = if (selectedMonth > 1) selectedMonth - 1 else 12 },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = EnigoColor.fgAlpha(dark, 0.06f))
                    ) { Text("−", color = EnigoColor.body(dark)) }
                    Text(
                        selectedMonth.toString().padStart(2, '0'),
                        modifier = Modifier
                            .weight(1f)
                            .align(Alignment.CenterVertically),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                    Button(
                        onClick = { selectedMonth = if (selectedMonth < 12) selectedMonth + 1 else 1 },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = EnigoColor.fgAlpha(dark, 0.06f))
                    ) { Text("+", color = EnigoColor.body(dark)) }
                }
            }

            // Day picker
            Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Day", fontSize = 12.sp, color = EnigoColor.fgAlpha(dark, 0.5f))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { selectedDay = if (selectedDay > 1) selectedDay - 1 else 31 },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = EnigoColor.fgAlpha(dark, 0.06f))
                    ) { Text("−", color = EnigoColor.body(dark)) }
                    Text(
                        selectedDay.toString().padStart(2, '0'),
                        modifier = Modifier
                            .weight(1f)
                            .align(Alignment.CenterVertically),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                    Button(
                        onClick = { selectedDay = if (selectedDay < 31) selectedDay + 1 else 1 },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = EnigoColor.fgAlpha(dark, 0.06f))
                    ) { Text("+", color = EnigoColor.body(dark)) }
                }
            }

            // Year picker
            Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Year", fontSize = 12.sp, color = EnigoColor.fgAlpha(dark, 0.5f))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { selectedYear = selectedYear - 1 },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = EnigoColor.fgAlpha(dark, 0.06f))
                    ) { Text("−", color = EnigoColor.body(dark)) }
                    Text(
                        selectedYear.toString(),
                        modifier = Modifier
                            .weight(1f)
                            .align(Alignment.CenterVertically),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                    Button(
                        onClick = { selectedYear = selectedYear + 1 },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = EnigoColor.fgAlpha(dark, 0.06f))
                    ) { Text("+", color = EnigoColor.body(dark)) }
                }
            }
        }

        if (errorMessage != null) {
            Text(
                errorMessage ?: "",
                color = EnigoColor.danger(dark),
                fontFamily = EnigoFont.interFamily(400),
                fontSize = EnigoFont.metaSize
            )
        }

        Spacer(Modifier.height(24.dp))

        PrimaryButton(
            title = "Continue",
            disabled = false
        ) {
            try {
                val dateStr = "$selectedYear-${selectedMonth.toString().padStart(2, '0')}-${selectedDay.toString().padStart(2, '0')}"
                val birthDate = LocalDate.parse(dateStr)
                val today = LocalDate.now()
                val age = today.year - birthDate.year - (if (today.month < birthDate.month || (today.month == birthDate.month && today.dayOfMonth < birthDate.dayOfMonth)) 1 else 0)

                if (age >= 18) {
                    appState.birthdate = dateStr
                    appState.step = AppState.Step.IntroSlide(0)
                } else {
                    errorMessage = "You must be at least 18 years old."
                }
            } catch (e: Exception) {
                errorMessage = "Invalid date. Please check your entry."
            }
        }
    }
}

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
fun NameScreen(appState: AppState) {
    val dark = isSystemInDarkTheme()
    val canContinue = appState.firstName.isNotBlank() && appState.lastName.isNotBlank() && appState.username.isNotBlank()
    EnigoScreen {
        Eyebrow("Your name")
        ScreenTitle("What's your name?")
        Text(
            "Your first name can be shared with a match later, if you choose to. Your last name is never shown to anyone — we just keep it out of your username and out of chat.",
            color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize
        )
        OutlinedTextField(
            value = appState.firstName,
            onValueChange = { appState.firstName = it },
            placeholder = { Text("First name") },
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = appState.lastName,
            onValueChange = { appState.lastName = it },
            placeholder = { Text("Last name") },
            modifier = Modifier.fillMaxWidth()
        )
        Column {
            Text("Username", color = EnigoColor.fgAlpha(dark, 0.5f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            OutlinedTextField(
                value = appState.username,
                onValueChange = { appState.username = it; appState.usernameError = null },
                placeholder = { Text("Username") },
                modifier = Modifier.fillMaxWidth()
            )
            Text("This is what a match sees — no real names here.", color = EnigoColor.fgAlpha(dark, 0.45f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            appState.usernameError?.let {
                Text(it, color = EnigoColor.danger(dark), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)
            }
        }
        Spacer(Modifier.height(20.dp))
        PrimaryButton(title = "Continue", disabled = !canContinue) {
            appState.submitName()
        }
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
    var searchText by remember { mutableStateOf("") }

    val popularInterests = ContentData.interests.take(10)
    val filteredInterests = if (searchText.isEmpty()) {
        popularInterests
    } else {
        ContentData.interests.filter { it.contains(searchText, ignoreCase = true) }
    }

    val shouldShowCustomOption = searchText.isNotEmpty() &&
        !filteredInterests.any { it.equals(searchText.trim(), ignoreCase = true) }
    val customInterestText = "Add \"${searchText.trim()}\""

    EnigoScreen {
        Eyebrow("Step 2 of 3")
        ScreenTitle("What do you like?")
        Text("Pick at least three — more if you like. These unlock first, so they're the first real thing your match learns about you.", color = EnigoColor.fgAlpha(dark, 0.62f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(EnigoRadius.input.dp))
                .background(EnigoColor.fgAlpha(dark, 0.06f))
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = EnigoColor.fgAlpha(dark, 0.4f),
                modifier = Modifier.size(18.dp)
            )
            TextField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = { Text("Search or browse", fontSize = EnigoFont.bodySize, color = EnigoColor.fgAlpha(dark, 0.4f)) },
                modifier = Modifier
                    .weight(1f)
                    .background(Color.Transparent),
                textStyle = LocalTextStyle.current.copy(fontSize = EnigoFont.bodySize),
                colors = TextFieldDefaults.colors(
                    unfocusedContainerColor = Color.Transparent,
                    focusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent
                ),
                singleLine = true
            )
            if (searchText.isNotEmpty()) {
                IconButton(onClick = { searchText = "" }, modifier = Modifier.size(24.dp)) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = null,
                        tint = EnigoColor.fgAlpha(dark, 0.4f),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        Text("${appState.selectedInterests.size} chosen", color = EnigoColor.accent(dark), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.metaSize)

        if (filteredInterests.isNotEmpty() || shouldShowCustomOption) {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 90.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.height(420.dp)
            ) {
                items(filteredInterests) { tag ->
                    SelectableChip(text = tag, selected = appState.selectedInterests.contains(tag)) {
                        appState.selectedInterests = if (appState.selectedInterests.contains(tag)) {
                            appState.selectedInterests - tag
                        } else {
                            appState.selectedInterests + tag
                        }
                    }
                }
                if (shouldShowCustomOption) {
                    item {
                        Button(
                            onClick = {
                                val trimmed = searchText.trim()
                                appState.selectedInterests = appState.selectedInterests + trimmed
                                searchText = ""
                            },
                            modifier = Modifier
                                .clip(RoundedCornerShape(EnigoRadius.control.dp))
                                .border(1.5.dp, EnigoColor.accent(dark), RoundedCornerShape(EnigoRadius.control.dp))
                                .background(Color.Transparent),
                            contentPadding = PaddingValues(8.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent)
                        ) {
                            Text(
                                customInterestText,
                                color = EnigoColor.accent(dark),
                                fontFamily = EnigoFont.interFamily(600),
                                fontSize = EnigoFont.chipLabelSize
                            )
                        }
                    }
                }
            }
        } else {
            Text(
                "No interests match your search",
                color = EnigoColor.fgAlpha(dark, 0.5f),
                fontFamily = EnigoFont.interFamily(400),
                fontSize = EnigoFont.metaSize,
                modifier = Modifier.padding(vertical = 40.dp)
            )
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
