import SwiftUI

struct InterestsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var searchText = ""
    private let minimum = 3
    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var filteredInterests: [String] {
        if searchText.isEmpty {
            return popularInterests
        }
        return ContentData.interests.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var popularInterests: [String] {
        Array(ContentData.interests.prefix(10))
    }

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Step 2 of 3")
            ScreenTitle(text: "What do you like?")
            Text("Pick at least three — more if you like. These unlock first, so they're the first real thing your match learns about you.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.4))
                TextField("Search or browse", text: $searchText)
                    .font(EnigoFont.body)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.4))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.06)))

            Text("\(appState.selectedInterests.count) chosen")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.accent(scheme))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(filteredInterests, id: \.self) { tag in
                    SelectableChip(text: tag, selected: appState.selectedInterests.contains(tag)) {
                        if appState.selectedInterests.contains(tag) {
                            appState.selectedInterests.remove(tag)
                        } else {
                            appState.selectedInterests.insert(tag)
                        }
                    }
                }
            }

            if filteredInterests.isEmpty {
                Text("No interests match your search")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
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
