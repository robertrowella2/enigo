import SwiftUI

/// Simple line-art illustrations for the four intro slides, replacing the
/// original text placeholders ("NO FACES", "ELEVEN ANSWERS", etc.) with
/// something that actually looks intentional. Kept as vector shapes (not
/// raster images) so they stay crisp and theme-aware, matching the same
/// gold-line-on-navy language as the app icon.
struct IntroArtwork: View {
    @Environment(\.colorScheme) private var scheme
    let kind: String

    var body: some View {
        let color = EnigoColor.accent(scheme)
        Group {
            switch kind {
            case "NO FACES":
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: 84, height: 84)
            case "ELEVEN ANSWERS":
                elevenDots(color)
            case "SEALED ENVELOPE":
                envelope(color)
            case "SLOW LIGHT":
                slowLight(color)
            default:
                EmptyView()
            }
        }
    }

    private func elevenDots(_ color: Color) -> some View {
        let columns = Array(repeating: GridItem(.fixed(14), spacing: 10), count: 4)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<11, id: \.self) { _ in
                Circle().fill(color).frame(width: 8, height: 8)
            }
        }
        .frame(width: 86)
    }

    private func envelope(_ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(color, lineWidth: 3)
                .frame(width: 100, height: 68)
            Path { path in
                path.move(to: CGPoint(x: -50, y: -34))
                path.addLine(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 50, y: -34))
            }
            .stroke(color, lineWidth: 3)
        }
    }

    private func slowLight(_ color: Color) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: 2).frame(width: 100, height: 100)
            Circle().stroke(color.opacity(0.5), lineWidth: 2).frame(width: 68, height: 68)
            Circle().fill(color).frame(width: 20, height: 20)
        }
    }
}
