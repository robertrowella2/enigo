-- Last name: collected at onboarding for exactly one purpose — keeping it
-- out of the username and out of chat (see send-message's content filter).
-- It's never returned by get-match-state and no RLS policy lets another
-- user read it, so it's structurally private, unlike first_name which a
-- user can choose to reveal via show_first_name.
alter table profiles add column last_name text;

-- Enforced in the database (not just client-side) so it holds regardless
-- of which path writes a profile row: a username may not contain the
-- user's own first or last name. Comparison is case-insensitive and
-- ignores spaces/punctuation, so "Sarah Johnson" still blocks
-- "sarah-johnson99" as a username, not just an exact match.
create or replace function enforce_username_privacy() returns trigger as $$
declare
  normalized_username text := lower(regexp_replace(new.username, '[^a-zA-Z0-9]', '', 'g'));
  normalized_first text := lower(regexp_replace(coalesce(new.first_name, ''), '[^a-zA-Z0-9]', '', 'g'));
  normalized_last text := lower(regexp_replace(coalesce(new.last_name, ''), '[^a-zA-Z0-9]', '', 'g'));
begin
  if length(normalized_first) > 0 and normalized_username like '%' || normalized_first || '%' then
    raise exception 'Username may not contain your first name' using errcode = '23514';
  end if;
  if length(normalized_last) > 0 and normalized_username like '%' || normalized_last || '%' then
    raise exception 'Username may not contain your last name' using errcode = '23514';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger enforce_username_privacy_trigger
  before insert or update on profiles
  for each row execute function enforce_username_privacy();
