-- Fixes two foreign keys that were missing an ON DELETE action, which blocked
-- delete-account with "Database error deleting user" whenever the account
-- had filed a report or ended a match (found via the smoke test).

alter table reports drop constraint reports_reporter_id_fkey;
alter table reports add constraint reports_reporter_id_fkey
  foreign key (reporter_id) references profiles (id) on delete cascade;

alter table matches drop constraint matches_ended_by_fkey;
alter table matches add constraint matches_ended_by_fkey
  foreign key (ended_by) references profiles (id) on delete set null;
