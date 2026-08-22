// Records a Pro subscription purchase the client just completed via
// StoreKit (iOS) or Play Billing (Android).
//
// Verifies server-to-server against Apple's App Store Server API / Google's
// Play Developer API when the corresponding secrets are configured
// (APPLE_ISSUER_ID/APPLE_KEY_ID/APPLE_PRIVATE_KEY/APPLE_BUNDLE_ID for iOS;
// GOOGLE_SERVICE_ACCOUNT_JSON/GOOGLE_PACKAGE_NAME for Android — see
// _shared/appStoreServerApi.ts and _shared/playDeveloperApi.ts). Without
// those secrets set, falls back to trusting the client so local dev/testing
// still works — that fallback is dev-only and logs a warning every time.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { verifyAppleTransaction } from "../_shared/appStoreServerApi.ts";
import { verifyGooglePurchase } from "../_shared/playDeveloperApi.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { platform, productId, transactionId, currentPeriodEnd } = await req.json();

    if (platform !== "ios" && platform !== "android") {
      return Response.json({ message: "Invalid platform", code: "invalid_body" }, { status: 400 });
    }

    let verifiedExpiry: string | null = currentPeriodEnd ?? null;

    if (platform === "ios" && transactionId) {
      const result = await verifyAppleTransaction(transactionId);
      if (result === null) {
        console.warn("[record-purchase] Apple secrets not configured — trusting client-reported purchase (dev only).");
      } else if (!result.verified) {
        return Response.json({ message: "Purchase could not be verified", code: "verification_failed" }, { status: 402 });
      } else if (result.expiresDateMs) {
        verifiedExpiry = new Date(result.expiresDateMs).toISOString();
      }
    } else if (platform === "android" && transactionId && productId) {
      const result = await verifyGooglePurchase(productId, transactionId, true);
      if (result === null) {
        console.warn("[record-purchase] Google secrets not configured — trusting client-reported purchase (dev only).");
      } else if (!result.verified) {
        return Response.json({ message: "Purchase could not be verified", code: "verification_failed" }, { status: 402 });
      } else if (result.expiryTimeMs) {
        verifiedExpiry = new Date(result.expiryTimeMs).toISOString();
      }
    }

    const { error } = await admin.from("subscriptions").upsert({
      user_id: callerId,
      tier: "pro",
      platform,
      product_id: productId ?? null,
      transaction_id: transactionId ?? null,
      status: "active",
      current_period_end: verifiedExpiry,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;

    return Response.json({ ok: true });
  }),
};
