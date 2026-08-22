// Shared implementation of "The core mechanic" (design_handoff_enigo/README.md):
// per-person counters, character-weighted messages, fixed unlock order,
// thresholds/counts never returned to a client. Used by both the human
// message path (send-message) and the AI persona reply path (ai-reply),
// so there is exactly one place this logic lives.

// deno-lint-ignore no-explicit-any
type AdminClient = any;

const FIELD_ORDER = ["interests", "bio", "location", "photo"] as const;
export type UnlockField = (typeof FIELD_ORDER)[number];

export async function getAppConfig(admin: AdminClient, key: string): Promise<unknown> {
  const { data, error } = await admin
    .from("app_config")
    .select("value")
    .eq("key", key)
    .single();
  if (error) throw error;
  return data.value;
}

/**
 * Inserts a message and updates the sender's per-person counter.
 * Never called with the client's anon/user-scoped client — messages has no
 * client INSERT policy, specifically so this is the only path a message (and
 * its counter effect) can be created through.
 */
export async function recordMessage(
  admin: AdminClient,
  matchId: string,
  senderId: string | null,
  body: string,
  opts: { isSystem?: boolean } = {},
): Promise<{ charCount: number; isHeavy: boolean }> {
  const isSystem = opts.isSystem ?? false;
  const charCount = body.length;
  const heavyMin = Number(await getAppConfig(admin, "heavy_message_min_chars"));
  const isHeavy = !isSystem && charCount >= heavyMin;

  const { error: insertError } = await admin.from("messages").insert({
    match_id: matchId,
    sender_id: senderId,
    body,
    char_count: charCount,
    is_heavy: isHeavy,
    is_system: isSystem,
  });
  if (insertError) throw insertError;

  if (!isSystem && senderId) {
    const { data: existing } = await admin
      .from("match_counters")
      .select("heavy_count, char_count")
      .eq("match_id", matchId)
      .eq("user_id", senderId)
      .maybeSingle();

    const nextHeavy = (existing?.heavy_count ?? 0) + (isHeavy ? 1 : 0);
    const nextChars = Number(existing?.char_count ?? 0) + charCount;

    const { error: upsertError } = await admin.from("match_counters").upsert({
      match_id: matchId,
      user_id: senderId,
      heavy_count: nextHeavy,
      char_count: nextChars,
    });
    if (upsertError) throw upsertError;
  }

  return { charCount, isHeavy };
}

/**
 * Checks only the next field in fixed unlock order (interests -> bio ->
 * location -> photo) and inserts it into `unlocks` if both participants'
 * heavy_count counters have cleared its threshold. Never unlocks out of
 * order, and never returns counts — only ever a field name or null.
 */
export async function checkAndApplyUnlocks(
  admin: AdminClient,
  matchId: string,
): Promise<UnlockField | null> {
  const { data: match, error: matchError } = await admin
    .from("matches")
    .select("user_a, user_b")
    .eq("id", matchId)
    .single();
  if (matchError) throw matchError;

  const { data: unlockRows, error: unlocksError } = await admin
    .from("unlocks")
    .select("field")
    .eq("match_id", matchId);
  if (unlocksError) throw unlocksError;
  const unlockedSet = new Set((unlockRows ?? []).map((r: { field: string }) => r.field));

  const nextField = FIELD_ORDER.find((f) => !unlockedSet.has(f));
  if (!nextField) return null; // fully graduated

  const { data: threshold, error: thresholdError } = await admin
    .from("unlock_thresholds")
    .select("heavy_count_required")
    .eq("field", nextField)
    .single();
  if (thresholdError) throw thresholdError;

  const { data: counters, error: countersError } = await admin
    .from("match_counters")
    .select("user_id, heavy_count")
    .eq("match_id", matchId)
    .in("user_id", [match.user_a, match.user_b]);
  if (countersError) throw countersError;

  const heavyByUser = new Map<string, number>(
    (counters ?? []).map((c: { user_id: string; heavy_count: number }) => [c.user_id, c.heavy_count]),
  );
  const minHeavy = Math.min(heavyByUser.get(match.user_a) ?? 0, heavyByUser.get(match.user_b) ?? 0);

  if (minHeavy < threshold.heavy_count_required) return null;

  // Race-safe: two concurrent sends can't double-unlock the same field.
  const { error: insertError, count } = await admin
    .from("unlocks")
    .insert({ match_id: matchId, field: nextField }, { count: "exact" })
    .select();
  if (insertError && insertError.code !== "23505") throw insertError; // 23505 = unique_violation, already unlocked
  return count ? nextField : null;
}

const FALLBACK_REPLIES = [
  "Still here — just slower to type today than most.",
  "That's a good question. Give me a minute to answer it properly.",
  "Noted. Tell me something ordinary about your day.",
  "I read that twice. In a good way.",
];

export async function generateAiReply(
  admin: AdminClient,
  matchId: string,
  aiUserId: string,
): Promise<UnlockField | null> {
  const { data: persona, error: personaError } = await admin
    .from("profiles")
    .select("ai_system_prompt")
    .eq("id", aiUserId)
    .single();
  if (personaError) throw personaError;

  const { data: history, error: historyError } = await admin
    .from("messages")
    .select("sender_id, body")
    .eq("match_id", matchId)
    .eq("is_system", false)
    .order("created_at", { ascending: false })
    .limit(12);
  if (historyError) throw historyError;

  const messages = (history ?? [])
    .reverse()
    .map((m: { sender_id: string; body: string }) => ({
      role: m.sender_id === aiUserId ? "assistant" : "user",
      content: m.body,
    }));

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  let reply: string | null = null;

  if (apiKey) {
    try {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5",
          max_tokens: 200,
          system: persona.ai_system_prompt,
          messages: messages.length ? messages : [{ role: "user", content: "Hello." }],
        }),
      });
      if (res.ok) {
        const json = await res.json();
        reply = (json.content ?? [])
          .filter((b: { type: string }) => b.type === "text")
          .map((b: { text: string }) => b.text)
          .join("")
          .trim() || null;
      }
    } catch {
      reply = null;
    }
  }

  if (!reply) {
    const idx = messages.length % FALLBACK_REPLIES.length;
    reply = FALLBACK_REPLIES[idx];
  }

  await recordMessage(admin, matchId, aiUserId, reply);
  return await checkAndApplyUnlocks(admin, matchId);
}

export { FIELD_ORDER };
