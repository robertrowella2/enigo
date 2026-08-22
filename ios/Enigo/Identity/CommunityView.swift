import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    private let options: [(String, String, String)] = [
        ("in_community", "Match me inside the community", "A filter: you'll only be matched with others who chose this too."),
        ("open", "It matters but I'm open either way", "A lean: it can nudge a match, never a hard rule."),
        ("not_looking", "Not what I'm looking for", "A filter: you won't be matched into that pool."),
        ("rather_not_say", "Rather not say", "No effect at all — this is never shown on a profile."),
    ]

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "3 of 3")
            ScreenTitle(text: "Is Enigo an LGBTQ+ space for you?")

            VStack(spacing: 10) {
                ForEach(options, id: \.0) { value, label, _ in
                    SelectableRow(text: label, selected: appState.community == value) {
                        appState.community = value
                    }
                }
            }

            if let selected = appState.community, let footnote = options.first(where: { $0.0 == selected })?.2 {
                Text(footnote)
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            }

            Spacer(minLength: 20)

            PrimaryButton(title: appState.community == nil ? "Skip this one" : "Continue") {
                appState.submitCommunity()
            }
        }
    }
}
