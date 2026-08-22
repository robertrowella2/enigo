-- Server-side counterpart to find-match's step 1 (see
-- functions/find-match/index.ts). The client only triggers an upgrade check
-- while the user has Chat open and polling; this cron makes the
-- "as we start to get users, it stops talking or goes away" promise hold
-- even for a user who never reopens the app. Runs entirely in the
-- database — a batch job across every AI-bootstrapped match has no single
-- caller JWT to hand find-match, so it re-implements the same swap logic
-- directly against find_match_candidates rather than looping HTTP calls to
-- the edge function.
create extension if not exists pg_cron;

create or replace function upgrade_ai_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  m record;
  found_candidate uuid;
  new_match_id uuid;
begin
  for m in
    select id, user_a, user_b
    from matches
    where status = 'active' and is_ai_match = true
  loop
    select candidate_id into found_candidate
    from find_match_candidates(m.user_a, false)
    limit 1;

    if found_candidate is not null then
      insert into messages (match_id, sender_id, body, char_count, is_system)
      values (m.id, null, 'This one''s ended. Looking for your next connection...', length('This one''s ended. Looking for your next connection...'), true);

      update matches
      set status = 'ended', ended_at = now(), end_reason = 'upgraded_to_real'
      where id = m.id;

      insert into matches (user_a, user_b, is_ai_match)
      values (m.user_a, found_candidate, false)
      returning id into new_match_id;

      insert into match_counters (match_id, user_id)
      values (new_match_id, m.user_a), (new_match_id, found_candidate);
    end if;
  end loop;
end;
$$;

revoke execute on function upgrade_ai_matches() from public;

select cron.schedule('upgrade-ai-matches', '*/2 * * * *', 'select upgrade_ai_matches()');
