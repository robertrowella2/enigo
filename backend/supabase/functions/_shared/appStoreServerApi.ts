// Server-to-server verification of a StoreKit 2 transaction via Apple's App
// Store Server API, so record-purchase doesn't have to take the client's
// word for it. Needs APPLE_ISSUER_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY
// (the .p8 contents) / APPLE_BUNDLE_ID set as Supabase Edge Function
// secrets (from App Store Connect → Users and Access → Integrations → App
// Store Server API). Returns null — not false — when those secrets aren't
// configured, so a caller can choose to fall back to trusting the client in
// dev rather than hard-failing every purchase locally.

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importApplePrivateKey(pem: string): Promise<CryptoKey> {
  const pkcs8 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

async function signAppStoreJwt(): Promise<string | null> {
  const issuerId = Deno.env.get("APPLE_ISSUER_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKeyPem = Deno.env.get("APPLE_PRIVATE_KEY");
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID");
  if (!issuerId || !keyId || !privateKeyPem || !bundleId) return null;

  const key = await importApplePrivateKey(privateKeyPem);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = { iss: issuerId, iat: now, exp: now + 300, aud: "appstoreconnect-v1", bid: bundleId };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

// deno-lint-ignore no-explicit-any
function decodeJwsPayload(jws: string): any | null {
  try {
    const payloadB64 = jws.split(".")[1];
    return JSON.parse(atob(payloadB64.replace(/-/g, "+").replace(/_/g, "/")));
  } catch {
    return null;
  }
}

export interface AppleVerification {
  verified: boolean;
  productId?: string;
  expiresDateMs?: number;
}

export async function verifyAppleTransaction(transactionId: string): Promise<AppleVerification | null> {
  const jwt = await signAppStoreJwt();
  if (!jwt) return null;

  // Production and sandbox transaction ids live in separate environments;
  // Apple's own guidance is to try production first and fall back to
  // sandbox on a 404 rather than needing the caller to know which one a
  // given transaction came from.
  for (const base of ["https://api.storekit.itunes.apple.com", "https://api.storekit-sandbox.itunes.apple.com"]) {
    const res = await fetch(`${base}/inApps/v1/transactions/${transactionId}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    if (res.status === 404) continue;
    if (!res.ok) return { verified: false };

    const body = await res.json();
    const payload = decodeJwsPayload(body.signedTransactionInfo);
    if (!payload || String(payload.transactionId) !== transactionId) return { verified: false };
    return { verified: true, productId: payload.productId, expiresDateMs: payload.expiresDate };
  }
  return { verified: false };
}
