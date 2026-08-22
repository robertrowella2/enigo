import SwiftUI

struct IntroView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    let slideIndex: Int

    var body: some View {
        let slide = ContentData.introSlides[slideIndex]
        EnigoScreen(topPadding: 96) {
            Spacer(minLength: 40)
            RoundedRectangle(cornerRadius: EnigoRadius.card)
                .fill(EnigoColor.fgAlpha(scheme, 0.06))
                .frame(height: 210)
                .overlay(IntroArtwork(kind: slide.art))

            Text(slide.title)
                .font(EnigoFont.fraunces(size: 33, weight: 600))
                .foregroundStyle(EnigoColor.dominant(scheme))
                .padding(.top, 12)

            Text(slide.body)
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.62))

            ProgressDots(count: ContentData.introSlides.count, index: slideIndex)
                .padding(.top, 8)

            Spacer(minLength: 20)

            PrimaryButton(title: slide.cta) { appState.advanceIntro() }

            if slideIndex == 0 {
                SecondaryLink(title: "I already have an account") {}
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
