package com.enigo.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.enigo.app.data.Backend
import com.enigo.app.data.ContentData
import com.enigo.app.data.OnboardingProfile
import com.enigo.app.data.OwnProfile
import com.enigo.app.data.ProfilePatch
import com.enigo.app.data.SubscriptionStatus
import com.enigo.app.data.UsernameGenerator
import com.enigo.app.ui.account.LegalDocument
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

sealed class Step {
    data class IntroSlide(val index: Int) : Step()
    object Phone : Step()
    object Verify : Step()
    object Name : Step()
    object Photo : Step()
    object Interests : Step()
    object Bio : Step()
    object Gender : Step()
    object MatchedWith : Step()
    object ShownTo : Step()
    object Community : Step()
    object Location : Step()
    object Intent : Step()
    data class QuestionStep(val index: Int) : Step()
    object NotificationPermission : Step()
    object Searching : Step()
    object MatchReveal : Step()
    object Dashboard : Step()
    data class Chat(val matchId: String) : Step()
    data class Report(val matchId: String) : Step()
    data class SoftExit(val matchId: String) : Step()
    object Profile : Step()
    object Settings : Step()
    object Paywall : Step()
    object Subscription : Step()
    object SignInHelp : Step()
    object DeleteAccountConfirm : Step()
}

/**
 * Root of the vertical slice: one flat state machine over [Step], mirroring
 * ios/Enigo/App/AppState.swift rather than Jetpack Navigation, since the
 * flow is linear and every step feeds the same draft profile.
 */
class AppState : ViewModel() {
    var step by mutableStateOf<Step>(Step.IntroSlide(0)); private set
    var errorMessage by mutableStateOf<String?>(null)
    var isBusy by mutableStateOf(false); private set
    var presentedLegalDocument by mutableStateOf<LegalDocument?>(null)

    var phoneNumber by mutableStateOf("")
    var verifyCode by mutableStateOf("")
    var username by mutableStateOf(UsernameGenerator.generate())
    var firstName by mutableStateOf("")
    var lastName by mutableStateOf("")
    var usernameError by mutableStateOf<String?>(null)
    var photoBytes by mutableStateOf<ByteArray?>(null)
    var selectedInterests by mutableStateOf(setOf<String>())
    var bio by mutableStateOf("")
    var gender by mutableStateOf<String?>(null)
    var genderSelfDescription by mutableStateOf("")
    var matchWith by mutableStateOf(setOf<String>())
    var shownTo by mutableStateOf(setOf<String>())
    var community by mutableStateOf<String?>(null)
    var locationGranted by mutableStateOf(false)
    var lat by mutableStateOf<Double?>(null)
    var lng by mutableStateOf<Double?>(null)
    var radiusKm by mutableStateOf<Int?>(50)
    var intent by mutableStateOf<String?>(null)
    val answers = mutableMapOf<Int, Int>()

    /** The match just found by onboarding's initial search — drives the
     * one-time Match Reveal screen only. */
    var revealedMatchId by mutableStateOf<String?>(null)

    var activeMatchIds by mutableStateOf<List<String>>(emptyList())
    var ownProfile by mutableStateOf<OwnProfile?>(null)
    var ownPhotoURL by mutableStateOf<String?>(null)
    var subscriptionStatus by mutableStateOf<SubscriptionStatus?>(null)
    var rematchCreditsRemaining by mutableStateOf<Int?>(null)
    var rematchUnlimited by mutableStateOf(false)
    var exportedData by mutableStateOf<ByteArray?>(null)

    private var searchJob: Job? = null

    /** Called once at launch. If a session survived and the account already
     * finished onboarding, skip straight to the dashboard. */
    fun bootstrap() = viewModelScope.launch {
        repeat(10) {
            if (Backend.userId.value != null) return@repeat
            delay(200)
        }
        if (Backend.userId.value == null) return@launch
        if (runCatching { Backend.fetchOwnProfile() }.getOrNull() != null) {
            openDashboard()
        }
    }

    fun advanceIntro() {
        val s = step
        step = if (s is Step.IntroSlide && s.index < ContentData.introSlides.size - 1) {
            Step.IntroSlide(s.index + 1)
        } else {
            Step.Phone
        }
    }

    private val normalizedPhone: String get() = phoneNumber.filter { it.isDigit() }

    fun submitPhone() = run {
        Backend.requestOtp(normalizedPhone)
        step = Step.Verify
    }

