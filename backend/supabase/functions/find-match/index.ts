// Called by a signed-in user to find (or check on) their matches. Idempotent:
// safe to poll from the "Searching" screen, the connections dashboard, and
// chat. Free tier holds 1 concurrent match, Pro holds up to 3 (see
// getMaxConcurrentMatches) — this is also the mechanism behind "as we start
// to get users, it stops talking or goes away": if any of the caller's
// active matches is AI-bootstrapped, this keeps looking for a real
// candidate and upgrades that specific slot the moment one exists.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { getAppConfig, recordMessage } from "../_shared/mechanic.ts";
import { createMatch, endMatch, getMaxConcurrentMatches, hasOpenSlot } from "../_shared/matches.ts";
import { sendPushToUser } from "../_shared/pushNotifications.ts";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

/** The only way a client otherwise learns about a new match is by polling
 * find-match/get-match-state itself, which doesn't happen if the app isn't
 * open — this is the one push telling someone a match exists at all. */
async function notifyMatched(admin: AdminClient, userId: string): Promise<void> {
  const { data: profile } = await admin.from("profiles").select("notify_matches, is_ai").eq("id", userId).single();
  if (!profile || profile.is_ai || !profile.notify_matches) return;
  await sendPushToUser(admin, userId, "New match", "Someone new is here. Say hello.");
}

/** First candidate (already ranked by score/distance) that isn't already at
 * their own concurrent-match capacity. find_match_candidates only guarantees
 * mutual compatibility, not that the other person has room for us. */
async function firstAvailable(
  admin: AdminClient,
  candidates: { candidate_id: string }[],
): Promise<string | null> {
  for (const c of candidates) {
    if (await hasOpenSlot(admin, c.candidate_id)) return c.candidate_id;
  }
  return null;
}

const AI_FALLBACK_DELAY_MS = 2 * 60 * 1000;

/** How long this caller has been searching for the slot they're currently
 * trying to fill — since their most recently ended match, or since their
 * profile was created if they've never had one (profiles only ever get
 * created once onboarding fully completes, so that's the same moment their
 * very first search began). Used to hold off matching with an AI persona
 * for a couple of minutes, so a real candidate gets first chance. */
async function searchingSinceMs(admin: AdminClient, callerId: string): Promise<number> {
  const { data: lastEnded } = await admin
    .from("matches")
    .select("ended_at")
    .or(`user_a.eq.${callerId},user_b.eq.${callerId}`)
    .eq("status", "ended")
    .order("ended_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (lastEnded?.ended_at) return new Date(lastEnded.ended_at).getTime();

  const { data: profile } = await admin.from("profiles").select("created_at").eq("id", callerId).single();
  return new Date(profile.created_at).getTime();
}

export default {
  fetch: withSupabase({ auth: "user" }, async (_req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;

    const { data: activeRows, error: activeError } = await admin
      .from("matches")
      .select("id, is_ai_match")
      .eq("status", "active")
      .or(`user_a.eq.${callerId},user_b.eq.${callerId}`);
    if (activeError) throw activeError;

    let matches: { id: string; is_ai_match: boolean }[] = activeRows ?? [];

    // 1. Try upgrading any AI-bootstrapped slot to a real match.
    for (const m of matches.filter((m) => m.is_ai_match)) {
      const { data: realCandidates, error: realError } = await admin.rpc(
        "find_match_candidates",
        { p_caller_id: callerId, p_include_ai: false },
      );
      if (realError) throw realError;
      const candidateId = realCandidates?.length ? await firstAvailable(admin, realCandidates) : null;
      if (!candidateId) continue;

      await recordMessage(
        admin,
        m.id,
        null,
        "Someone real showed up — this one's stepping aside for them.",
        { isSystem: true },
      );
      await endMatch(admin, m.id, "upgraded_to_real", null);
      const newId = await createMatch(admin, callerId, candidateId, false);
      matches = matches.filter((x) => x.id !== m.id);
      matches.push({ id: newId, is_ai_match: false });
      await Promise.all([notifyMatched(admin, callerId), notifyMatched(admin, candidateId)]);
    }

    // 2. Fill any open slot (free = 1 total, Pro = up to 3).
    const maxMatches = await getMaxConcurrentMatches(admin, callerId);
    let searching = false;

    if (matches.length < maxMatches) {
      const { data: realCandidates, error: realError } = await admin.rpc(
        "find_match_candidates",
        { p_caller_id: callerId, p_include_ai: false },
      );
      if (realError) throw realError;
      const realCandidateId = realCandidates?.length ? await firstAvailable(admin, realCandidates) : null;

      if (realCandidateId) {
        const newId = await createMatch(admin, callerId, realCandidateId, false);
        matches.push({ id: newId, is_ai_match: false });
        await Promise.all([notifyMatched(admin, callerId), notifyMatched(admin, realCandidateId)]);
      } else {
        const aiMatchingEnabled = await getAppConfig(admin, "ai_matching_enabled");
        const searchedLongEnough = (Date.now() - await searchingSinceMs(admin, callerId)) >= AI_FALLBACK_DELAY_MS;
        if (aiMatchingEnabled && searchedLongEnough) {
          const { data: aiCandidates, error: aiError } = await admin.rpc(
            "find_match_candidates",
            { p_caller_id: callerId, p_include_ai: true },
          );
          if (aiError) throw aiError;
          if (aiCandidates?.length) {
            const newId = await createMatch(admin, callerId, aiCandidates[0].candidate_id, true);
            matches.push({ id: newId, is_ai_match: true });
            await notifyMatched(admin, callerId);
          } else {
            searching = matches.length === 0;
          }
        } else {
          searching = matches.length === 0;
        }
      }
    }

    return Response.json({ matchIds: matches.map((m) => m.id), searching });
  }),
};
