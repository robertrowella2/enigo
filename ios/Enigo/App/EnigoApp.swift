import SwiftUI

@main
struct EnigoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.step {
            case .ageVerification:
                AgeVerificationView()
            case .introSlide(let i):
                IntroView(slideIndex: i)
            case .phone:
                PhoneView()
            case .verify:
                VerifyView()
            case .name:
                NameView()
            case .photo:
                PhotoView()
            case .interests:
                InterestsView()
            case .bio:
                BioView()
            case .gender:
                GenderView()
            case .matchedWith:
                MatchedWithView()
            case .shownTo:
                ShownToView()
            case .community:
                CommunityView()
            case .location:
                LocationView()
            case .intent:
                IntentView()
            case .question(let i):
                QuestionView(index: i)
            case .notificationPermission:
                NotificationPermissionView()
            case .searching:
                SearchingView()
            case .matchReveal:
                MatchRevealView()
            case .dashboard:
                DashboardView()
            case .chat(let matchId):
                ChatView(matchId: matchId)
            case .report(let matchId):
                ReportView(matchId: matchId)
            case .feedback:
                FeedbackView()
            case .changePhone:
                ChangePhoneView()
            case .softExit(let matchId):
                SoftExitView(matchId: matchId)
            case .profile:
                ProfileView()
            case .settings:
                SettingsView()
            case .paywall:
                PaywallView()
            case .subscription:
                SubscriptionView()
            case .signInHelp:
                SignInHelpView()
            case .deleteAccountConfirm:
                DeleteAccountConfirmView()
            }
        }
        .task { await appState.bootstrap() }
        .sheet(item: $appState.presentedLegalDocument) { document in
            LegalView(document: document)
        }
        .alert("Something went wrong", isPresented: .constant(appState.errorMessage != nil), actions: {
            Button("OK") { appState.errorMessage = nil }
        }, message: {
            Text(appState.errorMessage ?? "")
        })
    }
}
