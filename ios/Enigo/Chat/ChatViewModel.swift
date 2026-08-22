import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var matchState: MatchStateResponse?
    @Published var draft: String = ""
    @Published var isSending = false
    @Published var celebrationField: UnlockField?
    @Published var showKnownSheet = false
    @Published var errorMessage: String?

    private var matchId: UUID?
    private var pollTask: Task<Void, Never>?
    private var previouslyUnlocked: Set<String> = []
    private let backend = Backend.shared

    /// Called when a background find-match check discovers this match is no
    /// longer active (typically an AI-bootstrapped slot upgraded to a real
    /// match, see backend/supabase/functions/find-match) — sends the user
    /// back to the dashboard, which will show whatever replaced it.
    var onMatchEnded: (() -> Void)?

    func configure(matchId: UUID) {
        guard self.matchId != matchId else { return }
        self.matchId = matchId
        messages = []
        matchState = nil
        previouslyUnlocked = []
        startPolling()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func refresh() async {
        guard let matchId else { return }
        if let upgrade = try? await backend.findMatch(), !upgrade.matchIds.contains(matchId) {
            onMatchEnded?()
            return
        }
        if let newMessages = try? await backend.listMessages(matchId: matchId) {
            messages = newMessages
        }
        if let state = try? await backend.getMatchState(matchId: matchId) {
            let newlyUnlocked = Set(state.unlocked).subtracting(previouslyUnlocked)
            matchState = state
            if let firstNew = UnlockField.allCases.first(where: { newlyUnlocked.contains($0.rawValue) }) {
                celebrationField = firstNew
            }
            previouslyUnlocked = Set(state.unlocked)
        }
    }

    func send() {
        guard let matchId, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft
        isSending = true
        Task {
            do {
                try await backend.sendMessage(matchId: matchId, body: text)
                draft = ""
                await refresh()
            } catch {
                // Leave the draft in place — e.g. a blocked message (phone
                // number, photo link) shouldn't force the user to retype it.
                errorMessage = Backend.friendlyMessage(from: error)
            }
            isSending = false
        }
    }

    deinit {
        pollTask?.cancel()
    }
}
