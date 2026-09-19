import SwiftUI

/// Shown from the first SwiftUI frame until bootstrap has decided where to
/// send someone — the dashboard for a returning account, onboarding for
/// everyone else. It reproduces the system launch frame exactly (same
/// background, same mark, same position) and only adds motion, so launch
/// reads as one continuous moment rather than a flash of the birthdate
/// screen for people who already have an account, which is what happened
/// before: `step` started at `.ageVerification` and jumped to the
/// dashboard a beat later.
struct LoadingView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var breathing = false

    var body: some View {
        ZStack {
            EnigoColor.background(scheme).ignoresSafeArea()
            EclipseMark()
                .scaleEffect(breathing ? 1.04 : 1.0)
                .opacity(breathing ? 1.0 : 0.88)
        }
        .onAppear {
            withAnimation(EnigoMotion.breathe) { breathing = true }
        }
    }
}
