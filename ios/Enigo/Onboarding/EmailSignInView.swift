import SwiftUI

/// Signing in when the phone number is already gone. Only works for accounts
/// that set a recovery email while they still had access — there is no way to
/// prove ownership after the fact, which is exactly why the app nags about
/// setting one.
struct EmailSignInView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: appState.emailSignInCodeSent ? "Enter the code" : "Sign in with email")

            if appState.emailSignInCodeSent {
                codeStep
            } else {
                addressStep
            }
        }
    }

    private var addressStep: some View {
        Group {
            Text("Use the recovery email you added to your account. If you never added one, email isn't a way in — get in touch at \(LegalContent.contactEmail) with your username.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
                .textSelection(.enabled)

            TextField("you@example.com", text: $appState.emailSignInAddress)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(EnigoFont.answerOption)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.5), lineWidth: 1))

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Send code",
                disabled: !appState.emailSignInAddress.contains("@"),
                isLoading: appState.isBusy
            ) {
                Task { await appState.requestEmailSignIn() }
            }
            SecondaryLink(title: "Use my phone number instead") { back() }
        }
    }

    private var codeStep: some View {
        Group {
            Text("We sent a 6-digit code to \(appState.emailSignInAddress).")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextField("123456", text: $appState.emailSignInCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(EnigoFont.answerOption)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.5), lineWidth: 1))

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Sign in",
                disabled: appState.emailSignInCode.filter(\.isNumber).count < 6,
                isLoading: appState.isBusy
            ) {
                Task { await appState.verifyEmailSignIn() }
            }
            SecondaryLink(title: "Use a different address") {
                appState.emailSignInCodeSent = false
                appState.emailSignInCode = ""
            }
        }
    }

    private func back() {
        appState.emailSignInCodeSent = false
        appState.emailSignInCode = ""
        appState.step = .phone
    }
}
