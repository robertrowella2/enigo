import SwiftUI

/// Your GIPHY API key. Get one free at https://developers.giphy.com —
/// create an app, pick "API" (not SDK), and paste the key here. Like the
/// Supabase anon key above it, this is a public client-side credential.
/// While it's empty the picker says so rather than silently showing
/// "No GIFs found".
private let giphyAPIKey = "B2Hwd1gOrbsBWjRAH1JzaTFT5o3RUSiV"

struct GifPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var searchText = ""
    @State private var gifs: [GifResult] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
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
            // One request per keystroke would burn through the rate limit,
            // so each edit cancels the previous in-flight search and waits
            // for a pause in typing.
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                gifs = []
                error = nil
                isLoading = false
                return
            }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await searchGifs(newValue)
            }
        }
    }

    private func searchGifs(_ query: String) async {
        guard !giphyAPIKey.isEmpty else {
            error = "GIF search isn't set up yet — no GIPHY API key configured."
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://api.giphy.com/v1/gifs/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "api_key", value: giphyAPIKey),
            URLQueryItem(name: "limit", value: "20"),
        ]
        guard let url = components?.url else {
            error = "Invalid search URL"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }
            // GIPHY returns its errors as a 200-shaped body with an empty
            // `data` array, so decoding alone can't tell a bad key from a
            // query with no matches — the status code is the only signal.
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                error = http.statusCode == 401 || http.statusCode == 403
                    ? "GIPHY rejected the API key."
                    : "GIPHY returned an error (\(http.statusCode))."
                gifs = []
                return
            }
            gifs = try JSONDecoder().decode(GiphyResponse.self, from: data).data
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Couldn't load GIFs. Check your connection and try again."
            gifs = []
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
