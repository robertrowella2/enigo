// Reporting always ends the match immediately and permanently excludes that
// pair from rematching. "A human reads every report" (out of scope here —
// this just records it and locks the pair; a moderation queue/notification
// is a separate ops surface, per the handoff doc's "Not yet designed").
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { endMatch } from "../_shared/matches.ts";

const CATEGORIES = ["harassment", "inappropriate_content", "fake_profile", "money", "other"];

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { matchId, category, detail } = await req.json();

    if (!CATEGORIES.includes(category)) {
      return Response.json({ message: "Invalid category", code: "invalid_body" }, { status: 400 });
    }

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

    const { error: reportError } = await admin.from("reports").insert({
      match_id: matchId,
      reporter_id: callerId,
      category,
      detail: detail ?? null,
    });
    if (reportError) throw reportError;

    if (match.status === "active") {
      await endMatch(admin, matchId, "report", callerId);
    }

    const { error: blockError } = await admin
      .from("blocked_pairs")
      .upsert({ user_a: callerId, user_b: partnerId, reason: "report" });
    if (blockError) throw blockError;

    return Response.json({ ok: true });
  }),
};
