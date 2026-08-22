-- Bug fix: the "already matched before" exclusion blocked re-matching ANY
-- past pair, including an ended AI-bootstrap match. With only one persona
-- seeded per gender category, that meant a user who ever ended their AI
-- match had no path back to AI bootstrapping again for that preference —
-- permanently stuck once real candidates ran out, no matter how long they
-- waited. Real people should never be re-matched after a past match (that
-- exclusion stays), but an AI persona is a bootstrap filler, not a person —
-- there's no reason re-serving the same one once an earlier match with them
-- has ended should ever be off the table.
create or replace function find_match_candidates(p_caller_id uuid, p_include_ai boolean)
returns table (candidate_id uuid, distance_km double precision, score integer)
language sql
security definer
set search_path = public
as $$
  with caller as (
    select * from profiles where id = p_caller_id
  ),
  scored as (
    select
      c.id as candidate_id,
      case
        when caller.lat is null or caller.lng is null or c.lat is null or c.lng is null then null
        else 6371 * acos(
          least(1.0, greatest(-1.0,
            cos(radians(caller.lat)) * cos(radians(c.lat)) * cos(radians(c.lng) - radians(caller.lng))
            + sin(radians(caller.lat)) * sin(radians(c.lat))
          ))
        )
      end as distance_km,
      (
        select count(*)::int
        from jsonb_each_text(caller.answers) ca
        join jsonb_each_text(c.answers) cc on ca.key = cc.key and ca.value = cc.value
      ) as score
    from profiles c, caller
    where c.id <> caller.id
      and c.is_ai = p_include_ai
      and c.onboarding_complete
      and not exists (
        select 1 from matches m
        where ((m.user_a = caller.id and m.user_b = c.id) or (m.user_a = c.id and m.user_b = caller.id))
          and not (c.is_ai and m.status = 'ended')
      )
      and not exists (
        select 1 from blocked_pairs b
        where (b.user_a = caller.id and b.user_b = c.id)
           or (b.user_a = c.id and b.user_b = caller.id)
      )
      -- mutual preference overlap (hard filter) — map gender to its plural
      -- category label before comparing against match_with/shown_to.
      and (('anyone' = any(caller.match_with)) or (case c.gender when 'man' then 'men' when 'woman' then 'women' else c.gender end) = any(caller.match_with))
      and (('anyone' = any(c.match_with)) or (case caller.gender when 'man' then 'men' when 'woman' then 'women' else caller.gender end) = any(c.match_with))
      and (('anyone' = any(caller.shown_to)) or (case c.gender when 'man' then 'men' when 'woman' then 'women' else c.gender end) = any(caller.shown_to))
      and (('anyone' = any(c.shown_to)) or (case caller.gender when 'man' then 'men' when 'woman' then 'women' else caller.gender end) = any(c.shown_to))
      -- community compatibility (see note above)
      and not (
        (caller.community = 'in_community' and c.community not in ('in_community', 'open'))
        or (c.community = 'in_community' and caller.community not in ('in_community', 'open'))
      )
  )
  select candidate_id, distance_km, score
  from scored, caller
  where (
    distance_km is null
    or (distance_km <= coalesce(caller.radius_km, 100000) and distance_km <= coalesce((select radius_km from profiles where id = scored.candidate_id), 100000))
  )
  order by score desc, distance_km asc nulls last
  limit 5;
$$;

revoke execute on function find_match_candidates(uuid, boolean) from public;
grant execute on function find_match_candidates(uuid, boolean) to service_role;
