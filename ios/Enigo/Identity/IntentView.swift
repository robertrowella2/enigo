import SwiftUI

struct IntentView: View {
    @EnvironmentObject private var appState: AppState
    private let options = [("close_friend", "A close friend"), ("open", "Open to wherever it goes"), ("not_sure", "Not sure yet, just curious")]

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: "What are you hoping to find?")

            VStack(spacing: 10) {
                ForEach(options, id: \.0) { value, label in
                    SelectableRow(text: label, selected: appState.intent == value) {
                        appState.intent = value
                    }
                }
            }

            Spacer(minLength: 20)

            PrimaryButton(title: "Continue", disabled: appState.intent == nil) {
                appState.submitIntent()
            }
        }
    }
}
