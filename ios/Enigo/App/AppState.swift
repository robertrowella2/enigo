import CoreLocation
import Foundation
import Supabase
import SwiftUI

enum Step: Equatable {
    case ageVerification
    case introSlide(Int)
    case phone
    case verify
    case name
    case photo
    case interests
    case bio
    case gender
    case matchedWith
    case shownTo
    case community
    case location
    case intent
    case question(Int)
    case notificationPermission
    case searching
    case matchReveal
    case dashboard
    case chat(UUID)
    case report(UUID)
    case softExit(UUID)
    case profile
    case settings
    case paywall
    case subscription
    case signInHelp
    case deleteAccountConfirm
}

/// Root of the vertical slice: one flat state machine over `Step`, mirroring
/// the prototype's single-component `state.screen` (see Enigo.dc.html) rather
/// than a NavigationStack, since the flow is linear and every step feeds the
/// same draft profile.
@MainActor
final class AppState: ObservableObject {
    @Published var step: Step = .ageVerification
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published var presentedLegalDocument: LegalDocument?

    // Onboarding draft — persisted to the backend in one upsert once
    // notification permission is resolved (see `completeOnboarding`).
    @Published var birthdate = Date()
    @Published var phoneNumber = ""
    @Published var verifyCode = ""
    @Published var username = UsernameGenerator.generate()
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var usernameError: String?
    @Published var photoData: Data?
    var photoFileName: String?
    @Published var selectedInterests: Set<String> = []
    @Published var bio = ""
    @Published var gender: String?
    @Published var genderSelfDescription = ""
    @Published var matchWith: Set<String> = []
    @Published var shownTo: Set<String> = []
    @Published var community: String?
    @Published var locationGranted = false
    @Published var locationCoordinate: CLLocationCoordinate2D?
    @Published var radiusKm: Int? = 50
    @Published var intent: String?
    @Published var answers: [Int: Int] = [:]

    private let locationManager = LocationManager()

    /// Requests real device location when the user flips "Share my rough
    /// location" on. Reverts the toggle if permission is denied or no fix
    /// could be obtained — the toggle only ever reflects a fix we actually
    /// have, never an aspirational state.
    func requestLocationPermission() async {
        if let coordinate = await locationManager.requestOneShotLocation() {
            locationCoordinate = coordinate
            locationGranted = true
        } else {
            locationCoordinate = nil
            locationGranted = false
        }
    }

    /// The match just found by onboarding's initial search — used only to
    /// drive the one-time Match Reveal screen.
    @Published var revealedMatchId: UUID?

    // MARK: - Dashboard / account state

    @Published var activeMatchIds: [UUID] = []
    @Published var ownProfile: OwnProfile?
    @Published var ownPhotoURL: URL?
    @Published var subscriptionStatus: SubscriptionStatus?

    private let backend = Backend.shared
    private var searchTask: Task<Void, Never>?

