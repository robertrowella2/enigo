import SwiftUI

struct BioView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    private let limit = 240

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Step 3 of 3")
            ScreenTitle(text: "Write a little about yourself")
            Text("The only free-text field in the whole app. Unlocks after your interests do.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            TextEditor(text: $appState.bio)
                .font(EnigoFont.fraunces(size: 16, weight: 400))
                .scrollContentBackground(.hidden)
                .frame(height: 140)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                .overlay(RoundedRectangle(cornerRadius: EnigoRadius.input).stroke(EnigoColor.fgAlpha(scheme, 0.12), lineWidth: 1))
                .onChange(of: appState.bio) { _, newValue in
                    if newValue.count > limit { appState.bio = String(newValue.prefix(limit)) }
                }

            Text("\(appState.bio.count)/\(limit)")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.45))

            Spacer(minLength: 20)

            PrimaryButton(title: "Continue") { appState.submitBio() }
        }
    }
}
