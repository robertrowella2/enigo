import SwiftUI

struct ShownToView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        GenderMultiSelect(
            title: "Shown to (2 of 3)",
            subtitle: "Who should be able to be matched with you?",
            selection: $appState.shownTo,
            onContinue: { appState.submitShownTo() }
        )
    }
}
