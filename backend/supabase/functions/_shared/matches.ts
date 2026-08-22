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

/**
 * True if userId has room for another active match given their tier (free =
 * 1, Pro = up to 3). find_match_candidates already guarantees mutual
 * compatibility (gender/community/distance) before a candidate reaches this
 * check — this only additionally protects a real candidate from being pulled
 * into a match beyond their own capacity by someone else's find-match call.
 * Not applied to AI personas, which aren't a capacity-limited resource.
 */
export async function hasOpenSlot(admin: AdminClient, userId: string): Promise<boolean> {
  const [{ count }, max] = await Promise.all([
    admin
      .from("matches")
      .select("id", { count: "exact", head: true })
      .eq("status", "active")
      .or(`user_a.eq.${userId},user_b.eq.${userId}`),
    getMaxConcurrentMatches(admin, userId),
  ]);
  return (count ?? 0) < max;
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
