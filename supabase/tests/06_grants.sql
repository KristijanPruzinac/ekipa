-- 06 · The grant surface, asserted rather than assumed.
--
-- **Why this file exists.** The first pgTAP run ever executed failed invariant
-- 1 with `denied` where it wanted `1`, and the cause was that nine migrations
-- had written policies and no grants: the privilege came from Supabase's
-- bootstrap `alter default privileges`, so the schema behaved one way on the
-- hosted project and another way from these files. `anon` also held `select` on
-- eleven tables, harmless only because every policy happened to say
-- `to authenticated`.
--
-- A policy answers *which rows*. A grant answers *whether at all*. The suite
-- asked the first question everywhere and the second one nowhere, which is how
-- a data plane ends up secure by coincidence. These four tests ask the second
-- question, table by table, so the answer is a fact in this repository rather
-- than a property of whoever's Postgres it happens to be running on.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir ../fixtures/world.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- The read surface, in full.
--
-- Asserted as one sorted string rather than table by table, for the same reason
-- 03's function allowlist is: a list you have to *edit* to grow is a list
-- somebody has to look at. A table that quietly becomes client-readable shows
-- up here as a name that was not there before.
create function tap.test_client_readable_tables()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'
        and has_table_privilege('authenticated', c.oid, 'select')),
    'activity_templates, availability, cities, devices, equipment, genders, '
    || 'people, person_activities, person_equipment, report_categories, '
    || 'sanctions, slots',
    'DP-2: a phone may select from exactly these twelve tables');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Anonymous callers hold nothing at all.
--
-- 01_deny_by_default.sql already proves an anonymous caller *reads* nothing.
-- This proves something stronger and more durable: they are not permitted to
-- try. The difference matters the day somebody writes a policy and forgets the
-- `to authenticated` clause — 01 would start passing for the wrong reason,
-- while this stays red.
create function tap.test_anon_holds_no_grant()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'
        and (has_table_privilege('anon', c.oid, 'select')
          or has_table_privilege('anon', c.oid, 'insert')
          or has_table_privilege('anon', c.oid, 'update')
          or has_table_privilege('anon', c.oid, 'delete'))),
    '',
    'DP-2: anon holds no table privilege anywhere in public');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- No client may write to any table, ever.
--
-- Every write in this product carries a consequence a policy cannot express —
-- a phase check, a deadline, a membership test, an audit row — so every write
-- is an RPC. This is that rule as an ACL fact rather than as a convention.
create function tap.test_no_client_write_grant()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(
              c.relname || ':' || priv.name, ', ' order by c.relname), '')
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
       cross join (values ('insert'), ('update'), ('delete'), ('truncate'))
              as priv (name)
      where n.nspname = 'public' and c.relkind = 'r'
        and has_table_privilege('authenticated', c.oid, priv.name)),
    '',
    'DP-4: authenticated holds no insert, update, delete or truncate anywhere');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The default is deny, for tables that do not exist yet.
--
-- The failure this guards against is the one that happened: a future migration
-- creates a table, writes a policy, and inherits a grant nobody asked for. With
-- the default privileges revoked, the new table is unreadable until a line says
-- otherwise — so forgetting the grant fails loudly at the screen, instead of
-- succeeding quietly at the ACL.
create function tap.test_new_tables_arrive_ungranted()
returns setof text language plpgsql as $fn$
begin
  create table public.tap_probe (id integer);

  return next is(
    (select coalesce(string_agg(priv.name, ', ' order by priv.name), '')
       from (values ('select'), ('insert'), ('update'), ('delete'))
              as priv (name)
      where has_table_privilege('authenticated', 'public.tap_probe', priv.name)
         or has_table_privilege('anon', 'public.tap_probe', priv.name)),
    '',
    'DP-2: a table created now inherits no client privilege');

  drop table public.tap_probe;
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
