import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var message = ""

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.step = .settings }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: "Send Feedback")
            Text("Help us improve Enigo. What's on your mind?")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextField("Your feedback...", text: $message, axis: .vertical)
                .font(EnigoFont.body)
                .padding(14)
                .frame(minHeight: 120)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))

            Spacer(minLength: 20)

            PrimaryButton(title: "Send feedback", disabled: message.trimmingCharacters(in: .whitespaces).isEmpty, isLoading: appState.isBusy) {
                Task { await appState.submitFeedback(message: message) }
            }
            SecondaryLink(title: "Cancel") { appState.step = .settings }
        }
    }
}
