-- The world every privacy test runs against, plus the two helpers that make a
-- test able to *be* somebody.
--
-- Included by each test file with `\ir fixture.sql`, so there is one world and
-- it is described in one place. A privacy test whose fixture lives somewhere
-- else is a test nobody can read, and a test nobody reads is a test that gets
-- weakened to make a feature pass (11_SECURITY.md §8 rule 9).
--
-- Everything below is created inside the test file's transaction and rolled
-- back with it. Nothing here reaches a real database.

drop schema if exists tap cascade;
create schema tap;

-- ─────────────────────────────────────────────────────────────────────────────
-- Becoming somebody.
--
-- `become` does exactly what a PostgREST request does and nothing more: it sets
-- the JWT claims and switches to the `authenticated` role. That is the whole of
-- the client's privilege. If a test can read something from inside `become`,
-- so can a user with a proxy (T1).
-- `p_aal` is the assurance level Supabase writes into the JWT after a second
-- factor. It defaults to `aal2` so that every existing assertion is unchanged
-- — no client RPC reads it — and so that a console test has to *opt in* to
-- being unauthenticated, which is the direction that fails safe.
create function tap.become(p_auth uuid, p_aal text default 'aal2')
returns void language plpgsql as $fn$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_auth, 'role', 'authenticated', 'aal', p_aal
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$fn$;

create function tap.become_anon() returns void language plpgsql as $fn$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role anon';
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Running a statement as somebody, and surviving the refusal.
--
-- Three outcomes are all *passes* depending on the assertion, so they are
-- returned rather than raised:
--
--   'denied'      the grant is missing — the strongest possible answer, and the
--                 one every DP-3 table must give
--   '<n>'         the statement ran and returned n rows — 0 is the RLS answer
--   'ERR:<state>' anything else, surfaced rather than swallowed, because a test
--                 that passes on the wrong error is worse than no test
--
-- The role is always restored before returning. pgTAP's result tables belong to
-- the session user, so an assertion made while still wearing `authenticated`
-- fails on a permission error and reads like a privacy pass.
create function tap.count_as(p_auth uuid, p_sql text, p_aal text default 'aal2')
returns text language plpgsql as $fn$
declare
  v_n bigint;
begin
  if p_auth is null then
    perform tap.become_anon();
  else
    perform tap.become(p_auth, p_aal);
  end if;
  begin
    execute 'select count(*) from (' || p_sql || ') q' into v_n;
  exception
    when insufficient_privilege then
      reset role;
      return 'denied';
    when others then
      reset role;
      return 'ERR:' || sqlstate;
  end;
  reset role;
  return v_n::text;
end;
$fn$;

-- Same contract for a statement whose success is the thing under test: a write
-- that must be refused, an RPC that must raise. Returns 'ok' or 'ERR:<state>'.
create function tap.exec_as(p_auth uuid, p_sql text, p_aal text default 'aal2')
returns text language plpgsql as $fn$
begin
  if p_auth is null then
    perform tap.become_anon();
  else
    perform tap.become(p_auth, p_aal);
  end if;
  begin
    execute p_sql;
  exception
    when others then
      reset role;
      return 'ERR:' || sqlstate;
  end;
  reset role;
  return 'ok';
end;
$fn$;

-- Scalar form, for an RPC whose *answer* matters.
create function tap.value_as(p_auth uuid, p_sql text, p_aal text default 'aal2')
returns text language plpgsql as $fn$
declare
  v_out text;
begin
  if p_auth is null then
    perform tap.become_anon();
  else
    perform tap.become(p_auth, p_aal);
  end if;
  begin
    execute p_sql into v_out;
  exception
    when others then
      reset role;
      return 'ERR:' || sqlstate;
  end;
  reset role;
  return coalesce(v_out, '(null)');
end;
$fn$;