    fun submitVerify() = run {
        Backend.verifyOtp(normalizedPhone, verifyCode)
        // This phone number may already belong to a completed account (e.g.
        // reinstalling the app, or verifying again after signing out) — in
        // that case skip straight to the dashboard instead of re-running
        // onboarding and overwriting their existing profile.
        if (runCatching { Backend.fetchOwnProfile() }.getOrNull() != null) {
            openDashboard()
        } else {
            step = Step.Name
        }
    }

    /** Mirrors the database trigger (`enforce_username_privacy`): a
     * username may not contain the user's own first or last name, checked
     * case-insensitively and ignoring anything but letters/digits, so the
     * user sees the problem immediately instead of only after the server
     * rejects it. */
    fun validateUsername(): Boolean {
        fun normalize(s: String) = s.lowercase().filter { it.isLetterOrDigit() }
        val normalizedUsername = normalize(username)
        val normalizedFirst = normalize(firstName)
        val normalizedLast = normalize(lastName)
        if (normalizedFirst.isNotEmpty() && normalizedUsername.contains(normalizedFirst)) {
            usernameError = "Username can't contain your first name"
            return false
        }
        if (normalizedLast.isNotEmpty() && normalizedUsername.contains(normalizedLast)) {
            usernameError = "Username can't contain your last name"
            return false
        }
        usernameError = null
        return true
    }

    fun submitName() {
        if (firstName.trim().isEmpty() || lastName.trim().isEmpty() || username.trim().isEmpty()) return
        if (!validateUsername()) return
        step = Step.Photo
    }

    fun submitPhoto() { step = Step.Interests }
    fun submitInterests() { step = Step.Bio }
    fun submitBio() { step = Step.Gender }
    fun submitGender() { step = Step.MatchedWith }
    fun submitMatchedWith() { step = Step.ShownTo }
    fun submitShownTo() { step = Step.Community }
    fun submitCommunity() { step = Step.Location }
    fun submitLocation() { step = Step.Intent }
    fun submitIntent() { step = Step.QuestionStep(0) }

    fun submitAnswer(optionIndex: Int) {
        val s = step
        if (s !is Step.QuestionStep) return
        answers[s.index] = optionIndex
        step = if (s.index + 1 < ContentData.questions.size) {
            Step.QuestionStep(s.index + 1)
        } else {
            Step.NotificationPermission
        }
    }

    /**
     * Uploads the photo (if any), writes the full onboarding profile, and
     * starts searching. This is the single point the draft becomes real —
     * everything before this is only ever held in memory on-device.
     */
    fun completeOnboarding() = run {
        val uid = Backend.userId.value ?: error("Not signed in")
        val photoPath = photoBytes?.let { Backend.uploadPhoto(it, "photo.jpg") }

        val profile = OnboardingProfile(
            id = uid,
            username = username,
            firstName = firstName,
            lastName = lastName,
            gender = gender,
            genderSelfDescription = genderSelfDescription.ifEmpty { null },
            matchWith = matchWith.toList(),
            shownTo = shownTo.toList(),
            community = community,
            intent = intent,
            interests = selectedInterests.toList(),
            bio = bio.ifEmpty { null },
            photoPath = photoPath,
            lat = if (locationGranted) lat else null,
            lng = if (locationGranted) lng else null,
            radiusKm = radiusKm,
            locationGranted = locationGranted,
            answers = answers.entries.associate { (k, v) -> (k + 1).toString() to v },
            onboardingComplete = true
        )
        Backend.upsertProfile(profile)
        step = Step.Searching
        beginSearching()
    }

    /** Free tier holds exactly 1 concurrent match, so an empty dashboard for
     * a free user always means "matchless," not "chose to leave a slot
     * open" — unlike Pro, which can genuinely have spare capacity by
     * choice. Called from DashboardScreen so a free user with nothing
     * active goes straight into the searching flow instead of sitting on an
     * empty "Start a new connection" screen requiring an extra tap. */
    fun autoSearchIfFreeAndEmpty() {
        if (activeMatchIds.isEmpty() && subscriptionStatus?.isPro != true) {
            step = Step.Searching
            beginSearching()
        }
    }

    private fun beginSearching() {
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            while (true) {
                try {
                    val result = Backend.findMatch()
                    // Cancellation only takes effect at the next suspend
                    // point, so a search that was already superseded by a
                    // fresh beginSearching() call can still resume here
                    // after the fact — re-check before committing its
                    // result to shared state.
                    if (!isActive) return@launch
                    val id = result.matchIds.firstOrNull()
                    if (id != null) {
                        revealedMatchId = id
                        activeMatchIds = result.matchIds
                        step = Step.MatchReveal
                        return@launch
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    errorMessage = e.message
                }
                delay(3000)
            }
        }
    }

