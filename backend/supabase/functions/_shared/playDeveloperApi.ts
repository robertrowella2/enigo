// Server-to-server verification of a Play Billing purchase via the Google
// Play Developer API, so record-purchase/redeem-boost don't have to take
// the client's word for it. Needs GOOGLE_SERVICE_ACCOUNT_JSON (the full
// contents of a service account key with access to Play Console's API,
// linked under Play Console → Setup → API access) and GOOGLE_PACKAGE_NAME
// set as Supabase Edge Function secrets. Returns null — not false — when
// those secrets aren't configured, so a caller can choose to fall back to
// trusting the client in dev rather than hard-failing every purchase
// locally.

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importGooglePrivateKey(pem: string): Promise<CryptoKey> {
  const pkcs8 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
}

async function getAccessToken(): Promise<string | null> {
  const serviceAccountJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) return null;
  const account = JSON.parse(serviceAccountJson);

  const key = await importGooglePrivateKey(account.private_key);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${assertion}`,
  });
  if (!res.ok) return null;
  const body = await res.json();
  return body.access_token ?? null;
}

export interface GoogleVerification {
  verified: boolean;
  expiryTimeMs?: number;
}

export async function verifyGooglePurchase(
  productId: string,
  purchaseToken: string,
  isSubscription: boolean,
): Promise<GoogleVerification | null> {
  const packageName = Deno.env.get("GOOGLE_PACKAGE_NAME");
  if (!packageName) return null;
  const accessToken = await getAccessToken();
  if (!accessToken) return null;

  const path = isSubscription
    ? `purchases/subscriptions/${productId}/tokens/${purchaseToken}`
    : `purchases/products/${productId}/tokens/${purchaseToken}`;
  const res = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/${path}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (!res.ok) return { verified: false };
  const body = await res.json();

  if (isSubscription) {
    // paymentState: 0 pending, 1 received, 2 free trial, 3 deferred.
    const verified = body.paymentState === 1 || body.paymentState === 2;
    return { verified, expiryTimeMs: body.expiryTimeMillis ? Number(body.expiryTimeMillis) : undefined };
  }
  // purchaseState: 0 purchased, 1 canceled, 2 pending.
  return { verified: body.purchaseState === 0 };
}
