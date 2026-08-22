// Internal/ops utility: manually trigger an AI persona's reply for a given
// match without going through send-message. Not called by the mobile apps —
// the real chat flow invokes `generateAiReply` directly from send-message
// (see _shared/mechanic.ts) right after a human message is recorded, so a
// human message and its AI reply land in the same request. This function
// exists for testing/back-office use, hence the secret-only auth.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { generateAiReply } from "../_shared/mechanic.ts";

export default {
  fetch: withSupabase({ auth: "secret" }, async (req, ctx) => {
    const { matchId, aiUserId } = await req.json();
    if (!matchId || !aiUserId) {
      return Response.json({ message: "matchId and aiUserId are required", code: "invalid_body" }, { status: 400 });
    }
    await generateAiReply(ctx.supabaseAdmin, matchId, aiUserId);
    return Response.json({ ok: true });
  }),
};
