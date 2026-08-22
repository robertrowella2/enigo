-- Read receipts: reuses match_counters (already one row per match_id/user_id,
-- never selectable by clients) rather than a new table. get-match-state
-- updates the caller's own last_read_at every time it's called — which the
-- client already polls every couple of seconds while a chat is open — and
-- returns the partner's last_read_at so the client can show "Read" on its
-- own sent messages. No new client-facing surface, no realtime infra.
alter table match_counters add column last_read_at timestamptz;
