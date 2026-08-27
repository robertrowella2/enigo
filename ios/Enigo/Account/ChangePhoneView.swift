import SwiftUI

/// Moving the account to a new number, for someone who still has access to
/// the old one — switching carriers, a new SIM. Nothing is keyed on the
/// phone (profiles.id is the auth UUID), so the account survives the move
/// intact; only the sign-in credential changes.
struct ChangePhoneView: View {
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
            ScreenTitle(text: appState.phoneChangeCodeSent ? "Enter the code" : "Change your number")

            if appState.phoneChangeCodeSent {
                codeStep
            } else {
                numberStep
            }
        }
        .task { await appState.loadCurrentPhone() }
    }

    private var numberStep: some View {
        Group {
            Text("Your matches, messages and subscription stay exactly as they are — only the number you sign in with changes.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            if let current = appState.currentPhone {
                Text("Signing in with \(current) today.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            }

            TextField("(720) 980-1520", text: $appState.newPhoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .font(EnigoFont.answerOption)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.5), lineWidth: 1))

            Text("Do this while you can still receive texts on your old number — there's no way back once it's gone.")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Send code to new number",
                disabled: appState.normalizedNewPhone.count < 10,
                isLoading: appState.isBusy
            ) {
                Task { await appState.requestPhoneChange() }
            }
        }
    }

    private var codeStep: some View {
        Group {
            Text("We texted a 6-digit code to your new number.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextField("123456", text: $appState.phoneChangeCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(EnigoFont.answerOption)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.5), lineWidth: 1))

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Confirm new number",
                disabled: appState.phoneChangeCode.filter(\.isNumber).count < 6,
                isLoading: appState.isBusy
            ) {
                Task { await appState.confirmPhoneChange() }
            }
            SecondaryLink(title: "Use a different number") {
                appState.phoneChangeCodeSent = false
                appState.phoneChangeCode = ""
            }
        }
    }

    private func back() {
        appState.phoneChangeCodeSent = false
        appState.phoneChangeCode = ""
        appState.step = .settings
    }
}
