-- 05 · The console's access control, as a property of the database.
--
-- `docs/v3/12_CONSOLE.md` §5 lists eight controls. Four of them are claims a
-- document cannot keep on its own — MFA, the role ladder, the audit trail, and
-- append-only evidence — so they are asserted here against the same role switch
-- every other file in this suite uses.
--
-- The stance that makes these tests meaningful: the console is a browser app
-- holding a user's JWT, and 11_SECURITY.md §2 says everything it sends is a
-- claim by an attacker who happens to be a user. So every assertion below is
-- made from inside `tap.become` — the whole of what a client has — and never
-- from the owner role.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir ../fixtures/world.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- AC-2. MFA is a permission, not a setting.
create function tap.test_mfa_is_enforced_by_the_database()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.value_as(tap.operator(), 'select public.admin_role()'),
    'operator',
    'AC-2: an operator who completed a second factor has their role');

  -- The same person, the same row in admin_roles, a session that stopped at a
  -- password. "MFA required. No exceptions, including for you" is a sentence
  -- in a document until something refuses.
  return next is(
    tap.value_as(tap.operator(), 'select public.admin_role()', 'aal1'),
    '(null)',
    'AC-2: the same operator without a second factor has no role at all');

  return next is(
    tap.value_as(tap.operator(),
      'select public.console_config_versions(10)::text', 'aal1'),
    'ERR:42501',
    'AC-2: and every console function refuses them, not just the helper');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- AC-3. The ladder, and least privilege by default.
create function tap.test_the_role_ladder()
returns setof text language plpgsql as $fn$
declare
  v_ana uuid := tap.auth_of(tap.alice());
begin
  return next is(
    tap.value_as(tap.viewer(), 'select public.admin_at_least(''viewer'')::text'),
    'true',
    'AC-3: a viewer is at least a viewer');

  return next is(
    tap.value_as(tap.viewer(),
      'select public.admin_at_least(''operator'')::text'),
    'false',
    'AC-3: and is not an operator');

  return next is(
    tap.value_as(tap.owner(), 'select public.admin_at_least(''operator'')::text'),
    'true',
    'AC-3: an owner is at least an operator — the ladder is an ordering');

  -- The control that matters most, because it is the one a real session has:
  -- an ordinary member of the product, fully authenticated, holding a valid
  -- JWT, with no row in admin_roles.
  return next is(
    tap.value_as(v_ana, 'select public.admin_role()'),
    '(null)',
    'AC-3: an ordinary user has no console role');

  return next is(
    tap.value_as(v_ana, 'select public.console_config_versions(10)::text'),
    'ERR:42501',
    'AC-3: and is refused by the console read surface');

  return next is(
    tap.value_as(null, 'select public.console_config_versions(10)::text'),
    'ERR:42501',
    'AC-3: as is an anonymous caller');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- AC-4. No service-role key in the browser: the tables themselves stay closed,
-- and the only way in is a function that re-checks the role.
create function tap.test_the_tables_stay_closed_to_the_console()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.count_as(tap.owner(), 'select 1 from public.config_versions'),
    'denied',
    'AC-4: even an owner cannot read config_versions directly');

  return next is(
    tap.count_as(tap.owner(), 'select 1 from public.admin_audit'),
    'denied',
    'AC-4: nor the audit log');

  return next is(
    tap.count_as(tap.owner(), 'select 1 from public.people'),
    'denied',
    'AC-4: nor the people table, which the console has no view over at all');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Publishing a version. The four things the server re-checks, because nothing
-- the app displays is a permission.
create function tap.test_publishing_a_config_version()
returns setof text language plpgsql as $fn$
declare
  v_call text := 'select public.console_publish_config(%L, %L::timestamptz, '
                 || '%L::jsonb, %L)::text';
  v_values text := '[{"key": "matching.cooldown_days", "scope_kind": "global",'
                   || ' "scope_ref": "", "value": 14}]';
  v_version text;
begin
  return next is(
    tap.value_as(tap.viewer(),
      format(v_call, 'a note', now() + interval '1 hour', v_values, 'why')),
    'ERR:42501',
    'a viewer may read configuration and may not change it');

  return next is(
    tap.value_as(tap.operator(),
      format(v_call, 'a note', now() - interval '1 hour', v_values, 'why')),
    'ERR:22023',
    'a version cannot take effect in the past — the rule versioning exists for');

  return next is(
    tap.value_as(tap.operator(),
      format(v_call, 'a note', now() + interval '1 hour', v_values, '  ')),
    'ERR:22023',
    'AC-6: and cannot be published without a typed reason');

  return next is(
    tap.value_as(tap.operator(),
      format(v_call, '', now() + interval '1 hour', v_values, 'why')),
    'ERR:22023',
    'or without a note saying what it is');

  -- A scope that reads as targeted and behaves as a second global layer.
  return next is(
    tap.value_as(tap.operator(),
      format(v_call, 'a note', now() + interval '1 hour',
        '[{"key": "matching.cooldown_days", "scope_kind": "city",'
        || ' "scope_ref": "", "value": 14}]', 'why')),
    'ERR:22023',
    'a city scope with no city is refused rather than silently outranking '
    'the global layer');

  v_version := tap.value_as(tap.operator(),
    format(v_call, 'shorten the cooldown', now() + interval '1 hour',
           v_values, 'the simulator says clique formation drops'));

  return next isnt(v_version, '(null)', 'a well-formed version is written');
  return next matches(v_version, '^[0-9a-f]{8}-[0-9a-f]{4}-',
    'and its id comes back');

  return next is(
    (select count(*)::text from public.config_values
      where version_id = v_version::uuid),
    '1',
    'with its values');

  -- A version is written unpublished. A browser tab that dies halfway through
  -- must not be able to leave half-entered rules live.
  return next is(
    (select published::text from public.config_versions
      where id = v_version::uuid),
    'false',
    'and it is not live until somebody publishes it');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- AC-5 and AC-8. The trail is written, and cannot be unwritten.
