package com.enigo.app.data

import kotlinx.serialization.Serializable

// Mirrors backend/supabase/migrations/20260101000000_schema.sql. supabase-kt's
// Postgrest module converts camelCase<->snake_case by default
// (PropertyConversionMethod.CAMEL_CASE_TO_SNAKE_CASE), so no manual
// @SerialName mapping is needed here (unlike the iOS client, whose SDK does
// not do this automatically).

@Serializable
data class OnboardingProfile(
    val id: String,
    val username: String,
    val firstName: String,
    val lastName: String,
    val gender: String? = null,
    val genderSelfDescription: String? = null,
    val matchWith: List<String>,
    val shownTo: List<String>,
    val community: String? = null,
    val intent: String? = null,
    val interests: List<String>,
    val bio: String? = null,
    val photoPath: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val radiusKm: Int? = null,
    val locationGranted: Boolean,
    val answers: Map<String, Int>,
    val onboardingComplete: Boolean
)

@Serializable
data class FindMatchResponse(
    val matchIds: List<String> = emptyList(),
    val searching: Boolean = false
)

@Serializable
data class EndMatchResponse(
    val ok: Boolean = false,
    val rematchCreditsRemaining: Int = 0,
    val unlimited: Boolean = false
)

@Serializable
data class SubscriptionStatus(
    val tier: String = "free",
    val status: String = "active"
) {
    val isPro: Boolean get() = tier == "pro" && status == "active"
}

@Serializable
data class OwnProfile(
    val username: String,
    val firstName: String? = null,
    val showFirstName: Boolean = false,
    val gender: String? = null,
    val matchWith: List<String> = emptyList(),
    val shownTo: List<String> = emptyList(),
    val community: String? = null,
    val interests: List<String> = emptyList(),
    val bio: String? = null,
    val photoPath: String? = null,
    val radiusKm: Int? = null,
    val locationGranted: Boolean = false,
    val notifyMessages: Boolean = true,
    val notifyUnlocks: Boolean = true,
    val notifyMatches: Boolean = true,
    val rematchCredits: Int = 0
)

@Serializable
data class ProfilePatch(
    val showFirstName: Boolean? = null,
    val firstName: String? = null,
    val matchWith: List<String>? = null,
    val shownTo: List<String>? = null,
    val community: String? = null,
    val radiusKm: Int? = null,
    val locationGranted: Boolean? = null,
    val notifyMessages: Boolean? = null,
    val notifyUnlocks: Boolean? = null,
    val notifyMatches: Boolean? = null
)

@Serializable
data class MatchStateResponse(
    val matchId: String,
    val status: String,
    val partnerUsername: String,
    val partnerFirstName: String? = null,
    val unlocked: List<String>,
    val interests: List<String>? = null,
    val bio: String? = null,
    val distanceKm: Int? = null,
    val photoUrl: String? = null,
    val partnerReadAt: String? = null
)

@Serializable
data class ChatMessage(
    val id: String,
    val matchId: String,
    val senderId: String? = null,
    val body: String,
    val isHeavy: Boolean = false,
    val isSystem: Boolean = false,
    val createdAt: String,
    val gifUrl: String? = null,
    val photoUrl: String? = null
)

enum class UnlockField(val key: String) {
    INTERESTS("interests"), BIO("bio"), LOCATION("location"), PHOTO("photo");
    companion object {
        val ORDER = listOf(INTERESTS, BIO, LOCATION, PHOTO)
        fun fromKey(key: String) = ORDER.firstOrNull { it.key == key }
    }
}