-- Attempting a statement as the owner, to find out which constraint refuses it.
-- Used where the thing under test is the database's own guarantee rather than a
-- permission: "no person is in two hangouts in one slot" has to hold against
-- the worker too, and the worker is not `authenticated`.
create function tap.attempt(p_sql text)
returns text language plpgsql as $fn$
begin
  begin
    execute p_sql;
  exception
    when others then
      return sqlstate;
  end;
  return 'ok';
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Names for the cast, so a failing assertion says who rather than which uuid.
create function tap.alice()  returns uuid language sql immutable as
  $fn$ select '11111111-1111-4111-8111-111111111111'::uuid $fn$;
create function tap.bruno()  returns uuid language sql immutable as
  $fn$ select '22222222-2222-4222-8222-222222222222'::uuid $fn$;
create function tap.cvita()  returns uuid language sql immutable as
  $fn$ select '33333333-3333-4333-8333-333333333333'::uuid $fn$;
-- Dario is in no hangout with anyone. He is the non-member every "can a
-- stranger read this" assertion is made from.
create function tap.dario()  returns uuid language sql immutable as
  $fn$ select '44444444-4444-4444-8444-444444444444'::uuid $fn$;

create function tap.auth_of(p_person uuid) returns uuid language sql stable as
  $fn$ select auth_user_id from public.people where id = p_person $fn$;

-- The console cast. These are auth users with **no `people` row**, which is the
-- shape an operator actually has: running the city is not the same account as
-- being in a hangout, and a console test that borrowed Ana's session would
-- silently be testing the wrong thing.
create function tap.viewer()   returns uuid language sql immutable as
  $fn$ select 'dddddddd-dddd-4ddd-8ddd-dddddddddd01'::uuid $fn$;
create function tap.operator() returns uuid language sql immutable as
  $fn$ select 'dddddddd-dddd-4ddd-8ddd-dddddddddd02'::uuid $fn$;
create function tap.owner()    returns uuid language sql immutable as
  $fn$ select 'dddddddd-dddd-4ddd-8ddd-dddddddddd03'::uuid $fn$;

-- The three hangouts, one per lifecycle question.
create function tap.h_before() returns uuid language sql immutable as
  $fn$ select '55555555-5555-4555-8555-555555555555'::uuid $fn$;
create function tap.h_after()  returns uuid language sql immutable as
  $fn$ select '66666666-6666-4666-8666-666666666666'::uuid $fn$;
create function tap.h_confirming() returns uuid language sql immutable as
  $fn$ select '77777777-7777-4777-8777-777777777777'::uuid $fn$;

create function tap.city_home()    returns uuid language sql immutable as
  $fn$ select '88888888-8888-4888-8888-888888888881'::uuid $fn$;
create function tap.city_other()   returns uuid language sql immutable as
  $fn$ select '88888888-8888-4888-8888-888888888882'::uuid $fn$;
create function tap.slot_free()    returns uuid language sql immutable as
  $fn$ select '99999999-9999-4999-8999-999999999994'::uuid $fn$;
create function tap.slot_foreign() returns uuid language sql immutable as
  $fn$ select '99999999-9999-4999-8999-999999999995'::uuid $fn$;
create function tap.slot_past()    returns uuid language sql immutable as
  $fn$ select '99999999-9999-4999-8999-999999999996'::uuid $fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The world. Built once per test file, before any test runs.
create function tap.startup() returns setof text language plpgsql as $fn$
declare
  v_venue uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  v_sigil uuid;
