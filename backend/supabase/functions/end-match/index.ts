// User-initiated soft exit ("This isn't quite it"). The other person is
// never notified — no notification, no last-seen. Free tier has a limited
// number of rematch credits; Pro is unlimited.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { endMatch, isPro } from "../_shared/matches.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { matchId, reason } = await req.json();

    const { data: match, error: matchError } = await admin
      .from("matches")
      .select("id, user_a, user_b, status")
      .eq("id", matchId)
      .single();
    if (matchError) {
      return Response.json({ message: "Match not found", code: "not_found" }, { status: 404 });
    }
    if (match.status !== "active" || (match.user_a !== callerId && match.user_b !== callerId)) {
      return Response.json({ message: "Not a participant of this match", code: "forbidden" }, { status: 403 });
    }

    const pro = await isPro(admin, callerId);
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("rematch_credits")
      .eq("id", callerId)
      .single();
    if (profileError) throw profileError;

    if (!pro && profile.rematch_credits <= 0) {
      return Response.json(
        { message: "No free rematches remaining", code: "no_rematches" },
        { status: 402 },
      );
    }

    await endMatch(admin, matchId, "soft_exit", callerId);
    if (typeof reason === "string" && reason.length > 0) {
      const { error: reasonError } = await admin
        .from("matches")
        .update({ soft_exit_reason: reason })
        .eq("id", matchId);
      if (reasonError) throw reasonError;
    }

    let rematchCreditsRemaining = profile.rematch_credits;
    if (!pro) {
      rematchCreditsRemaining = profile.rematch_credits - 1;
      const { error: creditError } = await admin
        .from("profiles")
        .update({ rematch_credits: rematchCreditsRemaining })
        .eq("id", callerId);
      if (creditError) throw creditError;
    }

    return Response.json({ ok: true, rematchCreditsRemaining, unlimited: pro });
  }),
};
