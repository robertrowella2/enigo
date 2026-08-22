import SwiftUI
import PhotosUI

struct PhotoView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        EnigoScreen {
            Eyebrow(text: "Photo · step 1 of 3")
            ScreenTitle(text: "Add a photo nobody sees yet")
            Text("It stays completely private until graduation — the very last thing that unlocks.")
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            PhotosPicker(selection: $pickerItem, matching: .images) {
                RoundedRectangle(cornerRadius: EnigoRadius.photoWell)
                    .strokeBorder(EnigoColor.fgAlpha(scheme, 0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .frame(height: 196)
                    .overlay {
                        if let data = appState.photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: EnigoRadius.photoWell))
                        } else {
                            VStack(spacing: 6) {
                                Text("SEALED")
                                    .font(EnigoFont.eyebrow)
                                    .tracking(2)
                                Text("Tap to choose a photo")
                                    .font(EnigoFont.body)
                            }
                            .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.45))
                        }
                    }
            }
            .onChange(of: pickerItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        appState.photoData = data
                        appState.photoFileName = "photo.jpg"
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Hidden until graduation. Always.")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.accent(scheme))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EnigoRadius.control).fill(EnigoColor.goldAlpha(scheme, 0.08)))

            Spacer(minLength: 20)

            PrimaryButton(title: appState.photoData == nil ? "Skip for now" : "Continue") {
                appState.submitPhoto()
            }
        }
    }
}
