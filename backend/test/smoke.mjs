// End-to-end smoke test for the core mechanic against a local `supabase
// start` instance. Creates real users + relies on the seeded AI persona,
// drives the match/unlock/chat/Pro/report/account flows, and asserts the
// invariants from design_handoff_enigo/README.md.
import { execSync } from "node:child_process";
import { createClient } from "@supabase/supabase-js";
import assert from "node:assert/strict";

function status() {
  const raw = execSync("npx --yes supabase@latest status -o json", { cwd: import.meta.dirname + "/..", encoding: "utf8" });
  return JSON.parse(raw);
}

const s = status();
const API_URL = s.API_URL;
const ANON_KEY = s.ANON_KEY;
const SERVICE_ROLE_KEY = s.SERVICE_ROLE_KEY;

const admin = createClient(API_URL, SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });

async function createTestUser(email, username, profileOverrides) {
  const password = "correct horse battery staple 42";
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  assert.equal(createErr, null, `createUser failed: ${createErr?.message}`);
  const userId = created.user.id;

  const base = {
    id: userId,
    username,
    gender: "woman",
    match_with: ["anyone"],
    shown_to: ["anyone"],
    community: "open",
    intent: "open",
    interests: ["reading", "cold-water swimming"],
    bio: "Testing is a form of care.",
    lat: 57.8, // near the seeded Wren persona (Gothenburg), well within radius_km
    lng: 12.0,
    radius_km: 100,
    location_granted: true,
    answers: { "1": 0, "2": 1, "3": 0 },
    onboarding_complete: true,
  };
  const { error: profileErr } = await admin.from("profiles").insert({ ...base, ...profileOverrides });
  assert.equal(profileErr, null, `profile insert failed: ${profileErr?.message}`);

  const anon = createClient(API_URL, ANON_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: signIn, error: signInErr } = await anon.auth.signInWithPassword({ email, password });
  assert.equal(signInErr, null, `sign-in failed: ${signInErr?.message}`);

  return { userId, accessToken: signIn.session.access_token };
}

