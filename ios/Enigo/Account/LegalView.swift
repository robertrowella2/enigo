import SwiftUI

/// Presented as a sheet from Settings and from the pre-account consent
/// links on PhoneView, so it doesn't need its own place in the linear
/// onboarding `Step` state machine — it can be dismissed back to wherever
/// it was opened from.
struct LegalView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: document.title)
            Text("Last updated \(LegalContent.lastUpdated)")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))

            ForEach(document.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: section.heading)
                    Text(section.body)
                        .font(EnigoFont.body)
                        .foregroundStyle(EnigoColor.body(scheme))
                }
                .padding(.top, 8)
            }
        }
    }
}
