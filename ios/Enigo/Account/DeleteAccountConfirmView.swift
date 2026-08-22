import SwiftUI

/// Delete account — irreversible, offers data export first, matches see the
/// conversation close without a reason.
struct DeleteAccountConfirmView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var exportFileURL: URL?
    @State private var confirmedUnderstanding = false

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openSettings() }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: "Delete account")
            Text("This is permanent. Your matches will see the conversation close without a reason — no notification, no explanation.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.danger(scheme))

            PrimaryButton(title: "Export my data first", isLoading: appState.isBusy) {
                Task {
                    await appState.exportAccountData()
                    if let data = appState.exportedData {
                        exportFileURL = writeToTempFile(data)
                    }
                }
            }
            if let exportFileURL {
                ShareLink(item: exportFileURL) {
                    Text("Save export").font(EnigoFont.chipLabel).foregroundStyle(EnigoColor.accent(scheme))
                }
            }

            Toggle(isOn: $confirmedUnderstanding) {
                Text("I understand this can't be undone.").font(EnigoFont.body)
            }
            .padding(.top, 12)

            Spacer(minLength: 20)

            PrimaryButton(title: "Delete my account", disabled: !confirmedUnderstanding, isLoading: appState.isBusy) {
                Task { await appState.deleteAccount() }
            }
            SecondaryLink(title: "Cancel") { appState.openSettings() }
        }
    }

    private func writeToTempFile(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("enigo-export-\(UUID().uuidString).json")
        do {
            try data.write(to: url)
            return url
        } catch {
            appState.errorMessage = error.localizedDescription
            return nil
        }
    }
}
