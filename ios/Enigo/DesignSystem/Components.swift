import SwiftUI

/// Screen scaffold: theme background + horizontal padding + top safe area,
/// per the "Top padding is platform-dependent" token (iOS values).
struct EnigoScreen<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var topPadding: CGFloat = 76
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EnigoSpacing.stackGap) {
                content
            }
            .padding(.horizontal, EnigoSpacing.screenHorizontal)
            .padding(.top, topPadding)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EnigoColor.background(scheme).ignoresSafeArea())
        .foregroundStyle(EnigoColor.body(scheme))
    }
}

struct PrimaryButton: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var disabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView().tint(EnigoColor.primaryLabel(scheme))
                } else {
                    Text(title).font(EnigoFont.chipLabel)
                }
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: EnigoRadius.control)
                    .fill(disabled ? EnigoColor.fgAlpha(scheme, 0.12) : EnigoColor.primaryFill(scheme))
            )
            .foregroundStyle(disabled ? EnigoColor.fgAlpha(scheme, 0.4) : EnigoColor.primaryLabel(scheme))
        }
        .disabled(disabled || isLoading)
    }
}

struct SecondaryLink: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(EnigoFont.body)
                .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.6))
        }
    }
}

struct ScreenTitle: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text)
            .font(EnigoFont.screenTitle)
            .foregroundStyle(EnigoColor.dominant(scheme))
    }
}

struct Eyebrow: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(EnigoFont.eyebrow)
            .tracking(2)
            .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.4))
    }
}

/// A single tap-to-select answer/option row — Fraunces, per the doc's "all
/// tap-to-select answer options" rule so onboarding and the questions read
/// as one uniform typographic block.
struct SelectableRow: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(EnigoFont.answerOption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: EnigoRadius.control)
                        .fill(selected ? EnigoColor.goldAlpha(scheme, 0.12) : EnigoColor.fgAlpha(scheme, 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EnigoRadius.control)
                        .stroke(selected ? EnigoColor.accent(scheme).opacity(0.55) : EnigoColor.fgAlpha(scheme, 0.1), lineWidth: 1)
                )
                .foregroundStyle(selected ? EnigoColor.accent(scheme) : EnigoColor.body(scheme))
        }
    }
}

/// Multi-select chip used for interests/preferences grids.
struct SelectableChip: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(EnigoFont.chipLabel)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule().fill(selected ? EnigoColor.goldAlpha(scheme, 0.12) : EnigoColor.fgAlpha(scheme, 0.05))
                )
                .overlay(
                    Capsule().stroke(selected ? EnigoColor.accent(scheme).opacity(0.55) : EnigoColor.fgAlpha(scheme, 0.1), lineWidth: 1)
                )
                .foregroundStyle(selected ? EnigoColor.accent(scheme) : EnigoColor.body(scheme))
        }
    }
}

/// A user's own photo as a circular thumbnail, falling back to a generic
/// silhouette while it's loading or if none was ever added. `url` is a
/// short-lived signed URL (see Backend.ownPhotoURL) — never persisted, just
/// fetched fresh each time the screen that shows it appears.
struct ProfileAvatar: View {
    @Environment(\.colorScheme) private var scheme
    let url: URL?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Image(systemName: "person.circle")
            .resizable()
            .foregroundStyle(EnigoColor.body(scheme))
    }
}

struct ProgressDots: View {
    @Environment(\.colorScheme) private var scheme
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? EnigoColor.accent(scheme) : EnigoColor.fgAlpha(scheme, 0.16))
                    .frame(width: i == index ? 22 : 6, height: 6)
            }
        }
    }
}
