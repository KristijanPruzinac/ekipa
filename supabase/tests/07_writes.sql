-- 07 · The write surface from 0011.
--
-- 03 proves these functions are *reachable* only by the right role. This file
-- proves they *do* the right thing when the caller is lying, which is the more
-- interesting half: everything the app sends is a claim by an attacker who
-- happens to be a user (`11_SECURITY.md §2`), so every parameter below is
-- tested with a value the UI could never produce.
--
-- The assertions cluster around three claims a client would most like to make:
--
--   * **"my city is the dense one"** — refused, because the city is derived
--     from the anchor and is not a parameter at all.
--   * **"I rated everybody"** — refused unless it is true, counted against the
--     membership rather than against the payload.
--   * **"this person is in my hangout"** — refused, for arrival, attestation
--     and reports alike.
--
-- Nothing here weakens 01's invariants. Where a function writes something a
-- person must never read, the test asserts the write happened *and* that the
-- subject still cannot see it.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir ../fixtures/world.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- Somebody who has verified and has no profile yet. This is a real state and it
-- lasts about ninety seconds per person: the worker has minted an anonymous
-- session and written the identity, and `create_profile` has not been called.
create function tap.newcomer() returns uuid language sql immutable as
  $fn$ select 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01'::uuid $fn$;

