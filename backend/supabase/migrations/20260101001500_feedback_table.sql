create table feedback (
  id bigserial primary key,
  user_id uuid not null references auth.users on delete cascade,
  message text not null,
  created_at timestamp with time zone default now() not null
);

create index idx_feedback_user_id on feedback (user_id);
create index idx_feedback_created_at on feedback (created_at);