create function tap.test_the_audit_trail()
returns setof text language plpgsql as $fn$
declare
  v_before bigint;
  v_version text;
begin
  select count(*) into v_before from public.admin_audit;

  v_version := tap.value_as(tap.operator(),
    format('select public.console_publish_config(%L, %L::timestamptz, '
           || '%L::jsonb, %L)::text',
           'a note', now() + interval '1 hour',
           '[{"key": "matching.cooldown_days", "scope_kind": "global",'
           || ' "scope_ref": "", "value": 14}]',
           'because the simulator said so'));

  return next is(
    (select count(*) - v_before from public.admin_audit)::text,
    '1',
    'AC-5: publishing writes exactly one audit row');

  return next is(
    (select actor::text from public.admin_audit
      order by id desc limit 1),
    tap.operator()::text,
    'AC-5: naming who did it');

  return next is(
    (select reason from public.admin_audit order by id desc limit 1),
    'because the simulator said so',
    'AC-5: and why');

  -- AC-8 as a permission rather than a policy. The console holds no delete or
  -- update grant on the audit log, so "the operator cannot erase their own
  -- trail" is a property of the database and not a promise in a document.
  return next is(
    tap.exec_as(tap.owner(), 'delete from public.admin_audit'),
    'ERR:42501',
    'AC-8: an owner cannot delete an audit row');

  return next is(
    tap.exec_as(tap.owner(),
      'update public.admin_audit set reason = ''nothing happened'''),
    'ERR:42501',
    'AC-8: nor rewrite one');

  return next is(
    tap.exec_as(tap.owner(), 'delete from public.infractions'),
    'ERR:42501',
    'rule 10: nor delete trust evidence');

  -- And the trail is readable by anyone who can see the console at all. A log
  -- only its writer can read protects nobody.
  return next isnt(
    tap.count_as(tap.viewer(), 'select * from public.console_audit(10)'),
    'denied',
    'AC-5: a viewer can read the trail');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The slot schedule. The one place a local time becomes an instant, and the
-- only reason that conversion is in SQL rather than in Dart.
create function tap.test_generating_slots_resolves_dst()
returns setof text language plpgsql as $fn$
declare
  v_call text := 'select public.console_generate_slots(%L::uuid, %L::jsonb, '
                 || '%L, %L)::text';
  -- Either side of the last Sunday in October 2026, when Europe/Zagreb leaves
  -- summer time. Both are 17:30 to a person in the city; they are an hour
  -- apart in UTC, and nothing in Dart can know that.
  v_slots text := '['
    || '{"local_date": "2026-10-24", "local_time": "17:30", "weekday": 6,'
    || ' "minutes": 90},'
    || '{"local_date": "2026-10-31", "local_time": "17:30", "weekday": 6,'
    || ' "minutes": 90}]';
begin
  return next is(
    tap.value_as(tap.viewer(),
      format(v_call, tap.city_home(), v_slots, 'test', 'why')),
    'ERR:42501',
    'a viewer cannot change the schedule');

  return next is(
    tap.value_as(tap.operator(),
      format(v_call, tap.city_home(), v_slots, 'test', '  ')),
    'ERR:22023',
    'and an operator needs a reason for it');

  return next is(
    tap.value_as(tap.operator(),
      format(v_call, tap.city_home(), v_slots, 'schedule:6@17:30/90m',
             'opening the October weeks')),
    '2',
    'two slots are materialised');

  return next is(
    (select to_char(starts_at at time zone 'UTC', 'HH24:MI')
       from public.slots
      where city_id = tap.city_home() and local_date = date '2026-10-24'),
    '15:30',
    'summer time: 17:30 in Osijek is 15:30 UTC');

  return next is(
    (select to_char(starts_at at time zone 'UTC', 'HH24:MI')
       from public.slots
      where city_id = tap.city_home() and local_date = date '2026-10-31'),
    '16:30',
    'winter time: the same local 17:30 is 16:30 UTC, one week later');

  return next is(
    (select to_char(ends_at - starts_at, 'HH24:MI')
       from public.slots
      where city_id = tap.city_home() and local_date = date '2026-10-31'),
    '01:30',
    'and a slot is ninety minutes on both sides of the switch');

  -- Idempotent, because the second run is usually somebody checking whether
  -- the first one worked.
  return next is(
    tap.value_as(tap.operator(),
      format(v_call, tap.city_home(), v_slots, 'schedule:6@17:30/90m',
             'running it again')),
    '0',
    'generating the same slots twice adds nothing');

  return next is(
    (select count(*)::text from public.slots
      where city_id = tap.city_home()
        and local_date in (date '2026-10-24', date '2026-10-31')),
    '2',
    'and leaves two rows, not four');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The blast radius. Ids and deadlines, and nothing that names a person.
create function tap.test_in_flight_says_what_a_change_would_reach()
returns setof text language plpgsql as $fn$
begin
  return next isnt(
    tap.count_as(tap.viewer(), 'select * from public.console_in_flight()'),
    'denied',
    'a viewer can see what is in flight');

  return next is(
    tap.count_as(tap.viewer(), 'select * from public.console_in_flight()'),
    '3',
    'the three live hangouts in the fixture, and only those');

  return next is(
    tap.value_as(tap.viewer(),
      'select count(*)::text from public.console_in_flight() '
      || 'where config_version_id is not null'),
    '0',
    'none of them is pinned, which is what makes them exposed');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
