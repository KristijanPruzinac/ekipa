-- 0003 tried to lock down the internal RPC surface via `REVOKE ... FROM
-- PUBLIC`, but Supabase grants EXECUTE to anon/authenticated/service_role
-- as explicit per-role ACL entries at function-creation time (its default
-- privileges are set per-role, not via the PUBLIC pseudo-role) — so
-- `REVOKE ... FROM PUBLIC` had nothing to remove. Confirmed by inspecting
-- pg_proc.proacl directly before and after: anon/authenticated were still
-- listed verbatim after 0003 ran. Revoking from the actual role names here.

revoke execute on function is_member(uuid) from anon;
revoke execute on function is_confirmed(uuid) from anon;
revoke execute on function confirmed_attendees(uuid) from anon;
revoke execute on function mutual_connections(uuid) from anon;
revoke execute on function handle_new_user() from anon, authenticated;
revoke execute on function handle_rsvp_change() from anon, authenticated;
