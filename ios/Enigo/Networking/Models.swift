import Foundation

// Mirrors backend/supabase/migrations/20260101000000_schema.sql. Field names
// are snake_case to match Postgres/PostgREST directly via `keyDecodingStrategy
// = .convertFromSnakeCase` (set once on the shared decoder/encoder).

struct OnboardingProfile: Encodable {
    var id: UUID
    var username: String
    var gender: String?
    var genderSelfDescription: String?
    var matchWith: [String]
    var shownTo: [String]
    var community: String?
    var intent: String?
    var interests: [String]
    var bio: String?
    var photoPath: String?
    var lat: Double?
    var lng: Double?
    var radiusKm: Int?
    var locationGranted: Bool
    var answers: [String: Int]
    var onboardingComplete: Bool
}

struct FindMatchResponse: Decodable {
    var matchIds: [UUID]
    var searching: Bool
}

struct EndMatchResponse: Decodable {
    var ok: Bool
    var rematchCreditsRemaining: Int
    var unlimited: Bool
}

struct SubscriptionStatus: Decodable {
    var tier: String
    var status: String
    var isPro: Bool { tier == "pro" && status == "active" }
}

struct AccountExport: Decodable {
    var exportedAt: String
    // The full payload is richer than this; the client only needs to hand
    // it off as a file, not parse every field.
}

struct MatchStateResponse: Decodable {
    var matchId: UUID
    var status: String
    var partnerUsername: String
    var partnerFirstName: String?
    var unlocked: [String]
    var interests: [String]?
    var bio: String?
    var distanceKm: Int?
    var photoUrl: String?
    // Raw ISO8601 string, not Date — this response is decoded by the
    // Supabase client's Functions invoker, which (unlike the `db` client)
    // doesn't use Backend's custom ISO8601 date-decoding strategy, so a
    // Date field here fails with "Expected value of type Double". Parsed
    // on demand in ChatView instead.
    var partnerReadAt: String?

    var isGraduated: Bool { unlocked.contains("photo") }
}

struct ChatMessage: Decodable, Identifiable {
    var id: UUID
    var matchId: UUID
    var senderId: UUID?
    var body: String
    var isHeavy: Bool
    var isSystem: Bool
    var createdAt: Date
}

/// Own profile, as read back for Settings/Profile screens.
struct OwnProfile: Decodable {
    var username: String
    var firstName: String?
    var showFirstName: Bool
    var gender: String?
    var matchWith: [String]
    var shownTo: [String]
    var community: String?
    var interests: [String]
    var bio: String?
    var photoPath: String?
    var radiusKm: Int?
    var locationGranted: Bool
    var notifyMessages: Bool
    var notifyUnlocks: Bool
    var rematchCredits: Int
}

/// Partial update to the profile row — Settings screens only ever patch a
/// few fields at a time via Postgres `update`, not a full re-upsert.
struct ProfilePatch: Encodable {
    var showFirstName: Bool?
    var firstName: String?
    var matchWith: [String]?
    var shownTo: [String]?
    var community: String?
    var radiusKm: Int?
    var locationGranted: Bool?
    var notifyMessages: Bool?
    var notifyUnlocks: Bool?
}

/// The five "Known" sheet fields, in fixed unlock order.
enum UnlockField: String, CaseIterable {
    case interests, bio, location, photo
}
