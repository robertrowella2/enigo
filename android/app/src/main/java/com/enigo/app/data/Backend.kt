package com.enigo.app.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import io.github.jan.supabase.storage.storage
import kotlin.time.Duration.Companion.minutes
import io.ktor.client.call.body
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Thin wrapper around the Supabase client: auth, the profiles table, and the
 * four edge functions that implement the core mechanic (find-match,
 * send-message, get-match-state — see backend/supabase/functions). A client
 * never talks to match_counters/unlock_thresholds directly; those have no
 * grant at all, by design.
 *
 * `PropertyConversionMethod.CAMEL_CASE_TO_SNAKE_CASE` (Postgrest's default)
 * only applies to KProperty-based filter/update DSL calls — NOT to whole
 * object encode/decode via upsert()/select().decodeList(), which just uses
 * plain kotlinx.serialization. So table structs still need an explicit
 * snake_case naming strategy on the Json instance below, or every property
 * would need its own @SerialName (learned the hard way — this exact gap
 * broke onboarding on first run).
 */
object Backend {
    // Enigo's cloud Supabase project. (Previously "http://10.0.2.2:54321" —
    // 10.0.2.2 is the Android emulator's alias for the host machine's
    // localhost — for pointing at a local `supabase start` dev stack.)
    private const val SUPABASE_URL = "https://szeiboavzjuembdwajfu.supabase.co"
    private const val ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZWlib2F2emp1ZW1iZHdhamZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczNTgzOTAsImV4cCI6MjEwMjkzNDM5MH0.3xMA02t-LVccJh4RYUL4I3ITBf4XiqUMKpXXebqUh5U"

    private val snakeCaseJson = Json {
        namingStrategy = JsonNamingStrategy.SnakeCase
        ignoreUnknownKeys = true
        // Without this, ProfilePatch's null fields would be encoded as
        // explicit JSON nulls and Postgrest's .update() would blank out
        // every column not being changed, instead of leaving them alone.
        explicitNulls = false
    }

    val client = createSupabaseClient(SUPABASE_URL, ANON_KEY) {
        install(Auth)
        install(Postgrest) {
            serializer = KotlinXSerializer(snakeCaseJson)
        }
        install(Storage)
        install(Functions)
    }

    private val _userId = MutableStateFlow<String?>(null)
    val userId: StateFlow<String?> = _userId

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    init {
        // supabase-kt persists the session on-device and re-emits it here on
        // cold start (mirrors iOS's Backend.swift, which does the same via
        // client.auth.authStateChanges) — without this, bootstrap() would
        // never see a signed-in user after an app restart.
        scope.launch {
            client.auth.sessionStatus.collect { status ->
                _userId.value = (status as? SessionStatus.Authenticated)?.session?.user?.id
            }
        }
    }

    suspend fun requestOtp(phone: String) {
        client.auth.signInWith(OTP) { this.phone = phone }
    }

    suspend fun verifyOtp(phone: String, code: String) {
        client.auth.verifyPhoneOtp(type = OtpType.Phone.SMS, phone = phone, token = code)
        _userId.value = client.auth.currentUserOrNull()?.id
    }

    suspend fun fetchOwnProfile(): OwnProfile? {
        val uid = _userId.value ?: return null
        return client.postgrest.from("profiles").select {
            filter { eq("id", uid) }
        }.decodeSingleOrNull()
    }

    suspend fun upsertProfile(profile: OnboardingProfile) {
        client.postgrest.from("profiles").upsert(profile)
    }

    suspend fun patchProfile(patch: ProfilePatch) {
        val uid = _userId.value ?: error("Not signed in")
        client.postgrest.from("profiles").update(patch) {
            filter { eq("id", uid) }
        }
    }

    suspend fun uploadPhoto(bytes: ByteArray, fileName: String): String {
        val uid = _userId.value ?: error("Not signed in")
        // Storage RLS compares the path's folder name against auth.uid()
        // (always lowercase); the Android auth id string is already
        // lowercase so no normalization is needed here (unlike iOS's
        // uppercase UUID.uuidString).
        val path = "$uid/$fileName"
        client.storage.from("photos").upload(path, bytes) { upsert = true }
        return path
    }

    /// The `photos` bucket is private — unlike a partner's photo (only
    /// revealed via get-match-state's signed URL once unlocked), the owner
    /// can always read their own via the "photos: owner can read own"
    /// storage policy, so this goes straight to Storage, no edge function.
    suspend fun ownPhotoURL(path: String): String =
        client.storage.from("photos").createSignedUrl(path, 5.minutes)

    @Serializable private data class SendMessageBody(
        val matchId: String,
        val body: String,
        val clientMessageId: String,
        val gifUrl: String? = null,
        val photoUrl: String? = null
    )
    @Serializable private data class MatchIdBody(val matchId: String)

    suspend fun findMatch(): FindMatchResponse =
        client.functions.invoke("find-match") {
            contentType(ContentType.Application.Json)
            setBody(emptyMap<String, String>())
        }.body()

    suspend fun sendMessage(matchId: String, body: String, clientMessageId: String, gifUrl: String? = null, photoUrl: String? = null) {
        client.functions.invoke("send-message") {
            contentType(ContentType.Application.Json)
            setBody(SendMessageBody(matchId, body, clientMessageId, gifUrl, photoUrl))
        }
    }

    suspend fun getMatchState(matchId: String): MatchStateResponse =
        client.functions.invoke("get-match-state") {
            contentType(ContentType.Application.Json)
            setBody(MatchIdBody(matchId))
        }.body()

    /** Polled every few seconds by ChatViewModel. */
    suspend fun listMessages(matchId: String): List<ChatMessage> =
        client.postgrest.from("messages").select {
            filter { eq("match_id", matchId) }
            order("created_at", Order.ASCENDING)
        }.decodeList()

    /** All of the caller's currently-active matches, for the dashboard. */
    suspend fun listActiveMatchIds(): List<String> {
        @Serializable data class Row(val id: String)
        val uid = _userId.value ?: return emptyList()
        val rows: List<Row> = client.postgrest.from("matches").select {
            filter {
                eq("status", "active")
                or {
                    eq("user_a", uid)
                    eq("user_b", uid)
                }
            }
        }.decodeList()
        return rows.map { it.id }
    }

    // MARK: Report / soft-exit

    @Serializable private data class ReportBody(val matchId: String, val category: String, val detail: String?)
    @Serializable private data class EndMatchBody(val matchId: String, val reason: String?)

    suspend fun endMatch(matchId: String, reason: String?): EndMatchResponse =
        client.functions.invoke("end-match") {
            contentType(ContentType.Application.Json)
            setBody(EndMatchBody(matchId, reason))
        }.body()

    suspend fun submitReport(matchId: String, category: String, detail: String?) {
        client.functions.invoke("submit-report") {
            contentType(ContentType.Application.Json)
            setBody(ReportBody(matchId, category, detail))
        }
    }

    // MARK: Pro / subscription

    suspend fun getSubscriptionStatus(): SubscriptionStatus {
        val uid = _userId.value ?: return SubscriptionStatus()
        return client.postgrest.from("subscriptions").select {
            filter { eq("user_id", uid) }
        }.decodeSingleOrNull<SubscriptionStatus>() ?: SubscriptionStatus()
    }

    @Serializable
    private data class PurchaseBody(
        val platform: String,
        val productId: String,
        val transactionId: String,
        val currentPeriodEnd: String? = null,
    )

    suspend fun recordPurchase(productId: String, transactionId: String, currentPeriodEndIso: String?) {
        client.functions.invoke("record-purchase") {
            contentType(ContentType.Application.Json)
            setBody(PurchaseBody("android", productId, transactionId, currentPeriodEndIso))
        }
    }

    suspend fun redeemBoost(productId: String, transactionId: String) {
        client.functions.invoke("redeem-boost") {
            contentType(ContentType.Application.Json)
            setBody(PurchaseBody("android", productId, transactionId))
        }
    }

    // MARK: Account

    suspend fun exportAccountData(): ByteArray =
        client.functions.invoke("export-account-data") {
            contentType(ContentType.Application.Json)
            setBody(EmptyBody())
        }.body()

    suspend fun deleteAccount() {
        client.functions.invoke("delete-account") {
            contentType(ContentType.Application.Json)
            setBody(EmptyBody())
        }
        client.auth.signOut()
        _userId.value = null
    }

    suspend fun signOut() {
        client.auth.signOut()
        _userId.value = null
    }

    /** Edge functions return `{ message, code }` on a non-2xx response (see
     * e.g. send-message's content-blocked rejection) — this pulls that
     * message out of the raw response body so the UI can show it instead
     * of a generic exception string. */
    suspend fun friendlyMessage(error: Throwable): String {
        if (error is RestException) {
            try {
                val body = error.response.bodyAsText()
                val message = Json.parseToJsonElement(body).jsonObject["message"]?.jsonPrimitive?.content
                if (message != null) return message
            } catch (_: Exception) {
            }
        }
        return error.message ?: "Something went wrong"
    }
}

@Serializable
private class EmptyBody
