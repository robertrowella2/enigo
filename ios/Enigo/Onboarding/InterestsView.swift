import SwiftUI

struct InterestsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    private let minimum = 3
    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Step 2 of 3")
            ScreenTitle(text: "What do you like?")
            Text("Pick at least three — more if you like. These unlock first, so they're the first real thing your match learns about you.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            Text("\(appState.selectedInterests.count) chosen")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.accent(scheme))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(ContentData.interests, id: \.self) { tag in
                    SelectableChip(text: tag, selected: appState.selectedInterests.contains(tag)) {
                        if appState.selectedInterests.contains(tag) {
                            appState.selectedInterests.remove(tag)
                        } else {
                            appState.selectedInterests.insert(tag)
                        }
                    }
                }
            }

            Spacer(minLength: 20)

            let remaining = max(0, minimum - appState.selectedInterests.count)
            PrimaryButton(
                title: remaining > 0 ? "Pick \(remaining) more" : "Continue",
                disabled: remaining > 0
            ) {
                appState.submitInterests()
            }
        }
    }
}
