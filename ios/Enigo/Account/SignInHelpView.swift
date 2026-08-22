import SwiftUI

/// Sign-in help — no passwords exist; a code is texted to the signup
/// number. Support never asks for a photo of a face.
struct SignInHelpView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openSettings() }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: "Sign-in help")
            Text("There are no passwords on Enigo. Every sign-in sends a fresh 6-digit code by text to your signup number.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
            Text("Lost access to that number? Contact support from the email you used to sign up. Support will never ask you for a photo of your face — that's not how identity works here.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
            Spacer(minLength: 20)
            PrimaryButton(title: "Back to settings") { appState.openSettings() }
        }
    }
}
