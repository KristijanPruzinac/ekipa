-- 08 · One evening, all the way through.
--
-- Every other test file asks whether a single function refuses the right
-- callers. This one asks the question none of them can: **does the product
-- work?** A plan is written, the morning-of question is asked and answered,
-- one person says nothing, the group locks, a place and a mark are allocated,
-- three people arrive, everybody rates, and the evening closes leaving edges,
-- an exclusion, a respect tally and exactly one infraction behind.
--
-- It is worth having as a *test* rather than as a thing somebody ran once,
-- because almost every defect in a state machine is a transition nobody
-- exercised. The eight below are the whole machine.
--
-- **What this file proves that a unit test cannot.** The matcher is pure and
-- tested as a function. Everything after it — the deadlines, the release of a
-- silent member, the venue that has to be reachable by all four, the sigil that
-- has to be unique at that venue in that slot, the mutual-only edge rule — is
-- SQL, runs in one transaction, and is only true if the whole sequence is.
--
-- The clock is the awkward part: the fixture writes deadlines relative to
-- `now()` and then drives the transitions by hand, because waiting ten hours is
-- not a test. That is why `worker_advance` takes a hangout and not a
-- destination — the sweeper's *scheduling* is `worker_due`, tested separately
-- at step 02, and its *transitions* are here.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

drop schema if exists tap cascade;
create schema tap;

-- ─────────────────────────────────────────────────────────────────────────────
-- Wearing each hat. The worker and a phone are different roles, and a test that
-- did all of this as the owner would prove nothing about either.
create function tap.as_member(p_n int, p_sql text) returns text
language plpgsql as $fn$
declare v_out text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa0' || p_n),
                      'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v_out;
  exception when others then reset role; return 'ERR:' || sqlstate;
  end;
  reset role;
  return coalesce(v_out, 'ok');
end;
$fn$;

create function tap.as_worker(p_sql text) returns text
language plpgsql as $fn$
declare v_out text;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
  begin
    execute p_sql into v_out;
  exception when others then reset role; return 'ERR:' || sqlstate;
  end;
  reset role;
  return coalesce(v_out, 'ok');
end;
$fn$;

create function tap.city() returns uuid language sql immutable as
  $fn$ select '88888888-8888-4888-8888-888888888881'::uuid $fn$;
create function tap.slot() returns uuid language sql immutable as
  $fn$ select '99999999-9999-4999-8999-999999999991'::uuid $fn$;
create function tap.person(p_n int) returns uuid language sql immutable as
  $fn$ select ('11111111-1111-4111-8111-11111111111' || p_n)::uuid $fn$;
create function tap.hangout() returns uuid language sql stable as
  $fn$ select id from public.hangouts where city_id = tap.city() limit 1 $fn$;

