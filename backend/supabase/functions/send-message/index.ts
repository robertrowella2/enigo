// Called by a signed-in user to send a chat message. This is the ONLY path
// that can create a `messages` row (the table has no client insert policy)
// so the counter/unlock side effects can never be bypassed by inserting
// directly into the table from a client.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { recordMessage, checkAndApplyUnlocks, generateAiReply, UnlockField } from "../_shared/mechanic.ts";
import { sendPushToUser } from "../_shared/pushNotifications.ts";
import {
  checkMessageContent,
  checkFragmentedPhoneNumber,
  checkOwnLastNameLeak,
  messageForBlockReason,
} from "../_shared/contentFilter.ts";

const MAX_LEN = 2000;

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { matchId, body, clientMessageId, gifUrl, photoUrl } = await req.json();

    const text = typeof body === "string" ? body.trim() : "";
    const gif = typeof gifUrl === "string" ? gifUrl.trim() : "";
    const photo = typeof photoUrl === "string" ? photoUrl.trim() : "";

    if (!text && !gif && !photo) {
      return Response.json({ message: "Message must have text, GIF, or photo", code: "invalid_body" }, { status: 400 });
    }
    if (text.length > MAX_LEN) {
      return Response.json({ message: "Invalid message body", code: "invalid_body" }, { status: 400 });
    }

    if (gif && !isValidGifUrl(gif)) {
      return Response.json({ message: "Invalid GIF source", code: "invalid_gif" }, { status: 400 });
    }

    if (photo) {
      const { data: unlocks } = await admin.from("unlocks").select("field").eq("match_id", matchId);
      const hasPhotoAccess = unlocks?.some((u: { field: string }) => u.field === "photo") ?? false;
      if (!hasPhotoAccess) {
        return Response.json(
          { message: "Photo sharing not yet unlocked", code: "photo_locked" },
          { status: 403 },
        );
      }
    }

    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const messageId = typeof clientMessageId === "string" && UUID_RE.test(clientMessageId) ? clientMessageId : undefined;

    const blockReason = checkMessageContent(text);
    if (blockReason) {
      return Response.json({ message: messageForBlockReason(blockReason), code: "content_blocked" }, { status: 400 });
    }

    const { data: sender } = await admin.from("profiles").select("last_name").eq("id", callerId).single();
    if (checkOwnLastNameLeak(text, sender?.last_name ?? null)) {
      return Response.json(
        { message: messageForBlockReason("last_name"), code: "content_blocked" },
        { status: 400 },
      );
    }

    const { data: match, error: matchError } = await admin
      .from("matches")
      .select("id, user_a, user_b, status, is_ai_match")
      .eq("id", matchId)
      .single();
    if (matchError) {
      return Response.json({ message: "Match not found", code: "not_found" }, { status: 404 });
    }
    if (match.status !== "active" || (match.user_a !== callerId && match.user_b !== callerId)) {
      return Response.json({ message: "Not a participant of this match", code: "forbidden" }, { status: 403 });
    }

    // Catches someone splitting a phone number across several messages
    // ("720" / "980" / "1520") to dodge the single-message check above —
    // looks at this sender's own recent messages in this match alongside
    // the new one.
    const { data: recentRows } = await admin
      .from("messages")
      .select("body")
      .eq("match_id", matchId)
      .eq("sender_id", callerId)
      .eq("is_system", false)
      .order("created_at", { ascending: false })
      .limit(8);
    const recentBodiesOldToNew = (recentRows ?? []).map((r: { body: string }) => r.body).reverse();
    if (checkFragmentedPhoneNumber(recentBodiesOldToNew, text)) {
      return Response.json(
        { message: messageForBlockReason("phone_number"), code: "content_blocked" },
        { status: 400 },
      );
    }

    await recordMessage(admin, matchId, callerId, text, { id: messageId, gifUrl: gif || undefined, photoUrl: photo || undefined });
    const unlockedField: UnlockField | null = await checkAndApplyUnlocks(admin, matchId);

    if (unlockedField) {
      await Promise.all(
        [match.user_a, match.user_b].map((uid: string) => notifyUnlock(admin, uid)),
      );
    }

    if (match.is_ai_match) {
      const aiUserId = match.user_a === callerId ? match.user_b : match.user_a;
      // Claude's own reply generation can take a couple of seconds — don't
      // make the human wait on it just to see their own message land. Runs
      // after the response is sent; still notified/unlock-checked once it
      // finishes. Falls back to awaiting inline if EdgeRuntime.waitUntil
      // isn't available in this runtime, rather than silently dropping the
      // AI's reply.
      const aiTask = generateAiReplyAndNotify(admin, matchId, aiUserId, callerId);
      // deno-lint-ignore no-explicit-any
      const waitUntil = (globalThis as any).EdgeRuntime?.waitUntil;
      if (waitUntil) {
        waitUntil(aiTask);
      } else {
        await aiTask;
      }
    } else {
      const recipientId = match.user_a === callerId ? match.user_b : match.user_a;
      await notifyNewMessage(admin, recipientId, callerId);
    }

    return Response.json({ ok: true });
  }),
};

// deno-lint-ignore no-explicit-any
async function notifyNewMessage(admin: any, recipientId: string, senderId: string): Promise<void> {
  const { data: recipient } = await admin.from("profiles").select("notify_messages, is_ai").eq("id", recipientId).single();
  if (!recipient || recipient.is_ai || !recipient.notify_messages) return;

  const { data: sender } = await admin.from("profiles").select("username").eq("id", senderId).single();
  await sendPushToUser(admin, recipientId, "New message", `@${sender?.username ?? "Someone"} sent you a message.`);
}

// deno-lint-ignore no-explicit-any
async function notifyUnlock(admin: any, userId: string): Promise<void> {
  const { data: profile } = await admin.from("profiles").select("notify_unlocks, is_ai").eq("id", userId).single();
  if (!profile || profile.is_ai || !profile.notify_unlocks) return;
  await sendPushToUser(admin, userId, "Something unlocked", "A new part of your connection just unlocked.");
}

// deno-lint-ignore no-explicit-any
async function generateAiReplyAndNotify(admin: any, matchId: string, aiUserId: string, humanUserId: string): Promise<void> {
  try {
    const replyUnlock = await generateAiReply(admin, matchId, aiUserId);
    await notifyNewMessage(admin, humanUserId, aiUserId);
    if (replyUnlock) {
      await Promise.all([humanUserId, aiUserId].map((uid) => notifyUnlock(admin, uid)));
    }
  } catch (e) {
    console.error("AI reply generation failed:", e);
  }
}

/** GIPHY serves media from numbered CDN subdomains (media0.giphy.com …
 * media4.giphy.com, i.giphy.com), and which one a given GIF comes back on
 * varies per request — so an exact-hostname allowlist rejects almost every
 * real GIF. Match the registrable domain instead. The leading dot matters:
 * without it "evilgiphy.com" would pass. */
function isValidGifUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:") return false;
    const hostname = parsed.hostname.toLowerCase();
    return hostname === "giphy.com" || hostname.endsWith(".giphy.com");
  } catch {
    return false;
  }
}
