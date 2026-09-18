-- Enigo is 18+. Until now that was checked only by the onboarding screen;
-- the profile row is written by the client directly through PostgREST, so
-- nothing on the server refused a birthdate under 18 — or a missing one.
-- The database is where the rule has to hold.
--
-- AI personas are exempt: they are not people and carry no birthdate.
-- Every real profile in production already has one, so this validates
-- against existing rows as well as new writes. current_date is evaluated
-- at write time, which is the intent: an account is checked when it is
-- created or its birthdate changes.
alter table profiles
  add constraint profiles_adult_check
  check (is_ai or (birthdate is not null and birthdate <= current_date - interval '18 years'));
