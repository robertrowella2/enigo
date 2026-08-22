-- One row per (user, device) push token, registered by the client once
-- notification permission is granted. A user can have more than one device
-- registered at a time (e.g. a reinstall before the old token expires), so
-- this isn't a single column on profiles.
create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, platform, token)
);

create index device_tokens_user_id_idx on device_tokens (user_id);

alter table device_tokens enable row level security;

create policy "device_tokens: owner can manage their own"
  on device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on device_tokens to authenticated;
grant all on device_tokens to service_role;
