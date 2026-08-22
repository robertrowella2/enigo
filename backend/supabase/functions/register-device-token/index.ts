// Called once notification permission is granted and the OS hands the
// client a push token (APNs device token on iOS, FCM registration token on
// Android). Upserts so re-registering the same token (e.g. app relaunch)
// is a no-op rather than a duplicate row.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { platform, token } = await req.json();

    if (platform !== "ios" && platform !== "android") {
      return Response.json({ message: "Invalid platform", code: "invalid_body" }, { status: 400 });
    }
    if (typeof token !== "string" || token.length === 0) {
      return Response.json({ message: "Missing token", code: "invalid_body" }, { status: 400 });
    }

    const { error } = await admin
      .from("device_tokens")
      .upsert(
        { user_id: callerId, platform, token, updated_at: new Date().toISOString() },
        { onConflict: "user_id,platform,token" },
      );
    if (error) throw error;

    return Response.json({ ok: true });
  }),
};