begin
  -- Two cities: one everybody lives in, one that exists only so a client can be
  -- caught claiming a slot in it.
  insert into public.cities (id, name, country_code, timezone, centroid, active)
  values
    (tap.city_home(), 'Testograd', 'HR', 'Europe/Zagreb',
     extensions.ST_SetSRID(extensions.ST_MakePoint(18.69, 45.55), 4326)::extensions.geography,
     true),
    (tap.city_other(), 'Drugigrad', 'HR', 'Europe/Zagreb',
     extensions.ST_SetSRID(extensions.ST_MakePoint(15.98, 45.81), 4326)::extensions.geography,
     true);

  -- One slot per hangout, because a person cannot be in two hangouts in one
  -- slot and the fixture must not be the thing that proves it.
  insert into public.slots
    (id, city_id, starts_at, ends_at, local_date, local_weekday, local_time,
     generated_by)
  values
    ('99999999-9999-4999-8999-999999999991', tap.city_home(),
     now() + interval '3 days', now() + interval '3 days 90 minutes',
     (now() + interval '3 days')::date, 5, '17:30', 'fixture'),
    ('99999999-9999-4999-8999-999999999992', tap.city_home(),
     now() + interval '4 days', now() + interval '4 days 90 minutes',
     (now() + interval '4 days')::date, 6, '17:30', 'fixture'),
    ('99999999-9999-4999-8999-999999999993', tap.city_home(),
     now() + interval '5 days', now() + interval '5 days 90 minutes',
     (now() + interval '5 days')::date, 7, '17:30', 'fixture'),
    (tap.slot_free(), tap.city_home(),
     now() + interval '6 days', now() + interval '6 days 90 minutes',
     (now() + interval '6 days')::date, 1, '19:00', 'fixture'),
    (tap.slot_foreign(), tap.city_other(),
     now() + interval '6 days', now() + interval '6 days 90 minutes',
     (now() + interval '6 days')::date, 1, '19:00', 'fixture'),
    (tap.slot_past(), tap.city_home(),
     now() - interval '2 days', now() - interval '2 days' + interval '90 minutes',
     (now() - interval '2 days')::date, 4, '16:00', 'fixture');

  insert into public.venues
    (id, city_id, source, source_ref, name, kind, location)
  values
    (v_venue, tap.city_home(), 'fixture', 'v1', 'Kod Bagrema', 'cafe',
     extensions.ST_SetSRID(extensions.ST_MakePoint(18.6955, 45.5550), 4326)::extensions.geography);

  select id into v_sigil from public.sigils
   where symbol = 'circle' and colour = 'red';

  -- Four people. Each gets an anonymous auth user, because that is exactly what
  -- the real signup produces: the university address never reaches auth.users.
  insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000',
         'authenticated', 'authenticated', now(), now()
  from unnest(array[
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01'::uuid,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02'::uuid,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03'::uuid,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa04'::uuid
  ]) as u;

  -- The console cast: auth users with an admin role and no person behind them.
  insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000',
         'authenticated', 'authenticated', now(), now()
  from unnest(array[tap.viewer(), tap.operator(), tap.owner()]) as u;

  insert into public.admin_roles (auth_user_id, role) values
    (tap.viewer(), 'viewer'),
    (tap.operator(), 'operator'),
    (tap.owner(), 'owner');

  insert into public.identities (id, identity_hash, provider)
  values
    ('cccccccc-cccc-4ccc-8ccc-cccccccccc01', '\x01'::bytea, 'FIXTURE'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccc02', '\x02'::bytea, 'FIXTURE'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccc03', '\x03'::bytea, 'FIXTURE'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccc04', '\x04'::bytea, 'FIXTURE');

  insert into public.people
    (id, identity_id, auth_user_id, first_name, last_initial, gender_code,
     city_id, home_anchor, max_travel_m)
  select
    p.id, p.identity_id, p.auth_id, p.first_name, p.last_initial, p.gender_code,
    tap.city_home(),
    extensions.ST_SetSRID(extensions.ST_MakePoint(18.69, 45.55), 4326)::extensions.geography,
    3000
  from (
    values
      (tap.alice(), 'cccccccc-cccc-4ccc-8ccc-cccccccccc01'::uuid,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01'::uuid, 'Ana',   'K', 'woman'),
      (tap.bruno(), 'cccccccc-cccc-4ccc-8ccc-cccccccccc02'::uuid,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02'::uuid, 'Bruno', 'M', 'man'),
      (tap.cvita(), 'cccccccc-cccc-4ccc-8ccc-cccccccccc03'::uuid,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03'::uuid, 'Cvita', 'P', 'woman'),
      (tap.dario(), 'cccccccc-cccc-4ccc-8ccc-cccccccccc04'::uuid,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa04'::uuid, 'Dario', 'S', 'man')
  ) as p (id, identity_id, auth_id, first_name, last_initial, gender_code);

  -- Three hangouts: one before its reveal, one after it, one mid-confirmation.
  insert into public.hangouts
    (id, slot_id, city_id, state, composition_rule, activity_id,
     meeting_point_id, sigil_id, confirm_opens_at, confirm_deadline_at,
     reveal_at, rating_due_at)
  values
    (tap.h_before(), '99999999-9999-4999-8999-999999999991', tap.city_home(),
     'PROPOSED', 'NO_LONE_GENDER', 'CONVERSATION_DECK',
     null, null,
     now() + interval '2 days', now() + interval '2 days 4 hours',
     now() + interval '3 days' - interval '60 minutes', null),
    (tap.h_after(), '99999999-9999-4999-8999-999999999992', tap.city_home(),
     'REVEALED', 'NO_LONE_GENDER', 'CONVERSATION_DECK',
     v_venue, v_sigil,
     now() - interval '8 hours', now() - interval '5 hours',
     now() - interval '1 hour', now() + interval '1 day'),
    (tap.h_confirming(), '99999999-9999-4999-8999-999999999993', tap.city_home(),
     'CONFIRMING', 'NO_LONE_GENDER', 'CONVERSATION_DECK',
     null, null,
     now() - interval '1 hour', now() + interval '3 hours',
     now() + interval '5 days' - interval '60 minutes', null);

  insert into public.hangout_members
    (hangout_id, person_id, slot_id, slot_role, ring_intended, via_person_id)
  select h.id, p.person_id, h.slot_id, p.role_,
         'r3_stranger'::public.ring,
         case when p.person_id = tap.cvita() then tap.bruno() end
  from public.hangouts h
  cross join (
    values
      (tap.alice(), 'seed'::public.slot_role),
      (tap.bruno(), 'partner'::public.slot_role),
      (tap.cvita(), 'partner'::public.slot_role)
  ) as p (person_id, role_)
  where h.id in (tap.h_before(), tap.h_after(), tap.h_confirming());

  -- Bruno did not enjoy Ana. Invariant 3 is the promise that she can never find
  -- that out, and invariant 4 is the promise that nobody can work out which
  -- direction it went.
  insert into public.ratings
    (hangout_id, rater_id, subject_id, enjoyment, respect)
  values
    (tap.h_after(), tap.bruno(), tap.alice(), 'rather_not', true),
    (tap.h_after(), tap.alice(), tap.bruno(), 'really_enjoyed', true),
    (tap.h_after(), tap.cvita(), tap.alice(), 'enjoyed', true);

  insert into public.edges (a_id, b_id, weight, meet_count, last_met_at)
  values (tap.alice(), tap.bruno(), 0.4200, 1, now() - interval '1 day');

  insert into public.exclusions (a_id, b_id, reason)
  values (tap.alice(), tap.dario(), 'rather_not');

  insert into public.reports
    (reporter_id, subject_id, hangout_id, category, note)
  values (tap.bruno(), tap.alice(), tap.h_after(), 'pushy', 'fixture note');

  insert into public.infractions (person_id, which, type, weight, hangout_id)
  values (tap.alice(), 'conduct', 'CONDUCT', 1.000, tap.h_after());

  insert into public.sanctions
    (person_id, which, kind, ladder_step, visible, reason_code, context_count,
     ends_at)
  values
    (tap.alice(), 'conduct', 'SUSPENSION', 3, true, 'CONDUCT_R3', 2,
     now() + interval '7 days'),
    (tap.bruno(), 'conduct', 'THROTTLE', 1, false, 'CONDUCT_R1', 1, null);

  insert into public.standing (person_id, tier, conduct_score)
  values
    (tap.alice(), 'SUSPENDED', 3.500),
    (tap.bruno(), 'GOOD', 0.000),
    (tap.cvita(), 'GOOD', 0.000),
    (tap.dario(), 'GOOD', 0.000);

  insert into public.availability (person_id, slot_id, source)
  values (tap.alice(), tap.slot_free(), 'manual');

  return;
end;
$fn$;
