import SwiftUI

struct IntroView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let slideIndex: Int

    var body: some View {
        let slide = ContentData.introSlides[slideIndex]
        EnigoScreen(topPadding: 96) {
            Spacer(minLength: 40)
            RoundedRectangle(cornerRadius: EnigoRadius.card)
                .fill(EnigoColor.fgAlpha(scheme, 0.06))
                // Half the display sideways at 210; the title and button
                // belong above the fold more than the artwork does.
                .frame(height: verticalSizeClass == .compact ? 120 : 210)
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
                // Straight to sign-in, past the three remaining intro slides.
                // Verifying a number that already has a profile lands on the
                // dashboard (AppState.submitVerify), and the phone step offers
                // email sign-in for a lost number — so this is the whole
                // returning-user path. The action was empty until now.
                SecondaryLink(title: "I already have an account") { appState.step = .phone }
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
