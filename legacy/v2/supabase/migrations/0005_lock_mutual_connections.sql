-- Lock down mutual_connections().
--
-- This SECURITY DEFINER function walks the reflections graph and returns the
-- ids of people you have a mutual "yes" with. It exists only for the group
-- composer (a trusted, server-side actor). PostgREST auto-exposes every
-- function as an RPC, and Supabase grants EXECUTE to anon + authenticated by
-- default — which would let any signed-in client call it and probe the private
-- reflection graph. Revoke those grants so only service_role can invoke it.
revoke execute on function mutual_connections(uuid) from authenticated;
revoke execute on function mutual_connections(uuid) from anon;
