// The only way a client learns anything about its match partner. Returns
// exactly the fields that have unlocked so far, plus a short-TTL signed URL
// for the photo once graduated — never counts, never thresholds, never the
// raw partner row, and never whether the partner is an AI persona (that
// disclosure lives in Terms/Settings copy, not runtime match data).
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const SIGNED_URL_TTL_SECONDS = 60 * 5;

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { matchId } = await req.json();

    const { data: match, error: matchError } = await admin
      .from("matches")
      .select("id, user_a, user_b, status")
      .eq("id", matchId)
      .single();
    if (matchError) {
      return Response.json({ message: "Match not found", code: "not_found" }, { status: 404 });
    }
    if (match.user_a !== callerId && match.user_b !== callerId) {
      return Response.json({ message: "Not a participant of this match", code: "forbidden" }, { status: 403 });
    }
    const partnerId = match.user_a === callerId ? match.user_b : match.user_a;

    const [
      { data: unlockRows, error: unlocksError },
      { data: partner, error: partnerError },
      { data: callerProfile, error: callerError },
      { data: partnerCounter },
    ] = await Promise.all([
      admin.from("unlocks").select("field").eq("match_id", matchId),
      admin
        .from("profiles")
        .select("username, first_name, show_first_name, interests, bio, photo_path, lat, lng")
        .eq("id", partnerId)
        .single(),
      admin.from("profiles").select("lat, lng").eq("id", callerId).single(),
      admin.from("match_counters").select("last_read_at").eq("match_id", matchId).eq("user_id", partnerId).maybeSingle(),
      // Calling get-match-state means the caller has this chat open — mark
      // everything sent so far as read by them.
      admin.from("match_counters").update({ last_read_at: new Date().toISOString() }).eq("match_id", matchId).eq("user_id", callerId),
    ]);
    if (unlocksError) throw unlocksError;
    if (partnerError) throw partnerError;
    if (callerError) throw callerError;

    const unlocked = new Set((unlockRows ?? []).map((r: { field: string }) => r.field));

    // deno-lint-ignore no-explicit-any
    const result: Record<string, any> = {
      matchId: match.id,
      status: match.status,
      partnerUsername: partner.username,
      unlocked: Array.from(unlocked),
      partnerReadAt: partnerCounter?.last_read_at ?? null,
    };

    if (partner.show_first_name && partner.first_name) {
      result.partnerFirstName = partner.first_name;
    }
    if (unlocked.has("interests")) {
      result.interests = partner.interests;
    }
    if (unlocked.has("bio")) {
      result.bio = partner.bio;
    }
    if (unlocked.has("location")) {
      result.distanceKm =
        callerProfile.lat != null && callerProfile.lng != null && partner.lat != null && partner.lng != null
          ? haversineKm(callerProfile.lat, callerProfile.lng, partner.lat, partner.lng)
          : null;
    }
    if (unlocked.has("photo") && partner.photo_path) {
      const { data: signed } = await admin.storage
        .from("photos")
        .createSignedUrl(partner.photo_path, SIGNED_URL_TTL_SECONDS);
      result.photoUrl = signed?.signedUrl ?? null;
    }

    return Response.json(result);
  }),
};

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}
