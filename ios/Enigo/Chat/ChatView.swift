import SwiftUI

struct ChatView: View {
    let matchId: UUID
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @StateObject private var vm = ChatViewModel()

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
                            MessageBubble(message: message, isMine: message.senderId == Backend.shared.userId)
                                .id(message.id)
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
            vm.onMatchEnded = { appState.openDashboard() }
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
                .font(EnigoFont.chatMessage)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.06)))
            Button(action: vm.send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(EnigoColor.primaryFill(scheme)))
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
                Text(message.body)
                    .font(EnigoFont.chatMessage)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: EnigoRadius.input)
                            .fill(isMine ? EnigoColor.goldAlpha(scheme, 0.14) : EnigoColor.fgAlpha(scheme, 0.06))
                    )
                if !isMine { Spacer(minLength: 40) }
            }
        }
    }
}
