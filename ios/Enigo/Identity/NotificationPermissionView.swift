import SwiftUI
import UIKit
import UserNotifications

struct NotificationPermissionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: "Something unlocked")
            Text("New messages and unlock moments only. Never streaks, never \"someone's waiting\".")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            Spacer(minLength: 20)

            PrimaryButton(title: "Turn on notifications", isLoading: appState.isBusy) {
                Task {
                    let granted = (try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                    if granted {
                        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
                    }
                    await appState.completeOnboarding()
                }
            }

            SecondaryLink(title: "Not now") {
                Task { await appState.completeOnboarding() }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
