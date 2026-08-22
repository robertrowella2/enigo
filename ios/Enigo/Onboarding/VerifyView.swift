import SwiftUI

struct VerifyView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Step 2")
            ScreenTitle(text: "Enter the code")
            Text("We texted a 6-digit code to \(appState.phoneNumber).")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextField("123456", text: $appState.verifyCode)
                .keyboardType(.numberPad)
                .font(EnigoFont.fraunces(size: 28, weight: 600))
                .multilineTextAlignment(.center)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.accent(scheme).opacity(0.55), lineWidth: 1))

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Verify",
                disabled: appState.verifyCode.count < 6,
                isLoading: appState.isBusy
            ) {
                Task { await appState.submitVerify() }
            }
        }
    }
}
