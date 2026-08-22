import SwiftUI

/// Shared UI for the two symmetric multi-selects (Matched with / Shown to).
/// Both are a hard filter: a match requires both sides' preferences to
/// overlap (enforced server-side in find_match_candidates).
struct GenderMultiSelect: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    @Binding var selection: Set<String>
    let onContinue: () -> Void

    private let options = [("men", "Men"), ("women", "Women"), ("nonbinary", "Nonbinary people"), ("anyone", "Anyone")]

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: title)
            Text(subtitle)
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            VStack(spacing: 10) {
                ForEach(options, id: \.0) { value, label in
                    SelectableRow(text: label, selected: selection.contains(value)) {
                        if value == "anyone" {
                            selection = ["anyone"]
                        } else {
                            selection.remove("anyone")
                            if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
                        }
                    }
                }
            }

            Spacer(minLength: 20)

            PrimaryButton(title: "Continue", disabled: selection.isEmpty, action: onContinue)
        }
    }
}

struct MatchedWithView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        GenderMultiSelect(
            title: "Matched with (1 of 3)",
            subtitle: "Who would you like Enigo to match you with?",
            selection: $appState.matchWith,
            onContinue: { appState.submitMatchedWith() }
        )
    }
}
