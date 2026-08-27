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

            // This used to tell people to write in "from the email you used
            // to sign up" — Enigo never asks for an email, so that pointed at
            // an account that does not exist. Changing the number in advance
            // is the only recovery that actually works.
            Text("Getting a new number? Change it in Settings **before** you lose the old one — your matches, messages and subscription all move with you.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            Text("Already lost access to your number? Email \(LegalContent.contactEmail) from anywhere and include your username — that's what we can look you up by. Support will never ask you for a photo of your face; that's not how identity works here.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
                .textSelection(.enabled)

            Spacer(minLength: 20)
            PrimaryButton(title: "Change my number") { appState.step = .changePhone }
            SecondaryLink(title: "Back to settings") { appState.openSettings() }
        }
    }
}
