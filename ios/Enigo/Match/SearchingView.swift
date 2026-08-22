import SwiftUI

struct SearchingView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var breathing = false

    var body: some View {
        EnigoScreen {
            Spacer(minLength: 120)
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
        }
    }
}
