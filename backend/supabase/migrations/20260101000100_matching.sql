-- Matching query used by the find-match edge function. Lives in SQL because
-- it's a geo + array-overlap + jsonb-scoring query that belongs closer to
-- the data than reimplemented in JS. Callable only via the service role
-- (edge functions use supabaseAdmin) — not exposed to clients directly.
--
-- Community-answer compatibility is a product judgment call not fully
-- specified in the design doc (it only says the effect is "a filter, a
-- lean, or nothing" per option, and that the choice is never shown to
-- anyone). Implemented here as: 'in_community' is a hard mutual filter
-- (only pairs with another 'in_community' or an 'open' profile); 'open' has
-- no filtering effect of its own (it's the lean, not yet scored); 'not_looking'
-- and 'rather_not_say' never block a match. Revisit against real product
-- guidance before shipping.

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
        where (m.user_a = caller.id and m.user_b = c.id)
           or (m.user_a = c.id and m.user_b = caller.id)
      )
      and not exists (
        select 1 from blocked_pairs b
        where (b.user_a = caller.id and b.user_b = c.id)
           or (b.user_a = c.id and b.user_b = caller.id)
      )
      -- mutual preference overlap (hard filter)
      and (('anyone' = any(caller.match_with)) or c.gender = any(caller.match_with))
      and (('anyone' = any(c.match_with)) or caller.gender = any(c.match_with))
      and (('anyone' = any(caller.shown_to)) or c.gender = any(caller.shown_to))
      and (('anyone' = any(c.shown_to)) or caller.gender = any(c.shown_to))
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

-- Only the service role (edge functions) may call this — it returns candidate
-- ids/scores that clients should never see directly.
revoke execute on function find_match_candidates(uuid, boolean) from public;
grant execute on function find_match_candidates(uuid, boolean) to service_role;
