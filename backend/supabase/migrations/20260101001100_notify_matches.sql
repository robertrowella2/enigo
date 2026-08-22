-- A third notification category, alongside notify_messages/notify_unlocks:
-- "you've been matched" wasn't covered by either — the client only ever
-- learns about a new match by polling find-match/get-match-state itself,
-- which means nothing arrives if the app isn't open.
alter table profiles add column notify_matches boolean not null default true;
