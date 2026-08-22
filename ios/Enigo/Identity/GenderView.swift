import SwiftUI

struct GenderView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    private let options = [("woman", "Woman"), ("man", "Man"), ("nonbinary", "Nonbinary"), ("self_described", "I'll describe it myself")]

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: "How do you describe your gender?")

            VStack(spacing: 10) {
                ForEach(options, id: \.0) { value, label in
                    SelectableRow(text: label, selected: appState.gender == value) {
                        appState.gender = value
                    }
                }
            }

            if appState.gender == "self_described" {
                TextField("Describe it in your own words", text: $appState.genderSelfDescription)
                    .font(EnigoFont.body)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
            }

            Spacer(minLength: 20)

            PrimaryButton(title: "Continue", disabled: appState.gender == nil) {
                appState.submitGender()
            }
        }
    }
}
