import SwiftUI

/// Connections dashboard: up to 3 simultaneous matches (1 free / 3 Pro, see
/// backend find-match), sorted by however the backend returned them, each
/// with a four-stage unlock strip.
struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var rows: [MatchStateResponse] = []
    @State private var isLoadingRows = false

    var body: some View {
        EnigoScreen(topPadding: 70) {
            HStack {
                ScreenTitle(text: "Your connections")
                Spacer()
                Button(action: { appState.openSettings() }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(EnigoColor.body(scheme))
                }
                Button(action: { appState.openProfile() }) {
                    Image(systemName: "person.circle")
                        .foregroundStyle(EnigoColor.body(scheme))
                }
            }

            if rows.isEmpty && !isLoadingRows {
                Text("No active connections yet.")
                    .font(EnigoFont.body)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.6))
            }

            ForEach(rows, id: \.matchId) { row in
                ConnectionRow(state: row) { appState.openChat(row.matchId) }
            }

            Button(action: { Task { await appState.startNewConnection(); await loadRows() } }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Start a new connection").font(EnigoFont.chipLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: EnigoRadius.control)
                    .strokeBorder(EnigoColor.fgAlpha(scheme, 0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            )
            .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.6))

            if appState.subscriptionStatus?.isPro != true {
                Button(action: { appState.openPaywall() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Go Pro").font(EnigoFont.chipLabel)
                            Text("Three conversations at once, unlimited fresh starts.")
                                .font(EnigoFont.meta)
                                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .background(RoundedRectangle(cornerRadius: EnigoRadius.card).fill(EnigoColor.goldAlpha(scheme, 0.1)))
            }
        }
        .task {
            await appState.refreshDashboard()
            await appState.loadSubscriptionStatus()
            await loadRows()
        }
    }

    private func loadRows() async {
        isLoadingRows = true
        var newRows: [MatchStateResponse] = []
        for id in appState.activeMatchIds {
            if let state = try? await Backend.shared.getMatchState(matchId: id) {
                newRows.append(state)
            }
        }
        rows = newRows
        isLoadingRows = false
    }
}

private struct ConnectionRow: View {
    @Environment(\.colorScheme) private var scheme
    let state: MatchStateResponse
    let onTap: () -> Void

    private let stages = ["INTERESTS", "BIO", "PLACE", "PHOTO"]

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("@\(state.partnerUsername)")
                        .font(EnigoFont.fraunces(size: 18, weight: 600))
                        .foregroundStyle(EnigoColor.dominant(scheme))
                    Spacer()
                    if let km = state.distanceKm {
                        Text("~\(km) km")
                            .font(EnigoFont.meta)
                            .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                    }
                }
                HStack(spacing: 6) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { index, label in
                        let key = UnlockField.allCases[index].rawValue
                        let on = state.unlocked.contains(key)
                        Text(label)
                            .font(EnigoFont.meta)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(on ? EnigoColor.goldAlpha(scheme, 0.15) : EnigoColor.fgAlpha(scheme, 0.06)))
                            .foregroundStyle(on ? EnigoColor.accent(scheme) : EnigoColor.fgAlpha(scheme, 0.4))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EnigoRadius.card).fill(EnigoColor.fgAlpha(scheme, 0.05)))
        }
        .buttonStyle(.plain)
    }
}
