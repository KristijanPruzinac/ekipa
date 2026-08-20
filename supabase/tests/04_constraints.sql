-- 04 · The constraints that are doing real work (02_DOMAIN.md §7).
--
-- These are not validations. A validation is a thing the application checks
-- before it writes; a constraint is a thing that cannot be false. The
-- difference matters here because every invariant below can be raced — two
-- match runs, a run and a backfill, two people confirming at once — and an
-- application check under concurrency is a check that passes twice.
--
-- Each test states the failure it prevents, because a constraint whose purpose
-- nobody remembers is a constraint somebody drops to make a migration pass.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir ../fixtures/world.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- One person, one hangout, one slot. Two groups holding the same person at
-- 17:30 means at least one group waits for somebody who is not coming, which is
-- the single outcome the product cannot survive at launch.
create function tap.test_one_hangout_per_person_per_slot()
returns setof text language plpgsql as $fn$
declare
  v_rival uuid := 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1';
begin
  insert into public.hangouts
    (id, slot_id, city_id, state, composition_rule, activity_id)
  values
    (v_rival, '99999999-9999-4999-8999-999999999991', tap.city_home(),
     'PLANNED', 'NO_LONE_GENDER', 'CONVERSATION_DECK');

  return next is(
    tap.attempt(
      'insert into public.hangout_members '
      || '(hangout_id, person_id, slot_id, slot_role) values ('
      || quote_literal(v_rival) || '::uuid, '
      || quote_literal(tap.alice()) || '::uuid, '
      || quote_literal('99999999-9999-4999-8999-999999999991') || '::uuid, '
      || '''partner'')'),
    '23505',
    'a second hangout in the same slot cannot take a person who is already in one');

  -- Cancellation frees the person without deleting the evidence: the row stays,
  -- `released_at` is set, and the partial index stops counting it.
  update public.hangout_members
     set released_at = now()
   where hangout_id = tap.h_before() and person_id = tap.alice();

  return next is(
    tap.attempt(
      'insert into public.hangout_members '
      || '(hangout_id, person_id, slot_id, slot_role) values ('
      || quote_literal(v_rival) || '::uuid, '
      || quote_literal(tap.alice()) || '::uuid, '
      || quote_literal('99999999-9999-4999-8999-999999999991') || '::uuid, '
      || '''backfill'')'),
    'ok',
    'and a released member frees the slot without losing the cancelled row');
end;
$fn$;

-- The denormalised `slot_id` on a membership is what makes the index above
-- possible. The composite foreign key is what stops it from ever disagreeing
-- with the hangout it belongs to.
create function tap.test_membership_slot_cannot_drift()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.attempt(
      'insert into public.hangout_members '
      || '(hangout_id, person_id, slot_id, slot_role) values ('
      || quote_literal(tap.h_before()) || '::uuid, '
      || quote_literal(tap.dario()) || '::uuid, '
      || quote_literal(tap.slot_free()) || '::uuid, ''partner'')'),
    '23503',
    'a membership cannot claim a slot its hangout is not in');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Two groups never share a symbol at the same place in the same slot. The
-- transcript asked for this outright, and it is the difference between "four
-- strangers find each other" and "seven strangers stand awkwardly at one table".
create function tap.test_sigil_collision_is_impossible()
returns setof text language plpgsql as $fn$
declare
  v_venue uuid;
  v_sigil uuid;
  v_slot  uuid;
begin
  select meeting_point_id, sigil_id, slot_id
    into v_venue, v_sigil, v_slot
  from public.hangouts where id = tap.h_after();

  return next isnt(v_venue, null,
    'the revealed hangout has a meeting point to collide at');

  return next is(
    tap.attempt(
      'insert into public.hangouts (slot_id, city_id, state, '
      || 'composition_rule, activity_id, meeting_point_id, sigil_id) values ('
      || quote_literal(v_slot) || '::uuid, '
      || quote_literal(tap.city_home()) || '::uuid, ''PLANNED'', '
      || '''NO_LONE_GENDER'', ''CONVERSATION_DECK'', '
      || quote_literal(v_venue) || '::uuid, '
      || quote_literal(v_sigil) || '::uuid)'),
    '23505',
    'a second group cannot take the same sigil at the same place and time');

  -- A different sigil at the same place is fine — that is the whole point of
  -- 144 combinations against a handful of simultaneous groups.
  return next is(
    tap.attempt(
      'insert into public.hangouts (slot_id, city_id, state, '
      || 'composition_rule, activity_id, meeting_point_id, sigil_id) values ('
      || quote_literal(v_slot) || '::uuid, '
      || quote_literal(tap.city_home()) || '::uuid, ''PLANNED'', '
      || '''NO_LONE_GENDER'', ''CONVERSATION_DECK'', '
      || quote_literal(v_venue) || '::uuid, '
      || '(select id from public.sigils where symbol = ''anchor'' '
      || 'and colour = ''blue''))'),
    'ok',
    'but a different sigil at the same place is exactly what they are for');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- The R2 gate, as a constraint rather than a code path.