-- One sweeper step, with the parameters the mill resolves from config. They are
-- spelled out rather than defaulted so that a change to a default cannot make
-- this file quietly test something else.
create function tap.step() returns text language sql as $fn$
  select tap.as_worker(
    'select public.worker_advance(' || quote_literal(tap.hangout())
    || '::uuid, ''{"min_group_size":3,"max_travel_m":6000,"min_arrivals":2,'
    || '"weights":{"CONFIRM_SILENT":1.5,"CONFIRM_DECLINE":0.25,"NO_SHOW":3,'
    || '"LATE_ARRIVAL":0.5,"RATING_MISSED":0.5},'
    || '"edge_strong":1,"edge_warm":0.6}''::jsonb)::text')
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
create function tap.startup() returns setof text language plpgsql as $fn$
begin
  insert into public.cities (id, name, country_code, timezone, centroid, active)
  values (tap.city(), 'Testograd', 'HR', 'Europe/Zagreb',
    extensions.ST_SetSRID(extensions.ST_MakePoint(18.69, 45.55), 4326)::extensions.geography,
    true);

  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('c1000000-0000-4000-8000-000000000001', tap.city(),
    extensions.ST_SetSRID(extensions.ST_MakePoint(18.6955, 45.5550), 4326)::extensions.geography,
    1);

  insert into public.venues
    (id, city_id, cluster_id, source, source_ref, name, kind, location,
     outcome_score)
  values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', tap.city(),
    'c1000000-0000-4000-8000-000000000001', 'fixture', 'v1', 'Kod Bagrema',
    'cafe',
    extensions.ST_SetSRID(extensions.ST_MakePoint(18.6955, 45.5550), 4326)::extensions.geography,
    0.8);

  insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
  select ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa0' || n)::uuid,
    '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    now(), now()
  from generate_series(1, 4) n;

  insert into public.identities (id, identity_hash, provider)
  select ('cccccccc-cccc-4ccc-8ccc-cccccccccc0' || n)::uuid,
    decode(lpad(n::text, 2, '0'), 'hex'), 'FIXTURE'
  from generate_series(1, 4) n;

  -- Two women and two men, because the composition rule the plan names is
  -- NO_LONE_GENDER and a fixture that could not satisfy it would be testing a
  -- group the matcher would never emit.
  insert into public.people (id, identity_id, auth_user_id, first_name,
    last_initial, gender_code, city_id, home_anchor)
  select tap.person(n),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccc0' || n)::uuid,
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa0' || n)::uuid,
    'P' || n, 'X', case when n <= 2 then 'woman' else 'man' end, tap.city(),
    extensions.ST_SetSRID(extensions.ST_MakePoint(18.69, 45.55), 4326)::extensions.geography
  from generate_series(1, 4) n;

  insert into public.standing (person_id)
  select tap.person(n) from generate_series(1, 4) n;

  insert into public.slots (id, city_id, starts_at, ends_at, local_date,
    local_weekday, local_time, generated_by)
  values (tap.slot(), tap.city(),
    now() + interval '2 hours', now() + interval '3 hours 30 minutes',
    (now() + interval '2 hours')::date, 5, '17:30', 'fixture');

  insert into public.availability (person_id, slot_id, source)
  select tap.person(n), tap.slot(), 'manual' from generate_series(1, 4) n;
  return;
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The whole evening, in order. One test function rather than eight, because
-- pgTAP rolls each one back and the eighth step depends on the seventh.
create function tap.test_one_evening_end_to_end()
returns setof text language plpgsql as $fn$
declare
  v_plan   jsonb;
  v_commit text;
  v_h      uuid;