create function tap.enrol_newcomer() returns void language plpgsql as $fn$
begin
  insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
  values (tap.newcomer(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', now(), now());

  insert into public.identities (id, identity_hash, provider, auth_user_id)
  values ('cccccccc-cccc-4ccc-8ccc-cccccccccc05', '\x05'::bytea, 'FIXTURE',
          tap.newcomer());
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Signup.
create function tap.test_create_profile_derives_the_city()
returns setof text language plpgsql as $fn$
declare
  v_call text;
begin
  perform tap.enrol_newcomer();

  -- An anchor next to Testograd. There is no city parameter to lie about, which
  -- is the point being asserted: the signature itself refuses the attack.
  v_call := 'select public.create_profile('
            || '''Eva'', ''L'', ''woman'', 45.5551, 18.6901,'
            || ' array[''deck_of_cards'']) is not null';

  return next is(
    tap.value_as(tap.newcomer(), v_call), 'true',
    'a verified session with no profile can create exactly one');

  return next is(
    (select c.name from public.people p
       join public.cities c on c.id = p.city_id
      where p.first_name = 'Eva'),
    'Testograd',
    'and the city is derived from the anchor, never sent');

  return next is(
    tap.value_as(tap.newcomer(), v_call), 'ERR:23505',
    'a second call from the same identity is refused, not silently ignored');
end;
$fn$;

create function tap.test_create_profile_snaps_the_anchor()
returns setof text language plpgsql as $fn$
declare
  v_lat double precision;
begin
  perform tap.enrol_newcomer();

  -- A coordinate precise to seven decimal places is somebody's front door. The
  -- app snaps before sending; this asserts the server snaps again, because the
  -- app is the adversary's copy.
  perform tap.value_as(tap.newcomer(),
    'select public.create_profile(''Eva'', ''L'', ''woman'', '
    || '45.5587231, 18.6912447, array[]::text[])::text');

  select extensions.ST_Y(p.home_anchor::extensions.geometry) into v_lat
  from public.people p where p.first_name = 'Eva';

  return next ok(
    abs(v_lat - round(45.5587231::numeric / 0.0045)::double precision * 0.0045)
      < 0.00001,
    'the stored anchor is on the grid, not where the client said');

  return next ok(
    abs(v_lat - 45.5587231) > 0.0001,
    'and it is measurably not the coordinate that was sent');
end;
$fn$;

create function tap.test_create_profile_refuses_a_far_anchor()
returns setof text language plpgsql as $fn$
begin
  perform tap.enrol_newcomer();

  return next is(
    tap.value_as(tap.newcomer(),
      'select public.create_profile(''Eva'', ''L'', ''woman'', '
      || '48.2082, 16.3738, array[]::text[])::text'),
    'ERR:22023',
    'an anchor in Vienna gets an honest refusal, not a nearest-city guess');
end;
$fn$;

create function tap.test_create_profile_needs_a_verified_identity()
returns setof text language plpgsql as $fn$
begin
  -- An auth user with no identity row: what a stolen or forged JWT looks like
  -- from the database's side.
  insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
  values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee99',
          '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', now(), now());

  return next is(
    tap.value_as('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee99'::uuid,
      'select public.create_profile(''Mal'', ''X'', ''man'', '
      || '45.5551, 18.6901, array[]::text[])::text'),
    'ERR:42501',
    'a session with no verified identity behind it creates nothing');

  return next is(
    tap.value_as(null,
      'select public.create_profile(''Mal'', ''X'', ''man'', '
      || '45.5551, 18.6901, array[]::text[])::text'),
    'ERR:42501',
    'and anonymous is refused before anything else is even looked at');
end;
$fn$;

create function tap.test_create_profile_is_18_plus()
returns setof text language plpgsql as $fn$
begin
  perform tap.enrol_newcomer();
  update public.identities
     set date_of_birth = current_date - interval '17 years'
   where auth_user_id = tap.newcomer();

  return next is(
    tap.value_as(tap.newcomer(),
      'select public.create_profile(''Eva'', ''L'', ''woman'', '
      || '45.5551, 18.6901, array[]::text[])::text'),
    'ERR:42501',
    'a known under-18 is refused; a null date of birth stays the normal case');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The week.
create function tap.test_my_slots_is_a_bucket_not_a_count()
returns setof text language plpgsql as $fn$
declare
  v_values text;
begin
  perform tap.become(tap.auth_of(tap.bruno()));
  select coalesce(string_agg(distinct s.density::text, ',' order by
                             s.density::text), '')
    into v_values
  from public.my_slots() s;
  reset role;

  -- Five buckets and nothing else. A raw count is gameable and it publishes how
  -- thin the network is (`05_PLACES.md §7`); the assertion is that no value can
  -- appear here that is not one of the five.
  return next ok(
    v_values <> ''
      and v_values ~ '^(0\.15|0\.35|0\.55|0\.8|0\.95)(,(0\.15|0\.35|0\.55|0\.8|0\.95))*$',
    'every density is one of the five buckets, so none of them is a headcount');

  return next is(
    tap.count_as(tap.auth_of(tap.bruno()),
      'select * from public.my_slots() where slot_id = '
      || quote_literal(tap.slot_foreign()) || '::uuid'),
    '0',
    'and another city''s slots are not in the answer at all');
end;
$fn$;

create function tap.test_repeat_last_week_copies_the_pattern()
returns setof text language plpgsql as $fn$
begin
  -- Ana was available on the past slot: Thursday at 16:00. Nothing in the
  -- future matches that pattern in the fixture, so the honest answer is zero —
  -- which is the assertion that matters, because a function that copied *ids*
  -- would also return zero and look identical.
  insert into public.availability (person_id, slot_id, source)
  values (tap.alice(), tap.slot_past(), 'manual')
  on conflict do nothing;

  insert into public.slots
    (city_id, starts_at, ends_at, local_date, local_weekday, local_time,
     generated_by)
  values
    (tap.city_home(), now() + interval '9 days',
     now() + interval '9 days 90 minutes',
     (now() + interval '9 days')::date, 4, '16:00', 'fixture');

  return next is(
    tap.value_as(tap.auth_of(tap.alice()),
      'select public.repeat_last_week()::text'),
    '1',
    'next Thursday at 16:00 is picked up from last Thursday at 16:00');

  return next is(
    tap.value_as(null, 'select public.repeat_last_week()::text'),
    'ERR:42501',
    'and an anonymous caller repeats nothing');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Arrival and attestation.
create function tap.test_arrival_is_membership_gated()
returns setof text language plpgsql as $fn$
declare
  v_call text := 'select public.mark_arrived('
                 || quote_literal(tap.h_after()) || '::uuid, true)::text';
begin
  return next is(
    tap.value_as(tap.auth_of(tap.dario()), v_call), 'ERR:42501',
    'DP-4: a non-member holding the hangout id cannot mark themselves arrived');

  return next is(
    tap.value_as(null, v_call), 'ERR:42501',
    'and neither can an anonymous caller');

  return next is(
    tap.value_as(tap.auth_of(tap.bruno()), v_call), 'LIVE',
    'a member arrives, and the first arrival moves the group to LIVE');

  return next is(
    (select arrival_proximate::text from public.hangout_members
      where hangout_id = tap.h_after() and person_id = tap.bruno()),
    'true',
    'the proximity claim is recorded as a boolean');

  return next is(
    (select count(*)::int from public.hangout_events e
      where e.hangout_id = tap.h_after() and e.type = 'ARRIVED'
        and e.payload ? 'proximate'
        and jsonb_typeof(e.payload->'proximate') = 'boolean'),
    1,
    'and never as a coordinate — the event carries a boolean and nothing else');
end;
$fn$;

create function tap.test_attestation_is_about_somebody_else()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.value_as(tap.auth_of(tap.bruno()),
      'select public.attest_member(' || quote_literal(tap.h_after())
      || '::uuid, ' || quote_literal(tap.bruno()) || '::uuid, true)::text'),
    'ERR:22023',
    'nobody attests their own presence — that is what mark_arrived is');

  return next is(
    tap.value_as(tap.auth_of(tap.bruno()),
      'select public.attest_member(' || quote_literal(tap.h_after())
      || '::uuid, ' || quote_literal(tap.dario()) || '::uuid, true)::text'),
    'ERR:42501',
    'and a person who is not in the hangout cannot be attested into it');

  return next is(
    tap.exec_as(tap.auth_of(tap.bruno()),
      'select public.attest_member(' || quote_literal(tap.h_after())
      || '::uuid, ' || quote_literal(tap.cvita()) || '::uuid, false)'),
    'ok',
    'a member says another member is absent, and it lands as evidence');

  return next is(
    (select count(*)::int from public.hangout_events
      where hangout_id = tap.h_after() and type = 'ATTESTED'),
    1,
    'stored as an event rather than a column, because attestations disagree');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Ratings. The most privacy-loaded write in the product.
create function tap.test_ratings_are_all_or_nothing()
returns setof text language plpgsql as $fn$
declare
  v_partial text;
  v_full    text;
begin
  update public.hangouts set state = 'RATING' where id = tap.h_after();
  delete from public.ratings where hangout_id = tap.h_after();

  -- No `::text` on either call. `submit_ratings` returns `void`, and a void
  -- cast to text is the empty string rather than null — so these go through
  -- `exec_as`, which answers 'ok' or 'ERR:<state>' and is the helper that
  -- exists for exactly this shape.
  v_partial := 'select public.submit_ratings('
    || quote_literal(tap.h_after()) || '::uuid, '
    || quote_literal('[{"subject":"' || tap.bruno()
       || '","enjoyment":"enjoyed","respect":true}]') || '::jsonb, '
    || 'true, true)';

  return next is(
    tap.exec_as(tap.auth_of(tap.alice()), v_partial), 'ERR:22023',
    'one answer out of two is refused: a partial set is indistinguishable '
    || 'from a missing one, and the gate would then punish somebody who tried');

  v_full := 'select public.submit_ratings('
    || quote_literal(tap.h_after()) || '::uuid, '
    || quote_literal('[{"subject":"' || tap.bruno()
       || '","enjoyment":"enjoyed","respect":true},'
       || '{"subject":"' || tap.cvita()
       || '","enjoyment":"rather_not","respect":true}]') || '::jsonb, '
    || 'true, false)';

  return next is(
    tap.exec_as(tap.auth_of(tap.alice()), v_full), 'ok',
    'the whole set lands in one transaction');

  return next is(
    (select count(*)::int from public.ratings
      where hangout_id = tap.h_after() and rater_id = tap.alice()),
    2,
    'both rows are written');

  return next is(
    (select count(*)::int from public.exclusions
      where a_id = least(tap.alice(), tap.cvita())
        and b_id = greatest(tap.alice(), tap.cvita())),
    1,
    'and the rather_not became a permanent symmetric exclusion (R0)');
end;
$fn$;

create function tap.test_ratings_stay_invisible_to_their_subject()
returns setof text language plpgsql as $fn$
begin
  update public.hangouts set state = 'RATING' where id = tap.h_after();
  delete from public.ratings where hangout_id = tap.h_after();

  perform tap.value_as(tap.auth_of(tap.alice()),
    'select public.submit_ratings('
    || quote_literal(tap.h_after()) || '::uuid, '
    || quote_literal('[{"subject":"' || tap.bruno()
       || '","enjoyment":"rather_not","respect":false},'
       || '{"subject":"' || tap.cvita()
       || '","enjoyment":"enjoyed","respect":true}]') || '::jsonb, '
    || 'true, true)::text');

  -- Invariant 3, asserted against the write that just happened rather than
  -- against the fixture. A new write path is exactly where a leak arrives.
  return next is(
    tap.count_as(tap.auth_of(tap.bruno()),
      'select * from public.ratings where subject_id = '
      || quote_literal(tap.bruno()) || '::uuid'),
    'denied',
    'invariant 3: the subject cannot read what was said about them');

  return next is(
    tap.count_as(tap.auth_of(tap.bruno()),
      'select * from public.exclusions'),
    'denied',
    'invariant 4: nor find the exclusion it created');

  return next is(
    tap.count_as(tap.auth_of(tap.bruno()), 'select * from public.edges'),
    'denied',
    'and the graph stays closed to everyone');
end;
$fn$;

create function tap.test_ratings_need_an_open_window()
returns setof text language plpgsql as $fn$
begin
  update public.hangouts set state = 'CLOSED' where id = tap.h_after();

  return next is(
    tap.exec_as(tap.auth_of(tap.alice()),
      'select public.submit_ratings(' || quote_literal(tap.h_after())
      || '::uuid, ''[]''::jsonb, true, true)'),
    'ERR:22023',
    'DP-7: the window is enforced here, not by hiding the screen');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Reports.
create function tap.test_report_is_invisible_including_its_count()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.exec_as(tap.auth_of(tap.cvita()),
      'select public.report_member(' || quote_literal(tap.h_after())
      || '::uuid, ' || quote_literal(tap.alice())
      || '::uuid, ''pushy'', ''note'')'),
    'ok',
    'a member reports another member');

  return next is(
    tap.count_as(tap.auth_of(tap.alice()),
      'select * from public.reports where subject_id = '
      || quote_literal(tap.alice()) || '::uuid'),
    'denied',
    'invariant 6: the reported person cannot read the report');

  return next is(
    tap.count_as(tap.auth_of(tap.alice()),
      'select count(*) from public.reports'),
    'denied',
    'nor the count, which is the part a naive aggregate would leak');

  return next is(
    (select count(*)::int from public.exclusions
      where a_id = least(tap.alice(), tap.cvita())
        and b_id = greatest(tap.alice(), tap.cvita())
        and reason = 'block'),
    1,
    'and R0 fired immediately: these two never meet again');

  return next is(
    tap.value_as(tap.auth_of(tap.cvita()),
      'select public.report_member(' || quote_literal(tap.h_after())
      || '::uuid, ' || quote_literal(tap.cvita())
      || '::uuid, ''pushy'', null)::text'),
    'ERR:22023',
    'nobody reports themselves');
end;
$fn$;

create function tap.test_report_venue_demotes_without_a_queue()
returns setof text language plpgsql as $fn$
declare
  v_venue uuid;
begin
  select meeting_point_id into v_venue
  from public.hangouts where id = tap.h_after();

  return next is(
    tap.exec_as(tap.auth_of(tap.bruno()),
      'select public.report_venue(' || quote_literal(tap.h_after())
      || '::uuid, ''closed'')'),
    'ok',
    'one tap on the reveal screen reports the place');

  return next is(
    (select active::text from public.venues where id = v_venue),
    'true',
    'one group is one observation, so the venue is not deleted by it');

  -- Three *distinct hangouts*, not three taps. Four people at one bad venue is
  -- one observation of that venue, and counting taps would let a single group
  -- remove a place from the city.
  insert into public.hangout_events (hangout_id, type, payload)
  select tap.h_before(), 'VENUE_REPORTED',
         jsonb_build_object('venue', v_venue, 'reason', 'closed');
  insert into public.hangout_events (hangout_id, type, payload)
  select tap.h_confirming(), 'VENUE_REPORTED',
         jsonb_build_object('venue', v_venue, 'reason', 'closed');

  update public.hangouts set meeting_point_id = v_venue
   where id = tap.h_confirming();

  perform tap.value_as(tap.auth_of(tap.alice()),
    'select public.report_venue(' || quote_literal(tap.h_confirming())
    || '::uuid, ''closed'')::text');

  return next is(
    (select active::text from public.venues where id = v_venue),
    'false',
    'D11: the third group''s report deactivates it, with nobody on duty');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Devices.
create function tap.test_device_binds_to_the_caller()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.exec_as(tap.auth_of(tap.bruno()),
      'select public.register_device(''tok-1'', ''android'')'),
    'ok',
    'a member registers a push token');

  return next is(
    (select person_id from public.devices where push_token = 'tok-1'),
    tap.bruno(),
    'bound to the caller, because there is no person id to send');

  -- A token moving between accounts is a real case — a resold phone — and the
  -- assertion is that it *moves* rather than pointing at two people, which
  -- would send one person's morning-of question to the other's phone.
  return next is(
    tap.exec_as(tap.auth_of(tap.cvita()),
      'select public.register_device(''tok-1'', ''android'')'),
    'ok',
    'the same token registered by somebody else is accepted');

  return next is(
    (select count(*)::int from public.devices where push_token = 'tok-1'),
    1,
    'and there is still exactly one row for it');

  return next is(
    (select person_id from public.devices where push_token = 'tok-1'),
    tap.cvita(),
    'now pointing at the new owner');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
