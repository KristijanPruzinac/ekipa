-- Ekipa — advisor hardening: lock down the internal RPC surface, add
-- missing FK indexes, and stop RLS policies from re-evaluating auth.uid()
-- per row. Applied after `get_advisors` flagged all of this post-0001/0002.
--
-- NOTE: the REVOKE ... FROM PUBLIC statements below turned out to be a
-- no-op against a live Supabase project — see 0004_fix_rpc_grants.sql for
-- why and the actual fix. Left here unmodified so this migration matches
-- exactly what was applied, in order, against the real database.

-- ── Security: PostgREST auto-exposes every public SECURITY DEFINER
-- function as /rest/v1/rpc/<name>. is_member/is_confirmed are internal
-- helpers only ever meant to be called from inside RLS policies (which run
-- as `authenticated`, so that grant is kept explicitly); handle_new_user/
-- handle_rsvp_change are trigger-only and never meant to be called by
-- anyone directly — triggers don't need EXECUTE to fire, only explicit SQL/
-- RPC calls do. None of this was an active leak (auth.uid() is null for an
-- anon caller, so these already returned nothing useful) but least
-- privilege is cheap here.
revoke execute on function is_member(uuid) from public;
grant execute on function is_member(uuid) to authenticated;

revoke execute on function is_confirmed(uuid) from public;
grant execute on function is_confirmed(uuid) to authenticated;

revoke execute on function handle_new_user() from public;
revoke execute on function handle_rsvp_change() from public;

-- confirmed_attendees / mutual_connections ARE meant to be called directly
-- by signed-in clients (see lib/data/repository.dart) — keep authenticated,
-- drop the anon/PUBLIC default.
revoke execute on function confirmed_attendees(uuid) from public;
grant execute on function confirmed_attendees(uuid) to authenticated;

revoke execute on function mutual_connections(uuid) from public;
grant execute on function mutual_connections(uuid) to authenticated;

-- ── Performance: covering indexes for FKs used in joins/cascades.
create index blocks_blocked_id_idx on blocks (blocked_id);
create index meetup_members_user_id_idx on meetup_members (user_id);
create index reflections_rater_id_idx on reflections (rater_id);
create index reflections_subject_id_idx on reflections (subject_id);

-- ── Performance: `(select auth.uid())` lets Postgres evaluate it once per
-- query via an InitPlan instead of once per row.
drop policy profiles_select_own on profiles;
create policy profiles_select_own on profiles
  for select using (id = (select auth.uid()));

drop policy profiles_update_own on profiles;
create policy profiles_update_own on profiles
  for update using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy profiles_insert_own on profiles;
create policy profiles_insert_own on profiles
  for insert with check (id = (select auth.uid()));

drop policy members_select_visible on meetup_members;
create policy members_select_visible on meetup_members
  for select using (
    user_id = (select auth.uid())
    or (is_confirmed(meetup_id) and is_member(meetup_id))
  );

drop policy members_update_own on meetup_members;
create policy members_update_own on meetup_members
  for update using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy reflections_rw_own on reflections;
create policy reflections_rw_own on reflections
  for all using (rater_id = (select auth.uid())) with check (rater_id = (select auth.uid()));

drop policy blocks_rw_own on blocks;
create policy blocks_rw_own on blocks
  for all using (blocker_id = (select auth.uid())) with check (blocker_id = (select auth.uid()));