begin
  -- ① The worker writes a plan. Deadlines are absolute, computed by the mill
  --    from the config version in force — `0003` requires all seven at
  --    creation so a mid-day config change cannot move one somebody is inside.
  --
  -- **The plan is built here and passed as a literal**, rather than assembled
  -- inside the string that runs as `service_role`. Everything in the `tap`
  -- schema belongs to the session user, and `service_role` has no `usage` on
  -- it — a `tap.person(1)` inside that string is a permission error dressed up
  -- as a JSON parse failure three assertions later. Every other file here uses
  -- the same shape for the same reason: compose as yourself, execute as them.
  v_plan := jsonb_build_object(
    'city', tap.city(),
    'kind', 'daily', 'seed', 4242, 'snapshot_hash', 'deadbeef',
    'stats', jsonb_build_object('eligible', 4),
    'groups', jsonb_build_array(jsonb_build_object(
      'slot', tap.slot(),
      'activity', 'CONVERSATION_DECK',
      'composition_rule', 'NO_LONE_GENDER',
      'seed_person', tap.person(1),
      'confirm_opens_at', (now() - interval '1 minute')::text,
      'confirm_deadline_at', (now() + interval '30 minutes')::text,
      'backfill_until', (now() + interval '60 minutes')::text,
      -- In the past, so the reveal's *time* gate is open and the assertion
      -- below is about membership rather than about the clock. The clock gate
      -- has its own test in 02.
      'reveal_at', (now() - interval '1 minute')::text,
      'arrival_grace_until', (now() + interval '2 hours 15 minutes')::text,
      'late_report_until', (now() + interval '2 hours 45 minutes')::text,
      'rating_due_at', (now() + interval '27 hours')::text,
      'members', jsonb_build_array(
        jsonb_build_object('person', tap.person(1), 'role', 'seed'),
        jsonb_build_object('person', tap.person(2), 'role', 'partner'),
        jsonb_build_object('person', tap.person(3), 'role', 'partner'),
        jsonb_build_object('person', tap.person(4), 'role', 'partner')
      )
    ))
  );

  v_commit := tap.as_worker(
    'select public.worker_commit_plan(' || quote_literal(v_plan::text)
    || '::jsonb)::text');

  return next ok(
    (v_commit::jsonb->>'written')::int = 1
      and (v_commit::jsonb->>'skipped')::int = 0,
    'the plan lands: one hangout written, none skipped');

  v_h := tap.hangout();

  return next is(
    (select count(*)::int from public.match_run_groups), 1,
    'and its explanation is written with it, because it cannot be '
    || 'reconstructed later');

  -- ② The sweeper is told what is due rather than told what to do.
  return next ok(
    tap.as_worker('select public.worker_due(10)::text')::jsonb -> 0 ->> 'next'
      = 'PROPOSED',
    'the clock says the planned hangout is due to be told to its members');

  return next is(
    tap.step()::jsonb->>'to', 'PROPOSED', 'PLANNED → PROPOSED');
  return next is(
    tap.step()::jsonb->>'to', 'CONFIRMING', 'PROPOSED → CONFIRMING');

  -- ③ Three answer. **The fourth says nothing**, which is the case the whole
  --    trust model is built around.
  return next is(
    tap.as_member(1, 'select public.confirm_hangout('
      || quote_literal(v_h) || '::uuid, true)::text'),
    'CONFIRMING',
    'the first yes does not lock it');
  perform tap.as_member(2, 'select public.confirm_hangout('
    || quote_literal(v_h) || '::uuid, true)::text');
  perform tap.as_member(3, 'select public.confirm_hangout('
    || quote_literal(v_h) || '::uuid, true)::text');

  return next is(
    tap.step()::jsonb->>'to', 'LOCKED',
    'three of four is enough: CONFIRMING → LOCKED');

  return next is(
    (select coalesce(string_agg(type::text || '=' || weight, ','), '(none)')
       from public.infractions where hangout_id = v_h),
    'CONFIRM_SILENT=1.500',
    'the silent member is charged, and at the weight that was in force');

  return next is(
    (select count(*)::int from public.hangout_members
      where hangout_id = v_h and released_at is not null),
    1,
    'and released rather than deleted: a cancellation is input to trust');

  return next ok(
    (select meeting_point_id is not null and sigil_id is not null
       from public.hangouts where id = v_h),
    'locking allocated a place everybody can reach and a mark for it');

  -- ④ Reveal, and the two gates on it.
  return next is(tap.step()::jsonb->>'to', 'REVEALED', 'LOCKED → REVEALED');

  return next is(
    tap.as_member(4, 'select count(*)::text from public.hangout_reveal('
      || quote_literal(v_h) || '::uuid)'),
    'ERR:42501',
    'DP-4: the released member cannot read the reveal they are no longer in');

  return next is(
    tap.as_member(1, 'select count(*)::text from public.hangout_reveal('
      || quote_literal(v_h) || '::uuid)'),
    '3',
    'a member sees the three people who are actually coming');

  -- ⑤ Arrival. The third taps with no proximity claim — a phone with location
  --    off is an ordinary phone, not a suspicious one.
  return next is(
    tap.as_member(1, 'select public.mark_arrived('
      || quote_literal(v_h) || '::uuid, true)::text'),
    'LIVE',
    'the first arrival makes it live');
  perform tap.as_member(2, 'select public.mark_arrived('
    || quote_literal(v_h) || '::uuid, true)::text');
  perform tap.as_member(3, 'select public.mark_arrived('
    || quote_literal(v_h) || '::uuid, null)::text');

  return next is(
    tap.step()::jsonb->>'arrived', '3',
    'attendance settles at three, and LIVE → RATING');

  return next is(
    (select count(*)::int from public.infractions
      where hangout_id = v_h and type = 'NO_SHOW'),
    0,
    'nobody is charged for a no-show, because nobody said yes and stayed home');

  -- ⑥ Ratings, and the edges they do and do not create.
  perform tap.as_member(1, 'select public.submit_ratings('
    || quote_literal(v_h) || '::uuid, ' || quote_literal(
      '[{"subject":"' || tap.person(2) || '","enjoyment":"really_enjoyed","respect":true},'
      || '{"subject":"' || tap.person(3) || '","enjoyment":"enjoyed","respect":true}]')
    || '::jsonb, true, true)');
  perform tap.as_member(2, 'select public.submit_ratings('
    || quote_literal(v_h) || '::uuid, ' || quote_literal(
      '[{"subject":"' || tap.person(1) || '","enjoyment":"really_enjoyed","respect":true},'
      || '{"subject":"' || tap.person(3) || '","enjoyment":"no_preference","respect":true}]')
    || '::jsonb, true, true)');
  perform tap.as_member(3, 'select public.submit_ratings('
    || quote_literal(v_h) || '::uuid, ' || quote_literal(
      '[{"subject":"' || tap.person(1) || '","enjoyment":"enjoyed","respect":true},'
      || '{"subject":"' || tap.person(2) || '","enjoyment":"rather_not","respect":false}]')
    || '::jsonb, false, true)');

  return next is(tap.step()::jsonb->>'to', 'CLOSED', 'RATING → CLOSED');

  -- **Mutual or nothing.** 1↔2 both said "really enjoyed" and get the strong
  -- weight. 1↔3 both enjoyed it and get the warm one. 2↔3 disagreed — 2 was
  -- indifferent, 3 would rather not — and get *no edge at all*, not a weak one.
  -- That is load-bearing for privacy: if one-sided liking could pull somebody
  -- back, being re-matched would leak that they liked you.
  return next is(
    (select coalesce(string_agg(
       right(a_id::text, 1) || '-' || right(b_id::text, 1) || '@' || weight,
       ',' order by a_id, b_id), '(none)') from public.edges),
    '1-2@1.0000,1-3@0.6000',
    'two mutual edges, at the strong and warm weights, and no third');

  return next is(
    (select coalesce(string_agg(
       right(a_id::text, 1) || '-' || right(b_id::text, 1) || ':' || reason,
       ','), '(none)') from public.exclusions),
    '2-3:rather_not',
    'and the rather_not is a permanent symmetric exclusion (R0)');

  return next is(
    (select coalesce(string_agg(
       right(person_id::text, 1) || ':' || respect_yes || '/' || respect_no,
       ',' order by person_id), '(none)')
       from public.standing where respect_yes + respect_no > 0),
    '1:2/0,2:1/1,3:2/0',
    'the respect tally accumulates — one bit from three strangers, and never '
    || 'shown to anybody, including its subject');

  return next is(
    (select state::text from public.hangouts where id = v_h), 'CLOSED',
    'and the evening is over');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The worker's surface is the worker's.
--
-- This is the assertion that keeps the mill's key from being the only thing
-- standing between a phone and the whole city. The console shares one auth
-- realm with the app, so `authenticated` is a role a phone holds.
create function tap.test_worker_functions_refuse_a_phone()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.as_member(1, 'select public.worker_due(10)::text'), 'ERR:42501',
    'a phone cannot ask what is due');

  return next is(
    tap.as_member(1, 'select public.worker_snapshot(' || quote_literal(tap.city())
      || '::uuid, now(), now() + interval ''7 days'', 6000)::text'),
    'ERR:42501',
    'nor read the snapshot, which is the whole city in one value');

  return next is(
    tap.as_member(1,
      'select public.worker_commit_plan(''{"city":"' || tap.city()
      || '"}''::jsonb)::text'),
    'ERR:42501',
    'nor write a plan that puts themselves in a group');

  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '(none)')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname like 'worker\_%'
        and (has_function_privilege('authenticated', p.oid, 'execute')
             or has_function_privilege('anon', p.oid, 'execute'))),
    '(none)',
    'and no worker function carries a grant to anon or authenticated at all');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
