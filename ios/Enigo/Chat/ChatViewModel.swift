import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var matchState: MatchStateResponse?
    /// Set only when a send fails, so the view can put the text back in the
    /// composer rather than making someone retype it. The draft itself lives
    /// in ChatView's own @State: this object republishes on every poll, and a
    /// TextField bound to it lost characters mid-typing as those updates
    /// landed. An earlier attempt bounced the field's `.id` to force a
    /// redraw, which destroyed in-progress text instead of fixing it.
    @Published var draftToRestore: String?
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
        if let upgrade = try? await backend.findMatch() {
            // Swift's task cancellation is cooperative: cancelling pollTask
            // doesn't abort an in-flight await, so a poll that was already
            // superseded (e.g. this view model got reconfigured for a new
            // match) can still resolve here after the fact. Bail out
            // silently rather than firing onMatchEnded for a match that's
            // no longer the one this instance is even polling for.
            guard !Task.isCancelled, self.matchId == matchId else { return }
            if !upgrade.matchIds.contains(matchId) {
                onMatchEnded?()
                return
            }
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

    func send(_ text: String) {
        guard let matchId, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true

        // Show it immediately rather than waiting on the round trip — for an
        // AI match that round trip includes the persona's own reply
        // generation, which can take a couple of seconds on its own. The
        // id is generated here and sent to the server as-is (see
        // clientMessageId), so the row that comes back from the next
        // refresh() has the *same* identity as this optimistic one instead
        // of a server-generated id — otherwise the list (keyed by id) sees
        // a real delete+insert and visibly flashes even though nothing
        // actually changed from the user's point of view.
        let messageId = UUID()
        let optimistic = ChatMessage(
            id: messageId, matchId: matchId, senderId: backend.userId,
            body: text, isHeavy: false, isSystem: false, createdAt: Date()
        )
        messages.append(optimistic)

        Task {
            do {
                try await backend.sendMessage(matchId: matchId, body: text, clientMessageId: messageId)
                await refresh()
            } catch {
                // Roll back the optimistic bubble and restore the draft —
                // e.g. a blocked message (phone number, photo link) shouldn't
                // look like it sent, and shouldn't force the user to retype it.
                messages.removeAll { $0.id == optimistic.id }
                draftToRestore = text
                errorMessage = Backend.friendlyMessage(from: error)
            }
            isSending = false
        }
    }

    func sendGif(url: String) {
        guard let matchId else { return }
        isSending = true

        let messageId = UUID()
        let optimistic = ChatMessage(
            id: messageId, matchId: matchId, senderId: backend.userId,
            body: "", isHeavy: false, isSystem: false, createdAt: Date(),
            gifUrl: url, photoUrl: nil
        )
        messages.append(optimistic)

        Task {
            do {
                try await backend.sendMessage(matchId: matchId, body: "", clientMessageId: messageId, gifUrl: url)
                await refresh()
            } catch {
                messages.removeAll { $0.id == optimistic.id }
                errorMessage = Backend.friendlyMessage(from: error)
            }
            isSending = false
        }
    }

    deinit {
        pollTask?.cancel()
    }
}
