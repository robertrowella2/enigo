// deno-lint-ignore no-explicit-any
type AdminClient = any;

export async function getMaxConcurrentMatches(admin: AdminClient, userId: string): Promise<number> {
  const { data } = await admin
    .from("subscriptions")
    .select("tier, status")
    .eq("user_id", userId)
    .maybeSingle();
  const isPro = data?.tier === "pro" && data?.status === "active";
  return isPro ? 3 : 1;
}

export async function isPro(admin: AdminClient, userId: string): Promise<boolean> {
  const { data } = await admin
    .from("subscriptions")
    .select("tier, status")
    .eq("user_id", userId)
    .maybeSingle();
  return data?.tier === "pro" && data?.status === "active";
}

export async function createMatch(
  admin: AdminClient,
  userA: string,
  userB: string,
  isAiMatch: boolean,
): Promise<string> {
  const { data: created, error } = await admin
    .from("matches")
    .insert({ user_a: userA, user_b: userB, is_ai_match: isAiMatch })
    .select("id")
    .single();
  if (error) throw error;

  await admin.from("match_counters").insert([
    { match_id: created.id, user_id: userA },
    { match_id: created.id, user_id: userB },
  ]);

  return created.id;
}

export async function endMatch(
  admin: AdminClient,
  matchId: string,
  reason: "soft_exit" | "report" | "upgraded_to_real",
  endedBy: string | null,
): Promise<void> {
  const { error } = await admin
    .from("matches")
    .update({ status: "ended", ended_at: new Date().toISOString(), end_reason: reason, ended_by: endedBy })
    .eq("id", matchId);
  if (error) throw error;
}
