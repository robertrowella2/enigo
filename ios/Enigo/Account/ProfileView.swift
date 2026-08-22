import SwiftUI

/// "Own profile" — username prominent as the default identity, first-name
/// display as a toggle, interests/bio/location/photo rows, and a way back
/// into the eleven questions.
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openDashboard() }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }

            if let profile = appState.ownProfile {
                ProfileAvatar(url: appState.ownPhotoURL, size: 72)

                Text("@\(profile.username)")
                    .font(EnigoFont.matchUsername)
                    .foregroundStyle(EnigoColor.dominant(scheme))

                Toggle(isOn: Binding(
                    get: { profile.showFirstName },
                    set: { newValue in Task { await appState.patchProfile(ProfilePatch(showFirstName: newValue)) } }
                )) {
                    Text("Show first name alongside username").font(EnigoFont.body)
                }

                row(label: "INTERESTS", value: profile.interests.joined(separator: " · "))
                row(label: "BIO", value: profile.bio ?? "Not written yet")
                row(label: "LOCATION", value: profile.locationGranted ? "Shared, \(profile.radiusKm.map(String.init) ?? "Anywhere") km radius" : "Not shared")
                row(label: "PHOTO", value: profile.photoPath == nil ? "Not added" : "Added — hidden until graduation")

                SecondaryLink(title: "Retake the eleven questions") {
                    appState.answers = [:]
                    appState.step = .question(0)
                }
            } else {
                ProgressView()
            }
        }
        .task { await appState.loadOwnProfile() }
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(EnigoFont.eyebrow)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.45))
                .frame(width: 90, alignment: .leading)
            Text(value).font(EnigoFont.body)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: EnigoRadius.control).fill(EnigoColor.fgAlpha(scheme, 0.05)))
    }
}
