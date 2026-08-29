import SwiftUI

struct SearchingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var breathing = false

    var body: some View {
        EnigoScreen {
            // This screen had no navigation of any kind. Searching can go on
            // for as long as nobody matches the caller's preferences — and an
            // empty dashboard routes straight back here — so anyone in that
            // position was stuck with no route to settings, their profile, or
            // account deletion, short of deleting the app.
            HStack {
                Spacer()
                Button(action: { appState.openSettings() }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(EnigoColor.body(scheme))
                }
                Button(action: { appState.openProfile() }) {
                    ProfileAvatar(url: appState.ownPhotoURL, size: 28)
                }
            }

            Spacer(minLength: 80)
            ZStack {
                Circle()
                    .stroke(EnigoColor.accent(scheme).opacity(0.25), lineWidth: 1.5)
                    .frame(width: breathing ? 180 : 140, height: breathing ? 180 : 140)
                Circle()
                    .stroke(EnigoColor.accent(scheme).opacity(0.4), lineWidth: 1.5)
                    .frame(width: breathing ? 130 : 100, height: breathing ? 130 : 100)
                Image(systemName: "diamond.fill")
                    .foregroundStyle(EnigoColor.accent(scheme))
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(EnigoMotion.breathe) { breathing = true }
            }

            Text("Looking for one good match")
                .font(EnigoFont.screenTitle)
                .foregroundStyle(EnigoColor.dominant(scheme))
                .frame(maxWidth: .infinity, alignment: .center)

            Text("This can take a day or two. We'll let you know the moment it's ready.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            // Waiting a long time usually means the preferences are too
            // narrow for who is currently around, and that is exactly when
            // someone needs to be able to reach them.
            SecondaryLink(title: "Adjust your matching settings") {
                appState.openSettings()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
        }
    }
}