async function callFunction(name, accessToken, body) {
  const res = await fetch(`${API_URL}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: ANON_KEY,
      authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body ?? {}),
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

async function main() {
  console.log("Creating user1 (no other real users yet -> should bootstrap to the AI persona)...");
  const user1 = await createTestUser("user1@smoke.test", "smoke_user1", {});

  const found1 = await callFunction("find-match", user1.accessToken, {});
  assert.equal(found1.status, 200, JSON.stringify(found1));
  assert.equal(found1.json.matchIds.length, 1, "free tier should hold exactly one match");
  const matchId = found1.json.matchIds[0];
  console.log("  matched:", matchId);

  const { data: matchRow } = await admin.from("matches").select("is_ai_match").eq("id", matchId).single();
  assert.equal(matchRow.is_ai_match, true, "first match should be the AI persona (no real candidates exist yet)");

  console.log("Confirming free tier can't get a second concurrent match while one is active...");
  const stillOne = await callFunction("find-match", user1.accessToken, {});
  assert.deepEqual(stillOne.json.matchIds, [matchId], "free tier find-match should be a no-op with a slot already full");

  console.log("Driving messages past every threshold (interests=12, bio=30, location=55, photo=90 heavy messages)...");
  const heavyMessage = "x".repeat(45); // >= 40 chars => "heavy"
  const seenUnlocks = [];
  for (let i = 0; i < 95; i++) {
    const sent = await callFunction("send-message", user1.accessToken, { matchId, body: `${heavyMessage} ${i}` });
    assert.equal(sent.status, 200, JSON.stringify(sent));
    const { data: unlocks } = await admin.from("unlocks").select("field").eq("match_id", matchId);
    const fields = unlocks.map((u) => u.field);
    for (const f of fields) {
      if (!seenUnlocks.includes(f)) {
        seenUnlocks.push(f);
        console.log(`  unlocked after ${i + 1} heavy messages: ${f}`);
      }
    }
    if (seenUnlocks.length === 4) break;
  }
  assert.deepEqual(seenUnlocks, ["interests", "bio", "location", "photo"], "unlocks must fire in fixed order");

  console.log("Checking get-match-state reveals only unlocked fields, never counts...");
  const state = await callFunction("get-match-state", user1.accessToken, { matchId });
  assert.equal(state.status, 200);
  assert.deepEqual(new Set(state.json.unlocked), new Set(["interests", "bio", "location", "photo"]));
  assert.ok("interests" in state.json && "bio" in state.json && "distanceKm" in state.json);
  assert.ok(!("heavyCount" in state.json) && !("heavy_count" in state.json), "counts must never be exposed");
  assert.ok(!("isAiMatch" in state.json) && !("is_ai" in state.json), "AI-match status must never be exposed in-chat");

  console.log("Checking RLS: user1's own scoped client cannot read match_counters directly...");
  const scoped = createClient(API_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${user1.accessToken}` } },
  });
  const { data: counterLeak, error: counterErr } = await scoped.from("match_counters").select("*").eq("match_id", matchId);
  assert.ok((counterLeak ?? []).length === 0 || counterErr, "match_counters must not be selectable by a client");

  console.log("Creating user2, a real mutual candidate, and confirming user1 gets upgraded off the AI match...");
  const user2 = await createTestUser("user2@smoke.test", "smoke_user2", { gender: "man" });
  const upgrade = await callFunction("find-match", user1.accessToken, {});
  assert.equal(upgrade.status, 200, JSON.stringify(upgrade));
  const upgradedMatchId = upgrade.json.matchIds[0];
  assert.notEqual(upgradedMatchId, matchId, "user1 should be moved to a new, real match");
  const { data: newMatchRow } = await admin.from("matches").select("is_ai_match, status").eq("id", upgradedMatchId).single();
  assert.equal(newMatchRow.is_ai_match, false, "the upgraded match should be with the real user, not the AI persona");
  const { data: oldMatchRow } = await admin.from("matches").select("status, end_reason").eq("id", matchId).single();
  assert.equal(oldMatchRow.status, "ended", "the AI match should be closed out once a real match exists");
  assert.equal(oldMatchRow.end_reason, "upgraded_to_real");

  console.log("Soft-exiting (\"This isn't quite it\") consumes a free rematch credit...");
  const { data: beforeCredits } = await admin.from("profiles").select("rematch_credits").eq("id", user1.userId).single();
  const softExit = await callFunction("end-match", user1.accessToken, { matchId: upgradedMatchId });
  assert.equal(softExit.status, 200, JSON.stringify(softExit));
  assert.equal(softExit.json.rematchCreditsRemaining, beforeCredits.rematch_credits - 1);
  const { data: exitedMatch } = await admin.from("matches").select("status, end_reason").eq("id", upgradedMatchId).single();
  assert.equal(exitedMatch.status, "ended");
  assert.equal(exitedMatch.end_reason, "soft_exit");

  console.log("Creating user3 and testing the report flow permanently blocks the pair...");
  const user3 = await createTestUser("user3@smoke.test", "smoke_user3", { gender: "man" });
  const found3 = await callFunction("find-match", user1.accessToken, {});
  const reportMatchId = found3.json.matchIds[0];
  const { data: reportMatchRow } = await admin.from("matches").select("user_a, user_b").eq("id", reportMatchId).single();
  const partnerId = reportMatchRow.user_a === user1.userId ? reportMatchRow.user_b : reportMatchRow.user_a;

  const report = await callFunction("submit-report", user1.accessToken, {
    matchId: reportMatchId,
    category: "harassment",
    detail: "test",
  });
  assert.equal(report.status, 200, JSON.stringify(report));
  const { data: reportedMatch } = await admin.from("matches").select("status, end_reason").eq("id", reportMatchId).single();
  assert.equal(reportedMatch.status, "ended");
  assert.equal(reportedMatch.end_reason, "report");
  const { data: blockRow } = await admin
    .from("blocked_pairs")
    .select("*")
    .or(`and(user_a.eq.${user1.userId},user_b.eq.${partnerId}),and(user_a.eq.${partnerId},user_b.eq.${user1.userId})`)
    .maybeSingle();
  assert.ok(blockRow, "reported pair should be permanently blocked from rematching");

  console.log("Recording a Pro purchase raises the concurrent-match cap to 3...");
  const purchase = await callFunction("record-purchase", user1.accessToken, {
    platform: "ios",
    productId: "pro_monthly",
    transactionId: "test-txn-1",
  });
  assert.equal(purchase.status, 200, JSON.stringify(purchase));
  const user4 = await createTestUser("user4@smoke.test", "smoke_user4", { gender: "man" });
  const user5 = await createTestUser("user5@smoke.test", "smoke_user5", { gender: "man" });
  const user6 = await createTestUser("user6@smoke.test", "smoke_user6", { gender: "man" });
  void user4;
  void user5;
  void user6;
  let proMatches = new Set();
  for (let i = 0; i < 3; i++) {
    const r = await callFunction("find-match", user1.accessToken, {});
    for (const id of r.json.matchIds) proMatches.add(id);
  }
  assert.equal(proMatches.size, 3, `Pro tier should hold 3 concurrent matches, got ${proMatches.size}`);

  console.log("Exporting and deleting the account...");
  const exportRes = await callFunction("export-account-data", user1.accessToken, {});
  assert.equal(exportRes.status, 200, JSON.stringify(exportRes));
  assert.equal(exportRes.json.profile.username, "smoke_user1");
  const del = await callFunction("delete-account", user1.accessToken, {});
  assert.equal(del.status, 200, JSON.stringify(del));
  const { data: deletedProfile } = await admin.from("profiles").select("id").eq("id", user1.userId).maybeSingle();
  assert.equal(deletedProfile, null, "profile should be gone after account deletion (cascade)");

  console.log("\nAll smoke assertions passed.");
}

main().catch((err) => {
  console.error("SMOKE TEST FAILED:", err);
  process.exit(1);
});
