-- Enigo core schema.
-- Design invariants this schema exists to enforce (see design_handoff_enigo/README.md,
-- "The core mechanic — implement server-side"):
--   1. Per-person counters, never pooled.
--   2. Character-weighted messages (heavy = length >= threshold).
--   3. Thresholds and counts are NEVER exposed to clients — enforced here via RLS
--      (match_counters and unlock_thresholds have no SELECT policy at all).
--   4. Unlock order is fixed: interests -> bio -> location -> photo.
--   5. Photo/bio/location access is enforced server-side, not a client `hidden` flag.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  first_name text,
  show_first_name boolean not null default false,

  gender text check (gender in ('woman', 'man', 'nonbinary', 'self_described')),
  gender_self_description text,

  match_with text[] not null default '{}',   -- subset of men/women/nonbinary/anyone
  shown_to text[] not null default '{}',
  community text check (community in ('in_community', 'open', 'not_looking', 'rather_not_say')),
  intent text check (intent in ('close_friend', 'open', 'not_sure')),

  interests text[] not null default '{}',
  bio text,
  photo_path text,                            -- path in the private `photos` bucket, nullable until uploaded

  lat double precision,
  lng double precision,
  radius_km integer check (radius_km in (25, 50, 100)) ,  -- null = "Anywhere"
  location_granted boolean not null default false,

  answers jsonb not null default '{}',        -- {"1": 0, "2": 3, ...} question index -> option index

  is_ai boolean not null default false,
  ai_system_prompt text,                      -- only set for is_ai = true rows

  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles: read own row" on profiles
  for select using (auth.uid() = id);

create policy "profiles: insert own row" on profiles
  for insert with check (auth.uid() = id);

create policy "profiles: update own row" on profiles
  for update using (auth.uid() = id);

-- No policy allows a client to read another user's profile row directly.
-- Matched-partner data is exposed only through the get-match-state edge
-- function, which runs with the service role and filters by `unlocks`.

-- ---------------------------------------------------------------------------
-- matches
-- ---------------------------------------------------------------------------
create table matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references profiles (id) on delete cascade,
  user_b uuid not null references profiles (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'ended')),
  is_ai_match boolean not null default false,
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  check (user_a <> user_b)
);

create index matches_user_a_idx on matches (user_a) where status = 'active';
create index matches_user_b_idx on matches (user_b) where status = 'active';

alter table matches enable row level security;

create policy "matches: participants can read" on matches
  for select using (auth.uid() = user_a or auth.uid() = user_b);

-- Matches are only created/ended by the find-match / ai-reply edge functions
-- (service role) — no client insert/update policy.

-- ---------------------------------------------------------------------------
-- match_counters — per-person, never pooled, never exposed to clients
-- ---------------------------------------------------------------------------
create table match_counters (
  match_id uuid not null references matches (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  heavy_count integer not null default 0,
  char_count bigint not null default 0,
  primary key (match_id, user_id)
);

alter table match_counters enable row level security;
-- Intentionally no policies: only the service role (edge functions) may
-- read or write this table. Clients must never learn raw counts.

-- ---------------------------------------------------------------------------
-- unlock_thresholds — global config, never exposed to clients
-- ---------------------------------------------------------------------------
create table unlock_thresholds (
  field text primary key check (field in ('interests', 'bio', 'location', 'photo')),
  stage_order integer not null unique,
  heavy_count_required integer not null
);

alter table unlock_thresholds enable row level security;
-- No policies: service role only.

insert into unlock_thresholds (field, stage_order, heavy_count_required) values
  ('interests', 1, 12),
  ('bio', 2, 30),
  ('location', 3, 55),
  ('photo', 4, 90);

-- Minimum message length (characters) to count as a "heavy" message at all.
-- Kept alongside thresholds so it can be tuned without a code deploy.
create table app_config (
  key text primary key,
  value jsonb not null
);
alter table app_config enable row level security;
-- No policies: service role only.

insert into app_config (key, value) values
  ('heavy_message_min_chars', '40'),
  ('ai_matching_enabled', 'true'),
  ('match_search_window_seconds', '20');

-- ---------------------------------------------------------------------------
-- unlocks — presence = unlocked
-- ---------------------------------------------------------------------------
create table unlocks (
  match_id uuid not null references matches (id) on delete cascade,
  field text not null references unlock_thresholds (field),
  unlocked_at timestamptz not null default now(),
  primary key (match_id, field)
);

alter table unlocks enable row level security;

create policy "unlocks: participants can read" on unlocks
  for select using (
    exists (
      select 1 from matches m
      where m.id = unlocks.match_id
        and (m.user_a = auth.uid() or m.user_b = auth.uid())
    )
  );
-- No client insert — only send-message (service role) inserts unlocks.

-- ---------------------------------------------------------------------------
-- messages
-- ---------------------------------------------------------------------------
create table messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references matches (id) on delete cascade,
  sender_id uuid references profiles (id) on delete cascade,  -- null for system messages
  body text not null,
  char_count integer not null,
  is_heavy boolean not null default false,
  is_system boolean not null default false,
  created_at timestamptz not null default now()
);

create index messages_match_id_idx on messages (match_id, created_at);

alter table messages enable row level security;

create policy "messages: participants can read" on messages
  for select using (
    exists (
      select 1 from matches m
      where m.id = messages.match_id
        and (m.user_a = auth.uid() or m.user_b = auth.uid())
    )
  );
-- No client insert policy — all messages are written by the send-message
-- edge function (service role) so the heavy/counter/unlock logic can never
-- be bypassed by inserting directly into this table.

-- ---------------------------------------------------------------------------
-- reports + blocked_pairs — stubbed for a later pass, referenced by find-match
-- ---------------------------------------------------------------------------
create table reports (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references matches (id) on delete cascade,
  reporter_id uuid not null references profiles (id),
  category text not null check (category in ('harassment', 'inappropriate_content', 'fake_profile', 'money', 'other')),
  detail text,
  created_at timestamptz not null default now()
);
alter table reports enable row level security;
-- No policies yet: report submission is a deferred flow (goes through a
-- future edge function using the service role).

create table blocked_pairs (
  user_a uuid not null references profiles (id) on delete cascade,
  user_b uuid not null references profiles (id) on delete cascade,
  reason text not null default 'report',
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a <> user_b)
);
alter table blocked_pairs enable row level security;
-- No policies: service role only.

-- ---------------------------------------------------------------------------
-- storage: private photos bucket
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

-- Users may upload only to their own folder (path prefix = their user id);
-- there is no read policy for other users' photos — reveal happens only via
-- get-match-state's signed URL, issued by the service role after checking
-- `unlocks`.
create policy "photos: owner can upload" on storage.objects
  for insert with check (
    bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "photos: owner can read own" on storage.objects
  for select using (
    bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text
  );
