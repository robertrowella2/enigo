import SwiftUI

struct ChatView: View {
    let matchId: UUID
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @StateObject private var vm = ChatViewModel()
    @State private var showGifPicker = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if vm.messages.isEmpty {
                            Text("You know each other's usernames. Everything else arrives in its own time.")
                                .font(EnigoFont.meta)
                                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                                .padding(.top, 24)
                        }
                        ForEach(vm.messages) { message in
                            let isMine = message.senderId == Backend.shared.userId
                            MessageBubble(message: message, isMine: isMine)
                                .id(message.id)
                            if isMine, message.id == lastMineId, isReadByPartner(message) {
                                Text("Read")
                                    .font(EnigoFont.meta)
                                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.4))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.horizontal, EnigoSpacing.listHorizontal)
                    .padding(.top, 16)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(EnigoColor.background(scheme).ignoresSafeArea())
        .foregroundStyle(EnigoColor.body(scheme))
        .task {
            // Guard against a stale poll from an outdated ChatViewModel
            // state (see ChatViewModel.refresh) ever navigating away from
            // whatever chat the user is actually looking at right now.
            vm.onMatchEnded = {
                if appState.step == .chat(matchId) {
                    appState.openDashboard()
                }
            }
            vm.configure(matchId: matchId)
        }
        .sheet(isPresented: $vm.showKnownSheet) {
            KnownSheetView(
                state: vm.matchState,
                onReport: { appState.openReport(matchId) },
                onSoftExit: { appState.openSoftExit(matchId) }
            )
        }
        .overlay {
            if let field = vm.celebrationField {
                UnlockCelebrationView(field: field) { vm.celebrationField = nil }
            }
        }
        .alert("Message not sent", isPresented: .constant(vm.errorMessage != nil), actions: {
            Button("OK") { vm.errorMessage = nil }
        }, message: {
            Text(vm.errorMessage ?? "")
        })
        .sheet(isPresented: $showGifPicker) {
            GifPickerView { url in
                vm.sendGif(url: url)
            }
        }
    }

    private var lastMineId: UUID? {
        vm.messages.last(where: { $0.senderId == Backend.shared.userId })?.id
    }

    private func isReadByPartner(_ message: ChatMessage) -> Bool {
        guard let raw = vm.matchState?.partnerReadAt else { return false }
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
        ] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let readAt = formatter.date(from: raw) {
                return message.createdAt <= readAt
            }
        }
        return false
    }

    private var header: some View {
        HStack {
            Button(action: { appState.openDashboard() }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(EnigoColor.body(scheme))
            }
            .padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(vm.matchState?.partnerUsername ?? "…")")
                    .font(EnigoFont.fraunces(size: 19, weight: 600))
                Text("\(vm.messages.filter { !$0.isSystem }.count) messages")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
            }
            Spacer()
            Button("Known") { vm.showKnownSheet = true }
                .font(EnigoFont.chipLabel)
                .foregroundStyle(EnigoColor.accent(scheme))
        }
        .padding(.horizontal, EnigoSpacing.listHorizontal)
        .padding(.top, 58)
        .padding(.bottom, 12)
        .background(EnigoColor.sheetBase(scheme))
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Type something real...", text: $vm.draft, axis: .vertical)
                .id(vm.sendGeneration)
                .font(EnigoFont.chatMessage)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            Button(action: { showGifPicker = true }) {
                Image(systemName: "smiley")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(.white.opacity(0.3)))
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(EnigoColor.body(scheme))
            }
            Button(action: vm.send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(EnigoColor.primaryFill(scheme)))
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: EnigoColor.primaryFill(scheme).opacity(0.3), radius: 6, x: 0, y: 2)
                    .foregroundStyle(EnigoColor.primaryLabel(scheme))
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSending)
        }
        .padding(EnigoSpacing.listHorizontal)
    }
}

private struct MessageBubble: View {
    @Environment(\.colorScheme) private var scheme
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        if message.isSystem {
            Text(message.body)
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack {
                if isMine { Spacer(minLength: 40) }
                VStack(alignment: .leading, spacing: 0) {
                    if !message.body.isEmpty {
                        Text(message.body)
                            .font(EnigoFont.chatMessage)
                            .padding(12)
                    }
                    if let gifUrl = message.gifUrl {
                        AsyncImage(url: URL(string: gifUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 200)
                            case .failure:
                                Image(systemName: "photo.fill")
                                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.3))
                                    .frame(height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(8)
                    }
                    if let photoUrl = message.photoUrl {
                        AsyncImage(url: URL(string: photoUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: 200, maxHeight: 200)
                                    .clipped()
                                    .cornerRadius(EnigoRadius.input)
                            case .failure:
                                Image(systemName: "photo.fill")
                                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.3))
                                    .frame(height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(8)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isMine ? EnigoColor.goldAlpha(scheme, 0.16) : .white.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                if !isMine { Spacer(minLength: 40) }
            }
        }
    }
}
