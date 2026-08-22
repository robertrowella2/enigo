// Records the one-time boost purchase (one extra rematch) after the free
// tier's 3 declines. Same verification approach as record-purchase — see
// that file and _shared/appStoreServerApi.ts / _shared/playDeveloperApi.ts.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { verifyAppleTransaction } from "../_shared/appStoreServerApi.ts";
import { verifyGooglePurchase } from "../_shared/playDeveloperApi.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { platform, productId, transactionId } = await req.json();

    if (platform !== "ios" && platform !== "android") {
      return Response.json({ message: "Invalid platform", code: "invalid_body" }, { status: 400 });
    }

    if (platform === "ios" && transactionId) {
      const result = await verifyAppleTransaction(transactionId);
      if (result === null) {
        console.warn("[redeem-boost] Apple secrets not configured — trusting client-reported purchase (dev only).");
      } else if (!result.verified) {
        return Response.json({ message: "Purchase could not be verified", code: "verification_failed" }, { status: 402 });
      }
    } else if (platform === "android" && transactionId && productId) {
      const result = await verifyGooglePurchase(productId, transactionId, false);
      if (result === null) {
        console.warn("[redeem-boost] Google secrets not configured — trusting client-reported purchase (dev only).");
      } else if (!result.verified) {
        return Response.json({ message: "Purchase could not be verified", code: "verification_failed" }, { status: 402 });
      }
    }

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("rematch_credits")
      .eq("id", callerId)
      .single();
    if (profileError) throw profileError;

    const rematchCreditsRemaining = profile.rematch_credits + 1;
    const { error } = await admin
      .from("profiles")
      .update({ rematch_credits: rematchCreditsRemaining })
      .eq("id", callerId);
    if (error) throw error;

    return Response.json({ ok: true, rematchCreditsRemaining });
  }),
};
