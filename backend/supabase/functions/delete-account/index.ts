// Irreversible. Deletes the auth user; profiles/matches/messages/etc. all
// cascade via foreign keys. Matches see the conversation close without a
// reason (no special "account deleted" system message — this mirrors the
// soft-exit's "no notification" behavior rather than adding a new one).
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (_req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(callerId);
    if (error) throw error;
    return Response.json({ ok: true });
  }),
};
