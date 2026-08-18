-- 01 · Deny by default (DP-1, DP-2, DP-3, DP-4).
--
-- These four assertions are the floor the seven privacy invariants stand on.
-- They are deliberately written as *whole-schema* checks rather than per-table
-- ones, so a table added next month is covered by a test written today. A
-- privacy suite that only knows about the tables that existed when it was
-- written stops being a control the first time someone is in a hurry.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir fixture.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-1. Not "we reviewed the policy" — the property itself, over every table
-- that exists at the moment the test runs.
create function tap.test_rls_on_every_table()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind = 'r'
        and not c.relrowsecurity),
    '',
    'DP-1: every table in public has row level security enabled'
  );
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-2, stated as an allowlist rather than a prohibition.
--
-- "No permissive policy anywhere" cannot be checked mechanically, because the
-- catalogue legitimately needs a few. What *can* be checked is that the set of
-- policies is exactly this one, so adding any policy anywhere forces someone to
-- come here and say why. That is the whole value: the test does not decide
-- whether a new policy is safe, it makes the decision visible.
create function tap.test_policy_allowlist()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(
              string_agg(tablename || '.' || policyname || ' [' || cmd || ']',
                         ', ' order by tablename, policyname), '')
       from pg_policies where schemaname = 'public'),
    'activity_templates.activity_templates_read [SELECT], '
    || 'availability.availability_read_self [SELECT], '
    || 'cities.cities_read [SELECT], '
    || 'devices.devices_read_self [SELECT], '
    || 'equipment.equipment_read [SELECT], '
    || 'genders.genders_read [SELECT], '
    || 'people.people_read_self [SELECT], '
    || 'person_activities.person_activities_read_self [SELECT], '
    || 'person_equipment.person_equipment_read_self [SELECT], '
    || 'report_categories.report_categories_read [SELECT], '
    || 'sanctions.sanctions_read_own_visible [SELECT], '
    || 'slots.slots_read_own_city [SELECT]',
    'DP-2: the client-readable surface is exactly the twelve reviewed policies'
  );
end;
$fn$;

-- Every policy is SELECT-only, so no client write reaches a table directly
-- (DP-4). The write path is the RPC surface in 0006 and nothing else.
create function tap.test_no_write_policy_anywhere()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(tablename || '.' || policyname, ', '), '')
       from pg_policies
      where schemaname = 'public' and cmd <> 'SELECT'),
    '',
    'DP-4: no policy anywhere permits a client INSERT, UPDATE or DELETE'
  );
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-2 again, this time by asking rather than by reading catalogues: a caller
-- with no session at all reads nothing from anything.
create function tap.test_anon_reads_nothing()
returns setof text language plpgsql as $fn$
declare
  r       record;
  outcome text;
  bad     text := '';
begin
  for r in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
     order by c.relname
  loop
    outcome := tap.count_as(
      null, 'select 1 from public.' || quote_ident(r.relname));
    if outcome not in ('denied', '0') then
      bad := bad || r.relname || '=' || outcome || ' ';
    end if;
  end loop;

  return next is(btrim(bad), '',
    'DP-2: an anonymous caller reads zero rows from every table in public');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-3. Dario is a real, verified, logged-in user who happens to be in no
-- hangout with anybody. He is the shape of T1: not an intruder, just a user
-- with a proxy and some curiosity.
create function tap.test_sensitive_tables_are_invisible()
returns setof text language plpgsql as $fn$
declare
  t       text;
  outcome text;
  bad     text := '';
  v_auth  uuid := tap.auth_of(tap.dario());
begin
  foreach t in array array[
    'identities', 'ratings', 'venue_feedback', 'edges', 'exclusions',
    'reports', 'infractions', 'standing',
    'hangouts', 'hangout_members', 'hangout_events', 'person_events',
    'match_runs', 'match_run_groups',
    'config_versions', 'config_values', 'admin_roles', 'admin_audit',
    'venues', 'venue_clusters', 'sigils'
  ]
  loop
    outcome := tap.count_as(v_auth, 'select 1 from public.' || quote_ident(t));
    if outcome not in ('denied', '0') then
      bad := bad || t || '=' || outcome || ' ';
    end if;
  end loop;

  return next is(btrim(bad), '',
    'DP-3: a logged-in stranger reads zero rows from every sensitive table');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-4. The client is a hostile display surface (§2): a write that carries a
-- consequence does not land, whatever the app sends.
--
-- Each assertion checks the **effect**, not the error. Postgres refuses these
-- two different ways — a missing grant raises, while a missing UPDATE policy
-- silently matches zero rows — and a test that insisted on an exception would
-- pass for the wrong reason on half of them.
create function tap.test_direct_writes_are_refused()
returns setof text language plpgsql as $fn$
declare
  v_auth uuid := tap.auth_of(tap.alice());
begin
  perform tap.exec_as(v_auth,
    'update public.people set city_id = ' || quote_literal(tap.city_other())
    || '::uuid where id = ' || quote_literal(tap.alice()) || '::uuid');
  return next is(
    (select city_id from public.people where id = tap.alice()),
    tap.city_home(),
    'DP-4: a client cannot relocate itself into a denser city'
  );

  perform tap.exec_as(v_auth,
    'insert into public.availability (person_id, slot_id, source) values ('
    || quote_literal(tap.alice()) || '::uuid, '
    || quote_literal(tap.slot_foreign()) || '::uuid, ''manual'')');
  return next is(
    (select count(*)::int from public.availability
      where person_id = tap.alice() and slot_id = tap.slot_foreign()),
    0,
    'DP-4: a client cannot write availability for another city directly'
  );

  perform tap.exec_as(v_auth,
    'update public.hangout_members set confirmation = ''yes'' where person_id = '
    || quote_literal(tap.alice()) || '::uuid');
  return next is(
    (select count(*)::int from public.hangout_members
      where person_id = tap.alice() and confirmation is not null),
    0,
    'DP-4: a client cannot confirm by writing the membership row'
  );

  perform tap.exec_as(v_auth,
    'delete from public.infractions where person_id = '
    || quote_literal(tap.alice()) || '::uuid');
  return next is(
    (select count(*)::int from public.infractions
      where person_id = tap.alice()),
    1,
    'rule 10: a client cannot erase its own evidence'
  );
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
