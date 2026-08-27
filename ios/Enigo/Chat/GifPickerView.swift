import SwiftUI

struct GifPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var searchText = ""
    @State private var gifs: [GifResult] = []
    @State private var isLoading = false
    @State private var error: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search GIFs...", text: $searchText)
                    .font(EnigoFont.chatMessage)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: EnigoRadius.input).fill(EnigoColor.fgAlpha(scheme, 0.06)))
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(EnigoColor.body(scheme))
                }
            }
            .padding(EnigoSpacing.listHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error {
                VStack {
                    Spacer()
                    Text(error)
                        .font(EnigoFont.meta)
                        .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
            } else if gifs.isEmpty {
                VStack {
                    Spacer()
                    Text(searchText.isEmpty ? "Search for GIFs" : "No GIFs found")
                        .font(EnigoFont.meta)
                        .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(gifs, id: \.id) { gif in
                            GifThumbnail(gif: gif, onSelect: {
                                onSelect(gif.url)
                                dismiss()
                            })
                        }
                    }
                    .padding(EnigoSpacing.listHorizontal)
                }
            }
        }
        .background(EnigoColor.background(scheme).ignoresSafeArea())
        .foregroundStyle(EnigoColor.body(scheme))
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                gifs = []
                error = nil
            } else {
                Task { await searchGifs(newValue) }
            }
        }
    }

    private func searchGifs(_ query: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard !query.isEmpty else { return }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.giphy.com/v1/gifs/search?q=\(encoded)&api_key=o6MpAH4I1qU0EcsL2MlARVBbFJG7bNVN&limit=20"

        guard let url = URL(string: urlString) else {
            error = "Invalid search URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(GiphyResponse.self, from: data)
            await MainActor.run {
                self.gifs = response.data
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load GIFs"
            }
        }
    }
}

private struct GifThumbnail: View {
    @Environment(\.colorScheme) private var scheme
    let gif: GifResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            AsyncImage(url: URL(string: gif.images.fixedHeight.url)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .cornerRadius(EnigoRadius.input)
                case .failure:
                    Image(systemName: "photo.fill")
                        .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.3))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(EnigoColor.fgAlpha(scheme, 0.06))
                        .cornerRadius(EnigoRadius.input)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

struct GiphyResponse: Decodable {
    let data: [GifResult]
}

struct GifResult: Decodable {
    let id: String
    let images: GifImages

    var url: String {
        images.fixedHeight.url
    }
}

struct GifImages: Decodable {
    let fixedHeight: GifImage

    enum CodingKeys: String, CodingKey {
        case fixedHeight = "fixed_height"
    }
}

struct GifImage: Decodable {
    let url: String
}
