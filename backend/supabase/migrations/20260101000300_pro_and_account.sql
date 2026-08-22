-- Adds: subscriptions (Pro tier), rematch credits (soft-exit), notification
-- prefs, and the columns/tables needed for the report and account-management
-- flows. See design_handoff_enigo/README.md sections "Pro & account".

alter table profiles add column rematch_credits integer not null default 3;
alter table profiles add column notify_messages boolean not null default true;
alter table profiles add column notify_unlocks boolean not null default true;

-- ---------------------------------------------------------------------------
-- subscriptions — one row per user, tracks the Pro tier.
--
-- record-purchase verifies each purchase server-to-server (App Store Server
-- API for iOS, Play Developer API for Android — see
-- functions/_shared/appStoreServerApi.ts and
-- functions/_shared/playDeveloperApi.ts) whenever the corresponding secrets
-- (APPLE_ISSUER_ID/APPLE_KEY_ID/APPLE_PRIVATE_KEY/APPLE_BUNDLE_ID or
-- GOOGLE_SERVICE_ACCOUNT_JSON/GOOGLE_PACKAGE_NAME) are set. Without those
-- secrets it falls back to trusting the client's word (dev only, logs a
-- warning every time) so local testing doesn't need real store credentials.
-- ---------------------------------------------------------------------------
create table subscriptions (
  user_id uuid primary key references profiles (id) on delete cascade,
  tier text not null default 'free' check (tier in ('free', 'pro')),
  platform text check (platform in ('ios', 'android')),
  product_id text,
  transaction_id text,
  status text not null default 'active' check (status in ('active', 'cancelled', 'expired')),
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table subscriptions enable row level security;

create policy "subscriptions: read own row" on subscriptions
  for select using (auth.uid() = user_id);
-- No client insert/update — only record-purchase / redeem-boost (service role) write this.

grant select on subscriptions to authenticated;
grant all on subscriptions to service_role;

-- ---------------------------------------------------------------------------
-- matches: is_ai_match already exists; add an end reason + who ended it, for
-- the soft-exit and report flows.
-- ---------------------------------------------------------------------------
alter table matches add column end_reason text check (end_reason in ('soft_exit', 'report', 'upgraded_to_real'));
alter table matches add column ended_by uuid references profiles (id);
