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

// deno-lint-ignore no-explicit-any
type AdminClient = any;

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
      } else {
        const aiMatchingEnabled = await getAppConfig(admin, "ai_matching_enabled");
        if (aiMatchingEnabled) {
          const { data: aiCandidates, error: aiError } = await admin.rpc(
            "find_match_candidates",
            { p_caller_id: callerId, p_include_ai: true },
          );
          if (aiError) throw aiError;
          if (aiCandidates?.length) {
            const newId = await createMatch(admin, callerId, aiCandidates[0].candidate_id, true);
            matches.push({ id: newId, is_ai_match: true });
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