--
-- Nothing above R2 may ever fire from a single hangout. Not from four
-- reporters, not from a severe category. One evening is one observation, and
-- two friends can manufacture one evening. This is the most important rule in
-- the trust system, which is exactly why it is not allowed to live in a
-- function somebody could refactor.
create function tap.test_r2_gate_is_a_constraint()
returns setof text language plpgsql as $fn$
declare
  v_insert text :=
    'insert into public.sanctions (person_id, which, kind, ladder_step, '
    || 'visible, reason_code, context_count) values ('
    || quote_literal(tap.dario()) || '::uuid, ''conduct'', ';
begin
  return next is(
    tap.attempt(v_insert || '''BAN'', 5, true, ''CONDUCT_R5'', 1)'),
    '23514',
    'a ban cannot be issued from one evening');
  return next is(
    tap.attempt(v_insert || '''SUSPENSION'', 3, true, ''CONDUCT_R3'', 1)'),
    '23514',
    'nor a suspension');
  return next is(
    tap.attempt(v_insert || '''SUSPENSION'', 3, true, ''CONDUCT_R3'', 2)'),
    'ok',
    'two independent contexts are what unlocks the visible half of the ladder');
  return next is(
    tap.attempt(v_insert || '''THROTTLE'', 1, false, ''CONDUCT_R1'', 1)'),
    'ok',
    'while the invisible steps stay available from a single observation');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Symmetry, keyed rather than enforced. If the pair key could hold (b, a) as
-- well as (a, b), then the *order* of the key is a direction, and invariant 4
-- becomes a convention instead of a fact.
create function tap.test_pair_tables_are_ordered()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.attempt(
      'insert into public.edges (a_id, b_id, weight, meet_count, last_met_at) '
      || 'values (' || quote_literal(tap.dario()) || '::uuid, '
      || quote_literal(tap.cvita()) || '::uuid, 0.5, 1, now())'),
    '23514',
    'an edge cannot be stored in the reversed order');

  return next is(
    tap.attempt(
      'insert into public.exclusions (a_id, b_id, reason) values ('
      || quote_literal(tap.dario()) || '::uuid, '
      || quote_literal(tap.bruno()) || '::uuid, ''block'')'),
    '23514',
    'nor an exclusion');

  return next is(
    tap.attempt(
      'insert into public.ratings (hangout_id, rater_id, subject_id, '
      || 'enjoyment, respect) values ('
      || quote_literal(tap.h_after()) || '::uuid, '
      || quote_literal(tap.alice()) || '::uuid, '
      || quote_literal(tap.alice()) || '::uuid, ''enjoyed'', true)'),
    '23514',
    'and nobody rates themselves');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- What we promised to store, enforced as what we can store. The exit criterion
-- for P1 is that a real signup writes exactly the seven fields we said and
-- nothing else; a surname reaching `last_initial` would be the quiet way that
-- promise breaks.
create function tap.test_a_person_row_stays_minimal()
returns setof text language plpgsql as $fn$
begin
  return next columns_are('public', 'people',
    array['id', 'identity_id', 'auth_user_id', 'first_name', 'last_initial',
          'gender_code', 'city_id', 'home_anchor', 'max_travel_m',
          'joined_at', 'deleted_at'],
    'a person is these eleven columns and no photo, bio, surname or address');

  return next is(
    tap.attempt(
      'update public.people set last_initial = ''Kovač'' where id = '
      || quote_literal(tap.alice()) || '::uuid'),
    '23514',
    'a surname cannot be smuggled into the initial');

  return next is(
    tap.attempt(
      'update public.people set first_name = ''   '' where id = '
      || quote_literal(tap.alice()) || '::uuid'),
    '23514',
    'nor can a blank name be stored, which would render as an empty seat');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
