import SwiftUI

struct KnownSheetView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let state: MatchStateResponse?
    let onReport: () -> Void
    let onSoftExit: () -> Void

    private var rows: [(String, String)] {
        guard let state else { return [] }
        let unlocked = Set(state.unlocked)
        return [
            ("INTERESTS", unlocked.contains("interests") ? (state.interests?.joined(separator: " · ") ?? "") : "Not yet"),
            ("BIO", unlocked.contains("bio") ? (state.bio ?? "") : "Not yet"),
            ("LOCATION", unlocked.contains("location") ? state.distanceKm.map { "~\($0) km away" } ?? "Not yet" : "Not yet"),
            ("PHOTO", unlocked.contains("photo") ? "Revealed" : "Not yet"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EnigoSpacing.stackGap) {
            Capsule()
                .fill(EnigoColor.fgAlpha(scheme, 0.2))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            Text("What you know so far")
                .font(EnigoFont.fraunces(size: 22, weight: 600))

            VStack(spacing: 10) {
                ForEach(rows, id: \.0) { label, value in
                    HStack(alignment: .top) {
                        Text(label)
                            .font(EnigoFont.eyebrow)
                            .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.45))
                            .frame(width: 90, alignment: .leading)
                        Text(value)
                            .font(EnigoFont.body)
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: EnigoRadius.control).fill(EnigoColor.fgAlpha(scheme, 0.05)))
                }
            }

            Text("Both of you have to keep showing up for the next one. We don't say how close it is — that's the point.")
                .font(EnigoFont.meta)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))

            Spacer(minLength: 8)

            Button("Report") { dismiss(); onReport() }
                .font(EnigoFont.chipLabel)
                .foregroundStyle(EnigoColor.danger(scheme))
            Button("This isn't quite it") { dismiss(); onSoftExit() }
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.6))
        }
        .padding(EnigoSpacing.screenHorizontal)
        .background(EnigoColor.sheetBase(scheme).ignoresSafeArea())
        .foregroundStyle(EnigoColor.body(scheme))
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(EnigoRadius.sheetTop)
    }
}
