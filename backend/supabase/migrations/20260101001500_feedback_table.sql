create table feedback (
  id bigserial primary key,
  user_id uuid not null references auth.users on delete cascade,
  message text not null,
  created_at timestamp with time zone default now() not null
);

create index idx_feedback_user_id on feedback (user_id);
create index idx_feedback_created_at on feedback (created_at);

-- Only submit-feedback writes here, and it runs as the service role, which
-- bypasses RLS. So enable RLS with no policies at all: that denies anon and
-- authenticated outright rather than leaving one user's feedback readable by
-- another. Matching the device_tokens pattern, minus the owner policy, since
-- nothing client-side ever reads this back.
alter table feedback enable row level security;
grant all on feedback to service_role;
grant usage, select on sequence feedback_id_seq to service_role;
