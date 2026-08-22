// Sends a push notification to every device registered for a user, via
// APNs (iOS) or FCM (Android). Needs:
//   iOS: APPLE_APNS_KEY (the .p8 key contents), APPLE_APNS_KEY_ID,
//        APPLE_APNS_TEAM_ID, APPLE_BUNDLE_ID
//   Android: FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_PROJECT_ID
// as Supabase Edge Function secrets. Silently no-ops per-platform when its
// secrets aren't configured, so local dev without real push credentials
// doesn't fail — it just doesn't deliver anything, which is the correct
// dev-mode behavior (see record-purchase for the same pattern).

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPemKey(pem: string, algorithm: EcKeyImportParams | RsaHashedImportParams): Promise<CryptoKey> {
  const der = Uint8Array.from(
    atob(
      pem
        .replace(/-----BEGIN PRIVATE KEY-----/, "")
        .replace(/-----END PRIVATE KEY-----/, "")
        .replace(/\\n/g, "")
        .replace(/\s/g, ""),
    ),
    (c) => c.charCodeAt(0),
  );
  return crypto.subtle.importKey("pkcs8", der, algorithm, false, ["sign"]);
}

// MARK: - APNs

async function sendApns(token: string, title: string, body: string): Promise<void> {
  const keyPem = Deno.env.get("APPLE_APNS_KEY");
  const keyId = Deno.env.get("APPLE_APNS_KEY_ID");
  const teamId = Deno.env.get("APPLE_APNS_TEAM_ID");
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID");
  if (!keyPem || !keyId || !teamId || !bundleId) {
    console.warn("[push] Apple APNs secrets not configured — skipping iOS push.");
    return;
  }

  const key = await importPemKey(keyPem, { name: "ECDSA", namedCurve: "P-256" });
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId };
  const payload = { iss: teamId, iat: now };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${base64url(new Uint8Array(signature))}`;

  const send = (host: string) =>
    fetch(`https://${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
      },
      body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" } }),
    });

  // A device token is only ever valid for the APNs environment the app was
  // signed for — a debug/development-signed build (every install before an
  // App Store or TestFlight release) registers a sandbox-only token, which
  // production APNs rejects with "BadEnvironmentKeyInToken". Same
  // prod-then-sandbox fallback shape as verifyAppleTransaction.
  let res = await send("api.push.apple.com");
  if (res.status === 400) {
    const failure = await res.clone().json().catch(() => null);
    if (failure?.reason === "BadEnvironmentKeyInToken") {
      res = await send("api.sandbox.push.apple.com");
    }
  }
  if (!res.ok) {
    console.warn(`[push] APNs send failed: ${res.status} ${await res.text()}`);
  }
}

// MARK: - FCM

async function getFcmAccessToken(): Promise<string | null> {
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) return null;
  const account = JSON.parse(serviceAccountJson);

  const key = await importPemKey(account.private_key, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" });
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput));
  const assertion = `${signingInput}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${assertion}`,
  });
  if (!res.ok) return null;
  return (await res.json()).access_token ?? null;
}

async function sendFcm(token: string, title: string, body: string): Promise<void> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) {
    console.warn("[push] Firebase secrets not configured — skipping Android push.");
    return;
  }
  const accessToken = await getFcmAccessToken();
  if (!accessToken) {
    console.warn("[push] Could not obtain an FCM access token — skipping Android push.");
    return;
  }

  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ message: { token, notification: { title, body } } }),
  });
  if (!res.ok) {
    console.warn(`[push] FCM send failed: ${res.status} ${await res.text()}`);
  }
}

// deno-lint-ignore no-explicit-any
export async function sendPushToUser(admin: any, userId: string, title: string, body: string): Promise<void> {
  const { data: tokens, error } = await admin
    .from("device_tokens")
    .select("platform, token")
    .eq("user_id", userId);
  if (error || !tokens?.length) return;

  await Promise.all(
    // deno-lint-ignore no-explicit-any
    tokens.map((t: any) => (t.platform === "ios" ? sendApns(t.token, title, body) : sendFcm(t.token, title, body))),
  );
}
