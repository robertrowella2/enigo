import Foundation
import Supabase

/// Thin wrapper around the Supabase client: auth, the profiles table, and
/// the four edge functions that implement the core mechanic (find-match,
/// send-message, get-match-state — see backend/supabase/functions). A
/// client never talks to match_counters/unlock_thresholds directly; those
/// have no grant at all, by design.
@MainActor
final class Backend: ObservableObject {
    static let shared = Backend()

    /// Enigo's cloud Supabase project. (Previously pointed at the local
    /// `supabase start` dev stack at 127.0.0.1 — swap back to that for
    /// local-only testing.)
    ///
    /// The SDK's default PostgREST encoder/decoder do NOT convert between
    /// Swift's camelCase and Postgres's snake_case column names (unlike the
    /// Auth client's decoder) — so a custom encoder/decoder pair is
    /// required here, or every table struct would need explicit CodingKeys.
    private let client = SupabaseClient(
        supabaseURL: URL(string: "https://szeiboavzjuembdwajfu.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZWlib2F2emp1ZW1iZHdhamZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczNTgzOTAsImV4cCI6MjEwMjkzNDM5MH0.3xMA02t-LVccJh4RYUL4I3ITBf4XiqUMKpXXebqUh5U",
        options: .init(db: .init(encoder: Backend.makeEncoder(), decoder: Backend.makeDecoder()))
    )

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            for options: ISO8601DateFormatter.Options in [
                [.withInternetDateTime, .withFractionalSeconds],
                [.withInternetDateTime],
            ] {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = options
                if let date = formatter.date(from: string) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }

    @Published var userId: UUID?

    private init() {
        Task {
            for await (event, session) in client.auth.authStateChanges {
                _ = event
                userId = session?.user.id
            }
        }
    }

    // MARK: - Auth (phone OTP — matches the design's "no passwords" model)

    func requestOTP(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    func verifyOTP(phone: String, code: String) async throws {
        try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
        userId = try await client.auth.session.user.id
    }

    /// Moves the signed-in account onto a new number. Nothing in the database
    /// is keyed on the phone — profiles.id is the auth user's UUID — so the
    /// account, its matches and its subscription all survive untouched; only
    /// the sign-in credential moves. Texts a code to the new number, which
    /// `confirmPhoneChange` then redeems.
    func requestPhoneChange(newPhone: String) async throws {
        try await client.auth.update(user: UserAttributes(phone: newPhone))
    }

    func confirmPhoneChange(newPhone: String, code: String) async throws {
        try await client.auth.verifyOTP(phone: newPhone, token: code, type: .phoneChange)
    }

    /// The number currently on the account, for display.
    func currentPhone() async throws -> String? {
        try await client.auth.session.user.phone
    }

    // MARK: - Recovery email

    /// A second way in, for the case `requestPhoneChange` can't help: the
    /// number is already gone. Adding an email as a linked identity means the
    /// account can be reached without the phone at all. Texts nothing — a
    /// confirmation code goes to the address, redeemed by
    /// `confirmRecoveryEmail`.
    func setRecoveryEmail(_ email: String) async throws {
        try await client.auth.update(user: UserAttributes(email: email))
    }

    /// `.emailChange` is the right type even when no email was set before:
    /// GoTrue treats nil -> address as a change, and issues the code against
    /// that flow rather than `.signup`.
    func confirmRecoveryEmail(_ email: String, code: String) async throws {
        try await client.auth.verifyOTP(email: email, token: code, type: .emailChange)
    }

    /// Only ever nil-or-confirmed: an address awaiting confirmation lives in
    /// `new_email` server-side, so this reflects what can actually be signed
    /// in with rather than what someone typed.
    func currentEmail() async throws -> String? {
        let email = try await client.auth.session.user.email
        return (email?.isEmpty ?? true) ? nil : email
    }

    /// Signing in when the phone is gone. `shouldCreateUser: false` matters —
    /// without it a typo'd address silently creates a brand new empty account
    /// instead of reporting that no account uses that email.
    func requestEmailSignIn(_ email: String) async throws {
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: false)
    }

    func verifyEmailSignIn(_ email: String, code: String) async throws {
        try await client.auth.verifyOTP(email: email, token: code, type: .magiclink)
        userId = try await client.auth.session.user.id
    }

    // MARK: - Profile (onboarding)

    func fetchOwnProfile() async throws -> OwnProfile? {
        guard let userId else { return nil }
        let rows: [OwnProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        return rows.first
    }

    func upsertProfile(_ profile: OnboardingProfile) async throws {
        try await client.from("profiles").upsert(profile).execute()
    }

    func patchProfile(_ patch: ProfilePatch) async throws {
        guard let userId else { throw BackendError.notSignedIn }
        try await client.from("profiles").update(patch).eq("id", value: userId.uuidString).execute()
    }

    func uploadPhoto(data: Data, fileName: String) async throws -> String {
        guard let userId else { throw BackendError.notSignedIn }
        // Postgres's auth.uid()::text is lowercase; Swift's UUID.uuidString is
        // uppercase. The storage RLS policy compares the path's folder name
        // against auth.uid(), so this must be lowercased or every upload is
        // silently denied.
        let path = "\(userId.uuidString.lowercased())/\(fileName)"
        try await client.storage.from("photos").upload(path, data: data, options: .init(upsert: true))
        return path
    }

    /// The `photos` bucket is private — unlike a partner's photo (only
    /// revealed via get-match-state's signed URL once unlocked), the owner
    /// can always read their own via the "photos: owner can read own"
    /// storage policy, so this goes straight to Storage, no edge function.
    func ownPhotoURL(path: String) async throws -> URL {
        try await client.storage.from("photos").createSignedURL(path: path, expiresIn: 300)
    }

    // MARK: - Matching / chat mechanic

    func findMatch() async throws -> FindMatchResponse {
        try await client.functions.invoke("find-match", options: .init(body: EmptyBody()))
    }

    func sendMessage(matchId: UUID, body: String, clientMessageId: UUID, gifUrl: String? = nil, photoUrl: String? = nil) async throws {
        try await client.functions.invoke(
            "send-message",
            options: .init(body: SendMessageBody(matchId: matchId, body: body, clientMessageId: clientMessageId, gifUrl: gifUrl, photoUrl: photoUrl))
        )
    }

    func getMatchState(matchId: UUID) async throws -> MatchStateResponse {
        try await client.functions.invoke(
            "get-match-state",
            options: .init(body: MatchIdBody(matchId: matchId))
        )
    }

    /// Polled every few seconds by ChatViewModel. A later pass can replace
    /// this with a Realtime subscription on `messages`/`unlocks`.
    func listMessages(matchId: UUID) async throws -> [ChatMessage] {
        try await client
            .from("messages")
            .select()
            .eq("match_id", value: matchId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// All of the caller's currently-active matches (for the connections
    /// dashboard) — a direct RLS-scoped table read, not an edge function.
    func listActiveMatchIds() async throws -> [UUID] {
        struct Row: Decodable { var id: UUID }
        let rows: [Row] = try await client
            .from("matches")
            .select("id")
            .eq("status", value: "active")
            .execute()
            .value
        return rows.map(\.id)
    }

    // MARK: - Report / soft-exit

    func endMatch(matchId: UUID, reason: String?) async throws -> EndMatchResponse {
        try await client.functions.invoke("end-match", options: .init(body: EndMatchBody(matchId: matchId, reason: reason)))
    }

    func submitReport(matchId: UUID, category: String, detail: String?) async throws {
        try await client.functions.invoke(
            "submit-report",
            options: .init(body: ReportBody(matchId: matchId, category: category, detail: detail))
        )
    }

    func submitFeedback(message: String) async throws {
        try await client.functions.invoke(
            "submit-feedback",
            options: .init(body: FeedbackBody(message: message))
        )
    }

    // MARK: - Pro / subscription

    func getSubscriptionStatus() async throws -> SubscriptionStatus {
        guard let userId else { throw BackendError.notSignedIn }
        let rows: [SubscriptionStatus] = try await client
            .from("subscriptions")
            .select("tier, status")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.first ?? SubscriptionStatus(tier: "free", status: "active")
    }

    func recordPurchase(productId: String, transactionId: String, currentPeriodEnd: Date?) async throws {
        try await client.functions.invoke(
            "record-purchase",
            options: .init(body: PurchaseBody(
                platform: "ios", productId: productId, transactionId: transactionId,
                currentPeriodEnd: currentPeriodEnd.map { ISO8601DateFormatter().string(from: $0) }
            ))
        )
    }

    func redeemBoost(productId: String, transactionId: String) async throws {
        try await client.functions.invoke(
            "redeem-boost",
            options: .init(body: PurchaseBody(platform: "ios", productId: productId, transactionId: transactionId, currentPeriodEnd: nil))
        )
    }

    // MARK: - Account

    func exportAccountData() async throws -> Data {
        try await client.functions.invoke("export-account-data", options: .init(body: EmptyBody())) { data, _ in data }
    }

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account", options: .init(body: EmptyBody()))
        try await client.auth.signOut()
        userId = nil
    }

    func signOut() async throws {
        try await client.auth.signOut()
        userId = nil
    }

    // MARK: - Push

    func registerDeviceToken(token: String) async throws {
        try await client.functions.invoke("register-device-token", options: .init(body: DeviceTokenBody(platform: "ios", token: token)))
    }

    /// Edge functions return `{ message, code }` on a non-2xx response (see
    /// e.g. send-message's content-blocked rejection) — this pulls that
    /// message out of the raw error so the UI can show it instead of a
    /// generic "non-2xx status code" string.
    static func friendlyMessage(from error: Error) -> String {
        if case let FunctionsError.httpError(_, data) = error,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return error.localizedDescription
    }
}

enum BackendError: Error, LocalizedError {
    case notSignedIn
    case purchaseUnverified

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Not signed in"
        case .purchaseUnverified: "Apple couldn't verify that purchase"
        }
    }
}

private struct EmptyBody: Encodable {}
private struct SendMessageBody: Encodable {
    var matchId: UUID
    var body: String
    var clientMessageId: UUID
    var gifUrl: String?
    var photoUrl: String?
}
private struct MatchIdBody: Encodable {
    var matchId: UUID
}
private struct EndMatchBody: Encodable {
    var matchId: UUID
    var reason: String?
}
private struct DeviceTokenBody: Encodable {
    var platform: String
    var token: String
}
private struct ReportBody: Encodable {
    var matchId: UUID
    var category: String
    var detail: String?
}
private struct FeedbackBody: Encodable {
    var message: String
}
private struct PurchaseBody: Encodable {
    var platform: String
    var productId: String
    var transactionId: String
    var currentPeriodEnd: String?
}
