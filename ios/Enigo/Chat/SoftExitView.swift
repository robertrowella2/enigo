import SwiftUI

/// "This isn't quite it" — states plainly that the other person won't be
/// notified: no notification, no last-seen. Optional reason chips. Shows
/// remaining free rematches.
struct SoftExitView: View {
    let matchId: UUID
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var reason: String?
    private let reasons = ["Didn't click", "Too slow", "Not what I expected", "Just not feeling it"]

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: "This isn't quite it")
            Text("They won't be notified — no notification, no last-seen. This just clears a slot for your next connection.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            FlowChips(reasons: reasons, selected: reason) { reason = $0 }

            if let remaining = appState.rematchCreditsRemaining {
                Text(appState.rematchUnlimited ? "Unlimited fresh starts with Pro." : "\(remaining) free rematches remaining.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            }

            Spacer(minLength: 20)

            PrimaryButton(title: "End this connection", isLoading: appState.isBusy) {
                Task { await appState.confirmSoftExit(matchId: matchId, reason: reason) }
            }
            SecondaryLink(title: "Never mind") { appState.openChat(matchId) }
        }
    }
}

private struct FlowChips: View {
    let reasons: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            ForEach(reasons, id: \.self) { reason in
                SelectableChip(text: reason, selected: selected == reason) { onSelect(reason) }
            }
        }
    }
}
