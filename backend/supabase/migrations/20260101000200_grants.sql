-- This Supabase project defaults new tables to NOT auto-exposed to the Data
-- API roles (see [api] auto_expose_new_tables in config.toml), so explicit
-- GRANTs are required even for the service role. RLS policies (from the
-- schema migration) still apply on top of these for anon/authenticated —
-- granting a privilege here does not bypass RLS, it only makes the table
-- reachable at all.

-- service_role: full access, used only by edge functions (ctx.supabaseAdmin).
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;

-- authenticated: only the tables/columns a client is ever meant to touch
-- directly. match_counters, unlock_thresholds, app_config, reports, and
-- blocked_pairs intentionally get no grant at all here — combined with
-- having no RLS policy for authenticated, that's a deny at two layers, not
-- just one.
grant usage on schema public to authenticated;
grant select, insert, update on profiles to authenticated;
grant select on matches to authenticated;
grant select on unlocks to authenticated;
grant select on messages to authenticated;
