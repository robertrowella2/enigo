import SwiftUI

struct UnlockCelebrationView: View {
    @Environment(\.colorScheme) private var scheme
    let field: UnlockField
    let onDismiss: () -> Void
    @State private var breathing = false

    private var badge: String {
        switch field {
        case .interests: "INTERESTS"
        case .bio: "BIO"
        case .location: "PLACE"
        case .photo: "PHOTO"
        }
    }

    private var note: String {
        switch field {
        case .interests: "The first real thing you've learned about each other."
        case .bio: "The only free-text thing they wrote in the whole app."
        case .location: "Rough area only. Never an address, never live location."
        case .photo: "You got here by showing up, both of you. Nothing was rushed."
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 18) {
                Circle()
                    .stroke(EnigoColor.accent(scheme), lineWidth: 1.5)
                    .frame(width: breathing ? 140 : 110, height: breathing ? 140 : 110)
                    .onAppear { withAnimation(EnigoMotion.breathe) { breathing = true } }

                Text("SOMETHING UNLOCKED")
                    .font(EnigoFont.eyebrow)
                    .tracking(3)
                    .foregroundStyle(EnigoColor.accent(scheme))

                Text(badge)
                    .font(EnigoFont.fraunces(size: 28, weight: 600))
                    .foregroundStyle(.white)

                Text(note)
                    .font(EnigoFont.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Continue", action: onDismiss)
                    .font(EnigoFont.chipLabel)
                    .foregroundStyle(EnigoColor.accent(scheme))
                    .padding(.top, 12)
            }
        }
        .transition(.opacity.animation(EnigoMotion.rise))
    }
}
