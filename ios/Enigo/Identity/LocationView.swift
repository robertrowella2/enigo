import SwiftUI

struct LocationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    private let radii: [Int?] = [25, 50, 100, nil]

    var body: some View {
        EnigoScreen {
            ScreenTitle(text: "Where are you?")
            Text("We sort matches by distance — the closest good one first. Your area stays sealed until it unlocks for them, and it's never an address.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            Toggle(isOn: Binding(
                get: { appState.locationGranted },
                set: { newValue in
                    if newValue {
                        Task { await appState.requestLocationPermission() }
                    } else {
                        appState.locationGranted = false
                        appState.locationCoordinate = nil
                    }
                }
            )) {
                Text("Share my rough location").font(EnigoFont.body)
            }
            .tint(EnigoColor.accent(scheme))

            HStack(spacing: 8) {
                ForEach(radii, id: \.self) { radius in
                    SelectableChip(text: radius.map { "\($0) km" } ?? "Anywhere", selected: appState.radiusKm == radius) {
                        appState.radiusKm = radius
                    }
                }
            }

            Spacer(minLength: 20)

            PrimaryButton(title: "Continue") { appState.submitLocation() }
        }
    }
}
