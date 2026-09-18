-- App Review fixture: a real person-to-person correspondence for the demo
-- account, so a reviewer sees the product rather than the AI placeholder.
--
-- Why this exists. Enigo has no public users yet, so until now every
-- reviewer who signed in with the demo number was paired with an AI persona
-- (find-match's bootstrap fallback) — under a banner we added ourselves
-- saying so. From the reviewer's chair the app was "answer eleven
-- questions, then chat with an AI", and 1.0 was rejected under 4.3(a) as a
-- look-alike of the AI-companion apps that pattern describes.
--
-- Two demo accounts, both signed in with the test OTP in config.toml:
--
--   +1 555 555 0100  Lands on the dashboard mid-correspondence with a
--                    member of the Enigo team. ~28 messages over ten days,
--                    "interests" already unlocked, bio/location/photo still
--                    sealed. Shows the mechanic partway through.
--   +1 555 555 0101  Has no profile, so it runs the full onboarding (age
--                    gate, eleven questions, interests) and then searches
--                    like any new account. Its first real candidate is the
--                    same team account, which holds Pro so it has room.
--
-- The team account is the existing enigoapp@gmail.com sign-in, so a person
-- can actually answer whatever a reviewer writes.
--
-- Everything is done by one function, so the fixture can be put back with
-- a single call whenever a reviewer ends, reports, or otherwise disturbs
-- the match — service role only, never reachable from a client:
--
--   npx supabase db query --linked "select review_fixture_reset()"

create or replace function review_fixture_reset() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  reviewer_phone constant text := '15555550100';
  fresh_phone    constant text := '15555550101';
  partner_email  constant text := 'enigoapp@gmail.com';

  v_reviewer uuid;
  v_fresh    uuid;
  v_partner  uuid;
  v_match    uuid;
  -- Conversation starts eleven days ago and ends yesterday, so it reads as
  -- current no matter when the fixture is reset.
  t0 timestamptz := date_trunc('day', now()) - interval '11 days' + interval '9 hours';
  v_heavy_min integer;
  v_interests_at integer;
  v_min_heavy integer;
  v_unlock_at timestamptz;
begin
  -- -------------------------------------------------------------------
  -- 1. Auth users. The reviewer's and partner's rows already exist in
  --    production (created by earlier sign-ins); the branches below only
  --    matter on a fresh database. Reusing the existing rows is what keeps
  --    GoTrue's test-OTP sign-in landing on the seeded profile.
  -- -------------------------------------------------------------------
  select id into v_reviewer from auth.users where phone = reviewer_phone;
  if v_reviewer is null then
    v_reviewer := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, phone, phone_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      is_super_admin, confirmation_token, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_reviewer,
      'authenticated', 'authenticated', reviewer_phone, now(),
      now(), now(), '{"provider":"phone","providers":["phone"]}', '{}',
      false, '', ''
    );
  end if;

  select id into v_partner from auth.users where email = partner_email;
  if v_partner is null then
    v_partner := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      is_super_admin, confirmation_token, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_partner,
      'authenticated', 'authenticated', partner_email, now(),
      now(), now(), '{"provider":"email","providers":["email"]}', '{}',
      false, '', ''
    );
  end if;

  -- The fresh account is created by GoTrue on its first sign-in; nothing
  -- to insert. If it exists we only need to clear its profile so the next
  -- sign-in runs onboarding again.
  select id into v_fresh from auth.users where phone = fresh_phone;

  -- -------------------------------------------------------------------
  -- 2. Clear whatever a previous reviewer left behind on the two demo
  --    accounts. Deleting the profile cascades to matches, messages,
  --    counters, unlocks, subscriptions and device tokens; the two
  --    references without a cascade are cleared by hand first.
  -- -------------------------------------------------------------------
  update matches set ended_by = null
    where ended_by in (v_reviewer, v_fresh);
  delete from reports
    where reporter_id in (v_reviewer, v_fresh)
       or match_id in (
         select id from matches
         where user_a in (v_reviewer, v_fresh) or user_b in (v_reviewer, v_fresh)
       );
  delete from blocked_pairs
    where user_a in (v_reviewer, v_fresh) or user_b in (v_reviewer, v_fresh);
  delete from profiles where id in (v_reviewer, v_fresh);

  -- -------------------------------------------------------------------
  -- 3. Profiles. Neither shares a location, so distance never gates the
  --    fresh account's search. The partner is open to anyone so that
  --    whatever a reviewer picks in onboarding, this account qualifies.
  -- -------------------------------------------------------------------
  insert into profiles (
    id, username, first_name, show_first_name, gender,
    match_with, shown_to, community, intent,
    interests, bio, location_granted, radius_km,
    answers, birthdate, onboarding_complete, created_at
  ) values (
    v_reviewer, 'farmeadow', 'Sam', false, 'woman',
    array['anyone'], array['anyone'], 'open', 'open',
    array['Photography', 'Trains', 'Sunday papers', 'Cooking', 'Hiking'],
    'I take the slow train when there is one.', false, null,
    '{"1":0,"2":3,"3":0,"4":0,"5":1,"6":0,"7":1,"8":0,"9":0,"10":0,"11":0}'::jsonb,
    date '1994-03-12', true, t0 - interval '1 hour'
  );

  insert into profiles (
    id, username, first_name, show_first_name, gender,
    match_with, shown_to, community, intent,
    interests, bio, location_granted, radius_km,
    answers, birthdate, onboarding_complete, created_at
  ) values (
    v_partner, 'amberwillow', 'Jo', false, 'man',
    array['anyone'], array['anyone'], 'open', 'open',
    array['Secondhand books', 'Cold water', 'Maps', 'Baking', 'Long walks'],
    'Most mornings start with bread and end with a map.', false, null,
    '{"1":0,"2":3,"3":0,"4":0,"5":1,"6":2,"7":1,"8":0,"9":0,"10":0,"11":0}'::jsonb,
    date '1991-07-04', true, t0 - interval '2 days'
  )
  on conflict (id) do update set
    username = excluded.username,
    first_name = excluded.first_name,
    show_first_name = excluded.show_first_name,
    gender = excluded.gender,
    match_with = excluded.match_with,
    shown_to = excluded.shown_to,
    community = excluded.community,
    intent = excluded.intent,
    interests = excluded.interests,
    bio = excluded.bio,
    location_granted = excluded.location_granted,
    radius_km = excluded.radius_km,
    answers = excluded.answers,
    birthdate = excluded.birthdate,
    onboarding_complete = true;

  -- Pro on the team account: three concurrent slots, so it can hold the
  -- seeded match and still be the first real candidate for the fresh
  -- account (and for a second reviewer device, if they use one).
  insert into subscriptions (user_id, tier, status, current_period_end)
  values (v_partner, 'pro', 'active', now() + interval '10 years')
  on conflict (user_id) do update set
    tier = 'pro', status = 'active',
    current_period_end = now() + interval '10 years',
    updated_at = now();

  -- -------------------------------------------------------------------
  -- 4. The match and its correspondence. A real match, not an AI one.
  -- -------------------------------------------------------------------
  insert into matches (user_a, user_b, status, is_ai_match, created_at)
  values (v_reviewer, v_partner, 'active', false, t0 - interval '30 minutes')
  returning id into v_match;

  -- Heaviness is decided by the same config the live mechanic reads, so
  -- the seeded rows are exactly what send-message would have produced.
  select (value #>> '{}')::integer into v_heavy_min
    from app_config where key = 'heavy_message_min_chars';

  insert into messages (match_id, sender_id, body, char_count, is_heavy, created_at)
  select v_match,
         case who when 'P' then v_partner else v_reviewer end,
         body, length(body), length(body) >= v_heavy_min, t0 + at
  from (values
    -- day 0
    ('P', interval '0 days 00:00', 'Hello. I''m told we answered eleven questions the same way, so I''ll start with the twelfth: what did you have for breakfast?'),
    ('R', interval '0 days 00:41', 'Toast, slightly burnt, eaten standing up. I was already late for a train I didn''t end up catching.'),
    ('P', interval '0 days 02:10', 'A missed train is the best kind of morning. Where were you meant to be going?'),
    ('R', interval '0 days 03:05', 'Two towns over, to photograph a bridge before they replace it. It will still be there tomorrow, apparently.'),
    -- day 1
    ('P', interval '1 days 00:20', 'I have opinions about bridges. Old ones in particular. Which kind is yours, stone or iron?'),
    ('R', interval '1 days 04:47', 'Iron, riveted, painted a green that has mostly given up. I like things that show their age honestly.'),
    ('P', interval '1 days 09:12', 'That''s a very specific green. I know exactly the one.'),
    -- day 2
    ('R', interval '2 days 01:30', 'Tell me something ordinary about your day. I find the ordinary parts are the ones people leave out.'),
    ('P', interval '2 days 03:55', 'I proved bread too long and it fell in on itself. Ate it anyway, warm, with too much butter. No regrets.'),
    ('R', interval '2 days 04:02', 'Ha. Collapsed bread is still bread.'),
    ('R', interval '2 days 10:40', 'I cooked for four last night and everyone stayed later than they meant to. That''s my favourite kind of evening.'),
    -- day 3
    ('P', interval '3 days 00:15', 'Long conversation, one person. That was my answer to the free evening question. I''m guessing it was yours too.'),
    ('R', interval '3 days 02:38', 'It was. Though I''d have said a room full of people if I''d been asked on a different day. Depends on the week.'),
    ('P', interval '3 days 06:20', 'Fair. Do you write back within minutes, or when you have something to say? I''m the second one, obviously.'),
    ('R', interval '3 days 06:24', 'Within minutes, most days. I''m trying to be more like you about it.'),
    -- day 5
    ('P', interval '5 days 01:05', 'Quiet couple of days. I walked a long way with no destination and came back with cold hands and nothing to report.'),
    ('R', interval '5 days 03:50', 'Nothing to report is a full report. I spent Sunday with the papers and didn''t finish a single article.'),
    ('P', interval '5 days 05:30', 'Which section do you go to first? I think it says something about a person.'),
    ('R', interval '5 days 08:15', 'The letters page, always. People arguing carefully with strangers. I suppose that''s a bit like this.'),
    -- day 7
    ('P', interval '7 days 00:45', 'A misunderstanding is sitting between you. I picked "ask, don''t assume". So: what''s something people assume about you?'),
    ('R', interval '7 days 03:10', 'That I''m quiet because I''m shy. I''m quiet because I''m listening. Different thing entirely.'),
    ('P', interval '7 days 04:00', 'Noted, carefully. I''ll try to give you things worth listening to.'),
    -- day 8
    ('R', interval '8 days 02:25', 'Cold water. Have you ever gone in properly, in winter? I''ve always wanted to and never have.'),
    ('P', interval '8 days 03:15', 'Every week, when I can. The first minute is a bad idea and the second is the best part of the week.'),
    ('R', interval '8 days 03:40', 'You''ve talked me into it. Ask me again next week and I''ll have a report.'),
    -- day 9: both sides have now cleared the first threshold
    ('P', interval '9 days 01:00', 'I''ll hold you to it. In the meantime, it looks like something unlocked. I like your list.'),
    ('R', interval '9 days 05:20', 'Yours too. Secondhand books and maps. I could have guessed the maps.'),
    -- day 10 (yesterday)
    ('P', interval '10 days 00:30', 'Still here. Slower to write this week, but here. Tell me about the bridge, did it get replaced?')
  ) as v(who, at, body);

  -- Counters derived from the rows above, the way recordMessage would have
  -- built them one message at a time. The partner has read everything; the
  -- reviewer's own read marker is refreshed by get-match-state on open.
  insert into match_counters (match_id, user_id, heavy_count, char_count, last_read_at)
  select v_match, u.id,
         count(m.id) filter (where m.is_heavy),
         coalesce(sum(m.char_count), 0),
         case when u.id = v_partner then t0 + interval '10 days 00:29' else t0 + interval '9 days 05:21' end
  from (values (v_reviewer), (v_partner)) as u(id)
  left join messages m on m.match_id = v_match and m.sender_id = u.id
  group by u.id;

  -- Unlock "interests" if, and only if, both sides cleared its threshold —
  -- the same rule as checkAndApplyUnlocks, so the fixture can never claim
  -- an unlock the live mechanic wouldn't have granted.
  select heavy_count_required into v_interests_at from unlock_thresholds where field = 'interests';
  select min(heavy_count) into v_min_heavy from match_counters where match_id = v_match;
  if v_min_heavy >= v_interests_at then
    -- Timestamp of the message that tipped the second participant over.
    select created_at into v_unlock_at
    from (
      select created_at,
             count(*) over (partition by sender_id order by created_at) as nth
      from messages where match_id = v_match and is_heavy
    ) x
    where nth = v_interests_at
    order by created_at desc limit 1;
    insert into unlocks (match_id, field, unlocked_at) values (v_match, 'interests', v_unlock_at);
  end if;

  return jsonb_build_object(
    'reviewer', v_reviewer,
    'partner', v_partner,
    'fresh', v_fresh,
    'match', v_match,
    'messages', (select count(*) from messages where match_id = v_match),
    'heavy', (select jsonb_object_agg(user_id, heavy_count) from match_counters where match_id = v_match),
    'unlocked', (select coalesce(jsonb_agg(field), '[]'::jsonb) from unlocks where match_id = v_match)
  );
end;
$$;

revoke all on function review_fixture_reset() from public;
grant execute on function review_fixture_reset() to service_role;
