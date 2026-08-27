-- ============================================================================
-- PENDING MIGRATIONS — paste this whole file into the Supabase SQL Editor
-- ============================================================================
-- These three migrations exist in backend/supabase/migrations/ but were never
-- applied to the live project (szeiboavzjuembdwajfu). The app ships code that
-- reads and writes these columns, so onboarding and GIF sending both fail
-- against production until this runs.
--
-- Verified missing on 2026-08-27 via the REST schema:
--   profiles.birthdate   -> 42703 column does not exist
--   messages.gif_url     -> 42703 column does not exist
--   messages.photo_url   -> 42703 column does not exist
--   public.feedback      -> 404 table not found
--
-- Safe to re-run: every statement is guarded with IF NOT EXISTS.
-- ============================================================================

-- 20260101001300_media_messages.sql --------------------------------------
-- GIF and photo messages. gif_url is validated in send-message against the
-- giphy.com domain rather than by a CHECK constraint, so the allowlist can
-- change without a migration.
alter table messages add column if not exists gif_url text;
alter table messages add column if not exists photo_url text;

-- 20260101001400_add_birthdate.sql ---------------------------------------
-- Age verification (18+). Not enforced in the database — birthdates get
-- corrected, and a CHECK would reject the correction — the app gates signup.
alter table profiles add column if not exists birthdate date;

-- 20260101001500_feedback_table.sql --------------------------------------
create table if not exists feedback (
  id bigserial primary key,
  user_id uuid not null references auth.users on delete cascade,
  message text not null,
  created_at timestamp with time zone default now() not null
);

create index if not exists idx_feedback_user_id on feedback (user_id);
create index if not exists idx_feedback_created_at on feedback (created_at);

-- Only submit-feedback writes here, and it runs as the service role, which
-- bypasses RLS. Enabling RLS with no policies denies anon and authenticated
-- outright, rather than leaving one user's feedback readable by another.
alter table feedback enable row level security;
grant all on feedback to service_role;
grant usage, select on sequence feedback_id_seq to service_role;

-- ============================================================================
-- Verify it worked — all four rows should come back 'ok'
-- ============================================================================
select 'profiles.birthdate' as item,
       case when exists (select 1 from information_schema.columns
                         where table_name='profiles' and column_name='birthdate')
            then 'ok' else 'MISSING' end as status
union all
select 'messages.gif_url',
       case when exists (select 1 from information_schema.columns
                         where table_name='messages' and column_name='gif_url')
            then 'ok' else 'MISSING' end
union all
select 'messages.photo_url',
       case when exists (select 1 from information_schema.columns
                         where table_name='messages' and column_name='photo_url')
            then 'ok' else 'MISSING' end
union all
select 'feedback table',
       case when exists (select 1 from information_schema.tables
                         where table_name='feedback')
            then 'ok' else 'MISSING' end;
