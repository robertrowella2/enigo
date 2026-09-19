import SwiftUI

/// The Enigo mark — the eclipse from the app icon. Same geometry as the
/// LaunchMark image asset (a 100-unit box: ring at (60, 44) r24 stroke 6,
/// disc at (46, 56) r22), so the static system launch frame and the first
/// SwiftUI frame line up exactly. Navy on the light background, gold on
/// the dark one — the inverse of the icon, which is how the icon variants
/// already work.
struct EclipseMark: View {
    @Environment(\.colorScheme) private var scheme
    var size: CGFloat = 96

    var body: some View {
        let u = size / 100
        ZStack {
            Circle()
                .stroke(EnigoColor.dominant(scheme), lineWidth: 6 * u)
                .frame(width: 48 * u, height: 48 * u)
                .position(x: 60 * u, y: 44 * u)
            Circle()
                .fill(EnigoColor.dominant(scheme))
                .frame(width: 44 * u, height: 44 * u)
                .position(x: 46 * u, y: 56 * u)
        }
        .frame(width: size, height: size)
    }
}