    fun enterChat() {
        revealedMatchId?.let { step = Step.Chat(it) }
    }

    // MARK: Dashboard

    fun openDashboard() {
        step = Step.Dashboard
        viewModelScope.launch { refreshDashboard() }
    }

    suspend fun refreshDashboard() {
        try {
            activeMatchIds = Backend.listActiveMatchIds()
        } catch (e: Exception) {
            errorMessage = e.message
        }
    }

    fun startNewConnection() = run {
        val result = Backend.findMatch()
        activeMatchIds = result.matchIds
    }

    fun openChat(matchId: String) { step = Step.Chat(matchId) }
    fun openReport(matchId: String) { step = Step.Report(matchId) }
    fun openSoftExit(matchId: String) { step = Step.SoftExit(matchId) }

    fun submitReport(matchId: String, category: String, detail: String?) = run {
        Backend.submitReport(matchId, category, detail)
        refreshDashboard()
        step = Step.Dashboard
    }

    fun confirmSoftExit(matchId: String, reason: String?) = run {
        val result = Backend.endMatch(matchId, reason)
        rematchCreditsRemaining = result.rematchCreditsRemaining
        rematchUnlimited = result.unlimited
        refreshDashboard()
        step = Step.Dashboard
    }

    // MARK: Profile / settings

    suspend fun loadOwnProfile() {
        try {
            ownProfile = Backend.fetchOwnProfile()
            ownProfile?.photoPath?.let { path ->
                ownPhotoURL = runCatching { Backend.ownPhotoURL(path) }.getOrNull()
            }
        } catch (e: Exception) {
            errorMessage = e.message
        }
    }

    fun patchProfile(patch: ProfilePatch) = run {
        Backend.patchProfile(patch)
        loadOwnProfile()
    }

    fun openProfile() {
        step = Step.Profile
        viewModelScope.launch { loadOwnProfile() }
    }

    fun openSettings() {
        step = Step.Settings
        viewModelScope.launch { loadOwnProfile() }
    }

    fun retakeQuestions() {
        answers.clear()
        step = Step.QuestionStep(0)
    }

    fun openSignInHelp() { step = Step.SignInHelp }
    fun openDeleteAccountConfirm() { step = Step.DeleteAccountConfirm }

    // MARK: Pro / subscription

    suspend fun loadSubscriptionStatus() {
        try {
            subscriptionStatus = Backend.getSubscriptionStatus()
        } catch (e: Exception) {
            errorMessage = e.message
        }
    }

    fun openPaywall() {
        step = Step.Paywall
        viewModelScope.launch { loadSubscriptionStatus() }
    }

    fun openSubscription() {
        step = Step.Subscription
        viewModelScope.launch { loadSubscriptionStatus() }
    }

    fun recordPurchase(productId: String, transactionId: String, currentPeriodEndIso: String?) = run {
        Backend.recordPurchase(productId, transactionId, currentPeriodEndIso)
        loadSubscriptionStatus()
        step = Step.Dashboard
    }

    fun redeemBoost(productId: String, transactionId: String) = run {
        Backend.redeemBoost(productId, transactionId)
    }

    // MARK: Account

    suspend fun exportAccountData() {
        try {
            exportedData = Backend.exportAccountData()
        } catch (e: Exception) {
            errorMessage = e.message
        }
    }

    fun deleteAccount() = run {
        Backend.deleteAccount()
        resetToIntro()
    }

    fun signOut() = run {
        Backend.signOut()
        resetToIntro()
    }

    private fun resetToIntro() {
        searchJob?.cancel()
        phoneNumber = ""
        verifyCode = ""
        photoBytes = null
        selectedInterests = emptySet()
        bio = ""
        gender = null
        matchWith = emptySet()
        shownTo = emptySet()
        community = null
        locationGranted = false
        lat = null
        lng = null
        intent = null
        answers.clear()
        revealedMatchId = null
        activeMatchIds = emptyList()
        ownProfile = null
        subscriptionStatus = null
        step = Step.IntroSlide(0)
    }

    private fun run(block: suspend () -> Unit) {
        viewModelScope.launch {
            isBusy = true
            errorMessage = null
            try {
                block()
            } catch (e: Exception) {
                errorMessage = e.message ?: "Something went wrong"
            }
            isBusy = false
        }
    }
}
