import SwiftUI

/// The safety net `ChangePhoneView` can't provide. Changing your number only
/// works while you can still receive texts on the old one — porting a number
/// and only then remembering the app leaves you locked out for good. An email
/// on the account is a second door.
struct RecoveryEmailView: View {
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
            ScreenTitle(text: appState.recoveryEmailCodeSent ? "Check your email" : "Recovery email")

            if appState.recoveryEmailCodeSent {
                codeStep
            } else {
                addressStep
            }
        }
        .task { await appState.loadRecoveryEmail() }
    }

    private var addressStep: some View {
        Group {
            Text("If you lose your phone number, this is how you get back in. It's only ever used to sign in — never shown to a match, never used to contact you.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            if let existing = appState.confirmedRecoveryEmail {
                Text("Currently set to \(existing).")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            } else {
                Text("You don't have one yet — if your number goes, so does your account.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.danger(scheme).opacity(0.8))
            }

            TextField("you@example.com", text: $appState.recoveryEmail)
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
                title: appState.confirmedRecoveryEmail == nil ? "Send confirmation code" : "Change recovery email",
                disabled: !appState.recoveryEmailLooksValid,
                isLoading: appState.isBusy
            ) {
                Task { await appState.requestRecoveryEmail() }
            }
        }
    }

    private var codeStep: some View {
        Group {
            Text("We sent a 6-digit code to \(appState.recoveryEmail). Enter it to finish — the address isn't saved until you do, so a typo can't quietly cost you your only way back in.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextField("123456", text: $appState.recoveryEmailCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(EnigoFont.answerOption)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.5), lineWidth: 1))

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Confirm",
                disabled: appState.recoveryEmailCode.filter(\.isNumber).count < 6,
                isLoading: appState.isBusy
            ) {
                Task { await appState.confirmRecoveryEmail() }
            }
            SecondaryLink(title: "Use a different address") {
                appState.recoveryEmailCodeSent = false
                appState.recoveryEmailCode = ""
            }
        }
    }

    private func back() {
        appState.recoveryEmailCodeSent = false
        appState.recoveryEmailCode = ""
        appState.step = .settings
    }
}