    /// Called once at launch. If a session survived in the Keychain and the
    /// account already finished onboarding, skip straight to the dashboard
    /// instead of dumping a returning user back into onboarding.
    func bootstrap() async {
        for _ in 0..<10 {
            if backend.userId != nil { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard backend.userId != nil else { return }
        if (try? await backend.fetchOwnProfile()) != nil {
            openDashboard()
        }
    }

    // MARK: - Onboarding navigation

    func advanceIntro() {
        if case .introSlide(let i) = step, i < ContentData.introSlides.count - 1 {
            step = .introSlide(i + 1)
        } else {
            step = .phone
        }
    }

    /// Digits only, no leading '+' — matches how the phone-auth test_otp
    /// numbers are configured locally (see backend/supabase/config.toml).
    private var normalizedPhone: String {
        phoneNumber.filter(\.isNumber)
    }

    func submitPhone() async {
        await run {
            try await self.backend.requestOTP(phone: self.normalizedPhone)
            self.step = .verify
        }
    }

    func submitVerify() async {
        await run {
            try await self.backend.verifyOTP(phone: self.normalizedPhone, code: self.verifyCode)
            // This phone number may already belong to a completed account
            // (e.g. reinstalling the app, or verifying again after signing
            // out) — in that case skip straight to the dashboard instead of
            // re-running onboarding and overwriting their existing profile.
            if (try? await self.backend.fetchOwnProfile()) != nil {
                self.openDashboard()
            } else {
                self.step = .name
            }
        }
    }

    /// True if `username` (normalized: lowercased, letters/digits only) contains
    /// `firstName` or `lastName` the same way normalized — mirrors the
    /// database trigger (`enforce_username_privacy`) so the user sees the
    /// problem immediately instead of only after the server rejects it.
    func validateUsername() -> Bool {
        func normalize(_ s: String) -> String {
            String(s.lowercased().filter { $0.isLetter || $0.isNumber })
        }
        let normalizedUsername = normalize(username)
        let normalizedFirst = normalize(firstName)
        let normalizedLast = normalize(lastName)
        if !normalizedFirst.isEmpty && normalizedUsername.contains(normalizedFirst) {
            usernameError = "Username can't contain your first name"
            return false
        }
        if !normalizedLast.isEmpty && normalizedUsername.contains(normalizedLast) {
            usernameError = "Username can't contain your last name"
            return false
        }
        usernameError = nil
        return true
    }

    func submitName() {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
              !lastName.trimmingCharacters(in: .whitespaces).isEmpty,
              !username.trimmingCharacters(in: .whitespaces).isEmpty,
              validateUsername()
        else { return }
        step = .photo
    }

    func submitPhoto() { step = .interests }
    func submitInterests() { step = .bio }
    func submitBio() { step = .gender }
    func submitGender() { step = .matchedWith }
    func submitMatchedWith() { step = .shownTo }
    func submitShownTo() { step = .community }
    func submitCommunity() { step = .location }
    func submitLocation() { step = .intent }
    func submitIntent() { step = .question(0) }

    func submitAnswer(_ optionIndex: Int) {
        guard case .question(let i) = step else { return }
        answers[i] = optionIndex
        if i + 1 < ContentData.questions.count {
            withAnimation(EnigoMotion.tapAdvance) { step = .question(i + 1) }
        } else {
            step = .notificationPermission
        }
    }

    /// Uploads the photo (if any), writes the full onboarding profile, and
    /// starts searching. This is the single point the draft becomes real —
    /// everything before this is only ever held in memory on-device.
    func completeOnboarding() async {
        await run {
            guard let userId = self.backend.userId else { throw BackendError.notSignedIn }

            var photoPath: String?
            if let data = self.photoData {
                photoPath = try await self.backend.uploadPhoto(data: data, fileName: self.photoFileName ?? "photo.jpg")
            }

            let profile = OnboardingProfile(
                id: userId,
                username: self.username,
                firstName: self.firstName,
                lastName: self.lastName,
                birthdate: self.birthdate,
                gender: self.gender,
                genderSelfDescription: self.genderSelfDescription.isEmpty ? nil : self.genderSelfDescription,
                matchWith: Array(self.matchWith),
                shownTo: Array(self.shownTo),
                community: self.community,
                intent: self.intent,
                interests: Array(self.selectedInterests),
                bio: self.bio.isEmpty ? nil : self.bio,
                photoPath: photoPath,
                lat: self.locationGranted ? self.locationCoordinate?.latitude : nil,
                lng: self.locationGranted ? self.locationCoordinate?.longitude : nil,
                radiusKm: self.radiusKm,
                locationGranted: self.locationGranted,
                answers: Dictionary(uniqueKeysWithValues: self.answers.map { (String($0.key + 1), $0.value) }),
                onboardingComplete: true
            )
            try await self.backend.upsertProfile(profile)
            self.step = .searching
            self.beginSearching()
        }
    }

    // MARK: - Matching

    /// Free tier holds exactly 1 concurrent match, so an empty dashboard for
    /// a free user always means "matchless," not "chose to leave a slot
    /// open" — unlike Pro, which can genuinely have spare capacity by
    /// choice. Called from DashboardView so a free user with nothing active
    /// goes straight into the searching flow instead of sitting on an empty
    /// "Start a new connection" screen requiring an extra tap.
    func autoSearchIfFreeAndEmpty() {
        guard activeMatchIds.isEmpty, subscriptionStatus?.isPro != true else { return }
        step = .searching
        beginSearching()
    }

    private func beginSearching() {
        searchTask?.cancel()
        searchTask = Task {
            while !Task.isCancelled {
                do {
                    let result = try await backend.findMatch()
                    // Cancelling searchTask doesn't abort this in-flight
                    // call (Swift's task cancellation is cooperative), so a
                    // search that was already superseded by a fresh
                    // beginSearching() can still resolve here after the
                    // fact — re-check before committing its result.
                    guard !Task.isCancelled else { return }
                    if let id = result.matchIds.first {
                        revealedMatchId = id
                        activeMatchIds = result.matchIds
                        step = .matchReveal
                        return
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func enterChat() {
        guard let id = revealedMatchId else { return }
        step = .chat(id)
    }

    // MARK: - Dashboard

    func openDashboard() {
        step = .dashboard
        Task { await refreshDashboard() }
    }

    func refreshDashboard() async {
        do {
            activeMatchIds = try await backend.listActiveMatchIds()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// "Start a new connection" — searches for one more slot (free tier is a
    /// no-op once its single slot is full; Pro can hold up to 3).
    func startNewConnection() async {
        await run {
            let result = try await self.backend.findMatch()
            self.activeMatchIds = result.matchIds
        }
    }

    func openChat(_ matchId: UUID) { step = .chat(matchId) }
    func openReport(_ matchId: UUID) { step = .report(matchId) }
    func openSoftExit(_ matchId: UUID) { step = .softExit(matchId) }

    func submitReport(matchId: UUID, category: String, detail: String?) async {
        await run {
            try await self.backend.submitReport(matchId: matchId, category: category, detail: detail)
            await self.refreshDashboard()
            self.step = .dashboard
        }
    }

    @Published var rematchCreditsRemaining: Int?
    @Published var rematchUnlimited = false

    func confirmSoftExit(matchId: UUID, reason: String?) async {
        await run {
            let result = try await self.backend.endMatch(matchId: matchId, reason: reason)
            self.rematchCreditsRemaining = result.rematchCreditsRemaining
            self.rematchUnlimited = result.unlimited
            await self.refreshDashboard()
            self.step = .dashboard
        }
    }

    // MARK: - Profile / settings

    func loadOwnProfile() async {
        do {
            ownProfile = try await backend.fetchOwnProfile()
            if let path = ownProfile?.photoPath {
                ownPhotoURL = try? await backend.ownPhotoURL(path: path)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func patchProfile(_ patch: ProfilePatch) async {
        await run {
            try await self.backend.patchProfile(patch)
            await self.loadOwnProfile()
        }
    }

    func openProfile() {
        step = .profile
        Task { await loadOwnProfile() }
    }

    func openSettings() {
        step = .settings
        Task { await loadOwnProfile() }
    }

    // MARK: - Pro / subscription

    func loadSubscriptionStatus() async {
        do {
            subscriptionStatus = try await backend.getSubscriptionStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openPaywall() {
        step = .paywall
        Task { await loadSubscriptionStatus() }
    }

    func openSubscription() {
        step = .subscription
        Task { await loadSubscriptionStatus() }
    }

    func recordPurchase(productId: String, transactionId: String, expiresAt: Date?) async {
        await run {
            try await self.backend.recordPurchase(productId: productId, transactionId: transactionId, currentPeriodEnd: expiresAt)
            await self.loadSubscriptionStatus()
            self.step = .dashboard
        }
    }

    func redeemBoost(productId: String, transactionId: String) async {
        await run {
            try await self.backend.redeemBoost(productId: productId, transactionId: transactionId)
        }
    }

    // MARK: - Account

    @Published var exportedData: Data?

    func exportAccountData() async {
        await run {
            self.exportedData = try await self.backend.exportAccountData()
        }
    }

    func deleteAccount() async {
        await run {
            try await self.backend.deleteAccount()
            self.resetToIntro()
        }
    }

    func signOut() async {
        await run {
            try await self.backend.signOut()
            self.resetToIntro()
        }
    }

    private func resetToIntro() {
        searchTask?.cancel()
        phoneNumber = ""
        verifyCode = ""
        photoData = nil
        selectedInterests = []
        bio = ""
        gender = nil
        matchWith = []
        shownTo = []
        community = nil
        locationGranted = false
        locationCoordinate = nil
        intent = nil
        answers = [:]
        revealedMatchId = nil
        activeMatchIds = []
        ownProfile = nil
        subscriptionStatus = nil
        step = .introSlide(0)
    }

    // MARK: - Helpers

    private func run(_ body: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        do {
            try await body()
        } catch let error as PostgrestError {
            errorMessage = error.message
        } catch {
            errorMessage = Backend.friendlyMessage(from: error)
        }
        isBusy = false
    }
}
