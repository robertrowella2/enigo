import SwiftUI

struct NameView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    private var canContinue: Bool {
        !appState.firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !appState.lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !appState.username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Your name")
            ScreenTitle(text: "What's your name?")
            Text("Your first name can be shared with a match later, if you choose to. Your last name is never shown to anyone — we just keep it out of your username and out of chat.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            field("First name", text: $appState.firstName)
            field("Last name", text: $appState.lastName)

            VStack(alignment: .leading, spacing: 6) {
                Text("Username").font(EnigoFont.meta).foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                field("Username", text: $appState.username, onChange: { _ in appState.usernameError = nil })
                Text("This is what a match sees — no real names here.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.45))
                if let error = appState.usernameError {
                    Text(error)
                        .font(EnigoFont.meta)
                        .foregroundStyle(EnigoColor.danger(scheme))
                }
            }

            Spacer(minLength: 20)

            PrimaryButton(title: "Continue", disabled: !canContinue) {
                appState.submitName()
            }
        }
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, onChange: ((String) -> Void)? = nil) -> some View {
        TextField(placeholder, text: text)
            .font(EnigoFont.answerOption)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
            .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.fgAlpha(scheme, 0.12), lineWidth: 1))
            .autocorrectionDisabled()
            .onChange(of: text.wrappedValue) { _, newValue in onChange?(newValue) }
    }
}
