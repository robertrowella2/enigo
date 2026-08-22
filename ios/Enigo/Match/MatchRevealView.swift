import SwiftUI

struct MatchRevealView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var partnerUsername: String?

    var body: some View {
        EnigoScreen {
            Spacer(minLength: 40)

            ZStack {
                RoundedRectangle(cornerRadius: 999)
                    .fill(EnigoColor.fgAlpha(scheme, 0.08))
                    .frame(width: 96, height: 96)
                if let username = partnerUsername {
                    Text(String(username.first ?? "?").uppercased())
                        .font(EnigoFont.fraunces(size: 34, weight: 600))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("@\(partnerUsername ?? "…")")
                .font(EnigoFont.matchUsername)
                .foregroundStyle(EnigoColor.dominant(scheme))
                .frame(maxWidth: .infinity, alignment: .center)

            Text("That's everything you get for now. No photo, no name, no city.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Why you two")
                Text("You answered the eleven questions closely enough to matter.")
                    .font(EnigoFont.body)
                Text("She's the closest strong match inside your radius.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: EnigoRadius.card).fill(EnigoColor.fgAlpha(scheme, 0.05)))

            Spacer(minLength: 20)

            PrimaryButton(title: "Start the conversation") { appState.enterChat() }
            SecondaryLink(title: "Not right now") { appState.openDashboard() }
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .task {
            if let matchId = appState.revealedMatchId,
               let state = try? await Backend.shared.getMatchState(matchId: matchId) {
                partnerUsername = state.partnerUsername
            }
        }
    }
}
