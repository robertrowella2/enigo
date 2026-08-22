// Delete account "offers data export first" — this returns everything the
// account itself contains (never anyone else's locked data) as one JSON
// blob the client can save/share.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (_req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;

    const [{ data: profile, error: profileError }, { data: matches, error: matchesError }] = await Promise.all([
      admin
        .from("profiles")
        .select(
          "username, first_name, show_first_name, gender, gender_self_description, match_with, shown_to, community, intent, interests, bio, radius_km, location_granted, answers, created_at",
        )
        .eq("id", callerId)
        .single(),
      admin
        .from("matches")
        .select("id, status, created_at, ended_at")
        .or(`user_a.eq.${callerId},user_b.eq.${callerId}`),
    ]);
    if (profileError) throw profileError;
    if (matchesError) throw matchesError;

    const matchIds = (matches ?? []).map((m: { id: string }) => m.id);
    const { data: messages, error: messagesError } = matchIds.length
      ? await admin
        .from("messages")
        .select("match_id, sender_id, body, created_at")
        .in("match_id", matchIds)
      : { data: [], error: null };
    if (messagesError) throw messagesError;

    return Response.json({
      exportedAt: new Date().toISOString(),
      profile,
      matches,
      messages: (messages ?? []).map((m: { match_id: string; sender_id: string | null; body: string; created_at: string }) => ({
        ...m,
        sentByMe: m.sender_id === callerId,
      })),
    });
  }),
};
