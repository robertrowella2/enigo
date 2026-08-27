import SwiftUI

struct AgeVerificationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var selectedDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var errorMessage: String?

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Step 1 of 3")
            ScreenTitle(text: "What's your birthdate?")
            Text("Enigo is for people 18 and older. We'll keep this private.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            DatePicker(
                "Birthdate",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .frame(maxHeight: 200)

            if let error = errorMessage {
                Text(error)
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.danger(scheme))
                    .padding(.top, 12)
            }

            Spacer(minLength: 20)

            PrimaryButton(
                title: "Continue"
            ) {
                if isOldEnough(selectedDate) {
                    appState.birthdate = selectedDate
                    appState.step = .introSlide(0)
                } else {
                    errorMessage = "You must be at least 18 years old."
                }
            }
        }
    }

    private func isOldEnough(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let eighteenYearsAgo = calendar.date(byAdding: .year, value: -18, to: today) else {
            return false
        }
        return date <= eighteenYearsAgo
    }
}
