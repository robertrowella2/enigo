// Called by a signed-in user to send a chat message. This is the ONLY path
// that can create a `messages` row (the table has no client insert policy)
// so the counter/unlock side effects can never be bypassed by inserting
// directly into the table from a client.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { recordMessage, checkAndApplyUnlocks, generateAiReply, UnlockField } from "../_shared/mechanic.ts";
import { sendPushToUser } from "../_shared/pushNotifications.ts";

const MAX_LEN = 2000;

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { matchId, body } = await req.json();

    const text = typeof body === "string" ? body.trim() : "";
    if (!text || text.length > MAX_LEN) {
      return Response.json({ message: "Invalid message body", code: "invalid_body" }, { status: 400 });
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

    await recordMessage(admin, matchId, callerId, text);
    let unlockedField: UnlockField | null = await checkAndApplyUnlocks(admin, matchId);

    if (match.is_ai_match) {
      const aiUserId = match.user_a === callerId ? match.user_b : match.user_a;
      // Synchronous for v1 simplicity; move to fire-and-forget/queue if reply
      // latency becomes a problem.
      const replyUnlock = await generateAiReply(admin, matchId, aiUserId);
      unlockedField = unlockedField ?? replyUnlock;
      await notifyNewMessage(admin, callerId, aiUserId);
    } else {
      const recipientId = match.user_a === callerId ? match.user_b : match.user_a;
      await notifyNewMessage(admin, recipientId, callerId);
    }

    if (unlockedField) {
      await Promise.all(
        [match.user_a, match.user_b].map((uid: string) => notifyUnlock(admin, uid)),
      );
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
