import SwiftUI

struct PhoneView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Step 1")
            ScreenTitle(text: "What's your number?")
            Text("Used to sign in and to confirm you're 18+. It's never shown to a match.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextField("(720) 980-1520", text: $appState.phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .font(EnigoFont.answerOption)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.5), lineWidth: 1))

            // US numbers are assumed unless a '+' is typed, so show the
            // number that will actually be dialled — a wrong country code
            // is much cheaper to catch here than after a text never lands.
            if !appState.phoneDisplay.isEmpty {
                Text("We'll text \(appState.phoneDisplay)")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                Text("Outside the US? Start with + and your country code.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.4))
            }

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Send code",
                disabled: appState.normalizedPhone.count < 10,
                isLoading: appState.isBusy
            ) {
                Task { await appState.submitPhone() }
            }

            consentLine
        }
    }

    private var consentLine: some View {
        HStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            Text("Terms")
                .underline()
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.75))
                .onTapGesture { appState.presentedLegalDocument = .terms }
            Text("and")
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            Text("Privacy Policy.")
                .underline()
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.75))
                .onTapGesture { appState.presentedLegalDocument = .privacy }
        }
        .font(EnigoFont.meta)
    }
}
