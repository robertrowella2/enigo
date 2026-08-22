import SwiftUI

/// "Reporting always ends the match immediately and permanently excludes
/// that pair from rematching. A human reads every report."
struct ReportView: View {
    let matchId: UUID
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var category: String?
    @State private var detail = ""

    private let categories = [
        ("harassment", "Harassment or threats"),
        ("inappropriate_content", "Inappropriate content"),
        ("fake_profile", "Fake profile"),
        ("money", "Asking for money"),
        ("other", "Something else"),
    ]

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: "Report")
            Text("Reporting ends this match immediately. A human reads every report.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            VStack(spacing: 10) {
                ForEach(categories, id: \.0) { value, label in
                    SelectableRow(text: label, selected: category == value) { category = value }
                }
            }

            TextField("Optional detail", text: $detail, axis: .vertical)
                .font(EnigoFont.body)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.05)))

            Spacer(minLength: 20)

            PrimaryButton(title: "Submit report", disabled: category == nil, isLoading: appState.isBusy) {
                guard let category else { return }
                Task { await appState.submitReport(matchId: matchId, category: category, detail: detail.isEmpty ? nil : detail) }
            }
            SecondaryLink(title: "Cancel") { appState.openChat(matchId) }
        }
    }
}
