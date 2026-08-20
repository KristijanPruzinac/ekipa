-- 02 · The seven privacy invariants (02_DOMAIN.md §6).
--
-- These are the acceptance criteria for the whole data plane. A release that
-- fails one does not ship, regardless of what else is in it — and rule 9 of
-- 11_SECURITY.md §8 says the test is the spec, so a feature that trips one of
-- these is the thing that changes.
--
-- Each invariant is tested twice where it can be: once by **asking** (a real
-- session, the `authenticated` role, exactly the privilege a phone has), and
-- once **structurally** (the column does not exist, the constraint forbids it).
-- Asking proves today's configuration is right. Structure proves tomorrow's
-- cannot quietly become wrong.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir ../fixtures/world.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. A person can read only their own availability, confirmations, ratings,
--    reports, standing, infractions.
--
-- Four of those six are stronger than the invariant asks: nobody reads them at
-- all, not even about themselves (DP-3). That is deliberate and it is recorded
-- here so the difference is visible rather than accidental.
create function tap.test_invariant_1_only_your_own()
returns setof text language plpgsql as $fn$
declare
  v_ana   uuid := tap.auth_of(tap.alice());
  v_dario uuid := tap.auth_of(tap.dario());
begin
  return next is(
    tap.count_as(v_ana, 'select 1 from public.availability'), '1',
    'invariant 1: Ana sees her own availability');
  return next is(
    tap.count_as(v_dario, 'select 1 from public.availability'), '0',
    'invariant 1: Dario sees none of Ana''s availability');

  return next is(
    tap.count_as(v_ana, 'select 1 from public.people'), '1',
    'invariant 1: a person row is a person''s own row and nothing else');

  return next is(
    tap.count_as(v_ana, 'select 1 from public.ratings'), 'denied',
    'invariant 1: ratings are readable by nobody, own included');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.reports'), 'denied',
    'invariant 1: reports are readable by nobody, own included');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.standing'), 'denied',
    'invariant 1: standing is readable by nobody, own included');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.infractions'), 'denied',
    'invariant 1: infractions are readable by nobody, own included');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Before REVEALED, a member learns only the hangout's shape.
--
-- The time gate is the interesting half. A client that merely hides the screen
-- has still received the names, and the person who patches the client is the
-- adversary the whole mechanism rests on defeating (T1).
create function tap.test_invariant_2_shape_before_names()
returns setof text language plpgsql as $fn$
declare
  v_ana uuid := tap.auth_of(tap.alice());
begin
  return next is(
    tap.count_as(v_ana, 'select 1 from public.my_hangouts()'), '3',
    'invariant 2: Ana can see that her three hangouts exist');

  return next is(
    tap.value_as(v_ana,
      'select member_count::text from public.my_hangouts() '
      || 'where hangout_id = ' || quote_literal(tap.h_before()) || '::uuid'),
    '3',
    'invariant 2: the shape is available before the reveal');

  return next is(
    tap.value_as(v_ana,
      'select names_visible::text from public.my_hangouts() '
      || 'where hangout_id = ' || quote_literal(tap.h_before()) || '::uuid'),
    'false',
    'invariant 2: the pre-reveal hangout does not claim its names are visible');

  return next is(
    tap.count_as(v_ana,
      'select 1 from public.hangout_reveal('
      || quote_literal(tap.h_before()) || '::uuid)'),
    'denied',
    'invariant 2: the reveal refuses before reveal_at, on the server');

  return next is(
    tap.count_as(v_ana,
      'select 1 from public.hangout_reveal('
      || quote_literal(tap.h_after()) || '::uuid)'),
    '3',
    'invariant 2: and returns the three members once reveal_at has passed');

  -- The gate is a membership check as well as a clock check (DP-7).
  return next is(
    tap.count_as(tap.auth_of(tap.dario()),
      'select 1 from public.hangout_reveal('
      || quote_literal(tap.h_after()) || '::uuid)'),
    'denied',
    'invariant 2: a non-member with a hangout id reads nothing');

  -- Names are the only thing the reveal adds, and it adds them as parts. The
  -- `Marko ····n` mask lives in DisplayName; a second implementation in SQL is
  -- a second place for it to be wrong.
  return next is(
    (select string_agg(a.attname, ',' order by a.attnum)
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       join unnest(p.proargnames, p.proargmodes)
            with ordinality as a (attname, mode, attnum) on true
      where n.nspname = 'public' and p.proname = 'hangout_reveal'
        and a.mode = 't'),
    'person_id,first_name,last_initial,gender_code,is_me,arrived,venue_name,'
    || 'venue_street,standing_spot,opening_hours,step_free,outdoor,'
    || 'walk_minutes,venue_lat,venue_lon,sigil_symbol,sigil_colour,sigil_label',
    'invariant 2: the reveal returns exactly these columns and no diagnostics');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Nobody can ever read how anyone rated them — not the value, not the
--    existence, not an aggregate that leaks it.
--
-- Bruno rated Ana `rather_not`. Everything below is an attempt to find that
-- out, made with exactly the privilege a phone has.
create function tap.test_invariant_3_ratings_are_unknowable()
returns setof text language plpgsql as $fn$
declare
  v_ana   uuid := tap.auth_of(tap.alice());
  v_bruno uuid := tap.auth_of(tap.bruno());
begin
  return next is(
    tap.count_as(v_ana, 'select 1 from public.ratings'), 'denied',
    'invariant 3: the subject cannot read the rating');
  return next is(
    tap.count_as(v_ana,
      'select 1 from public.ratings where subject_id = '
      || quote_literal(tap.alice()) || '::uuid'),
    'denied',
    'invariant 3: nor read whether one exists');
  return next is(
    tap.count_as(v_ana, 'select count(*) from public.ratings'), 'denied',
    'invariant 3: nor an aggregate over them');
  return next is(
    tap.count_as(v_bruno, 'select 1 from public.ratings'), 'denied',
    'invariant 3: the rater cannot read them back either');

  -- No client-callable function reads the table on their behalf. This is the
  -- assertion that survives someone adding a helpful RPC next month.
  --
  -- The match is `from`/`join ratings`, not the bare word: `submit_ratings`
  -- is exactly the client-callable function that must exist, and it only ever
  -- writes (`insert into public.ratings ... on conflict do nothing`). A regex
  -- on the word alone would fail permanently the day that function was
  -- written, which is not this invariant — the invariant is that nobody can
  -- read a rating back, not that the table's name may never appear.
  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prokind = 'f'
        and has_function_privilege('authenticated', p.oid, 'execute')
        and pg_get_functiondef(p.oid)
              ~* '\m(from|join)\M\s+(public\.)?ratings\M'),
    '',
    'invariant 3: no function the client may call reads the ratings table');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. The direction of an edge is not stored and cannot be derived.
--
-- Structural, not permissional: there is no column that could hold a direction,
-- so no query can recover who liked whom first. If one-sided liking could pull
-- someone back, being re-matched would leak that they liked you — and *not*
-- being re-matched would leak the opposite.
create function tap.test_invariant_4_edges_have_no_direction()
returns setof text language plpgsql as $fn$
begin
  return next columns_are('public', 'edges',
    array['a_id', 'b_id', 'weight', 'meet_count', 'last_met_at', 'created_at'],
    'invariant 4: an edge has no column that could hold a direction');

  return next is(
    (select count(*)::int from pg_constraint c
      where c.conrelid = 'public.edges'::regclass
        and c.contype = 'c'
        and pg_get_constraintdef(c.oid) ilike '%a_id < b_id%'),
    1,
    'invariant 4: symmetry is a constraint, so ordering cannot encode one');

  return next is(
    tap.count_as(tap.auth_of(tap.alice()), 'select 1 from public.edges'),
    'denied',
    'invariant 4: and the table is unreadable anyway');

  -- `via_person_id` names an edge outright — it is the whole friend graph in
  -- one column — so it must never leave the server.
  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prokind = 'f'
        and has_function_privilege('authenticated', p.oid, 'execute')
        and pg_get_functiondef(p.oid) ~* '\mvia_person_id\M'),
    '',
    'invariant 4: no client-callable function touches via_person_id');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. A decline is invisible: no member can determine who declined or was
--    replaced.
--
-- Bruno declines and Cvita is released mid-test, which is the exact sequence a
-- backfill produces. Ana must see a group that changed size and nothing about
-- whose evening it was.
create function tap.test_invariant_5_declines_are_invisible()
returns setof text language plpgsql as $fn$
declare
  v_ana uuid := tap.auth_of(tap.alice());
begin
  update public.hangout_members
     set confirmation = 'no', confirmed_at = now()
   where hangout_id = tap.h_confirming() and person_id = tap.bruno();
  update public.hangout_members
     set released_at = now()
   where hangout_id = tap.h_confirming() and person_id = tap.cvita();

  return next is(
    tap.value_as(v_ana,
      'select member_count::text from public.my_hangouts() where hangout_id = '
      || quote_literal(tap.h_confirming()) || '::uuid'),
    '2',
    'invariant 5: Ana sees the group is now two');

  return next is(
    tap.value_as(v_ana,
      'select coalesce(my_confirmation::text, ''(none)'') '
      || 'from public.my_hangouts() where hangout_id = '
      || quote_literal(tap.h_confirming()) || '::uuid'),
    '(none)',
    'invariant 5: and her own answer, which is still nothing');

  return next is(
    tap.count_as(v_ana, 'select 1 from public.hangout_members'), 'denied',
    'invariant 5: the membership rows carry the answer and are unreadable');

  -- The column list is the invariant. Adding `who_declined` would have to pass
  -- through here first.
  return next is(
    (select string_agg(a.attname, ',' order by a.attnum)
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       join unnest(p.proargnames, p.proargmodes)
            with ordinality as a (attname, mode, attnum) on true
      where n.nspname = 'public' and p.proname = 'my_hangouts'
        and a.mode = 't'),
    'hangout_id,state,starts_at,ends_at,activity_id,activity_label,'
    || 'is_dating,member_count,gender_mix,my_confirmation,i_arrived,'
    || 'confirm_opens_at,confirm_deadline_at,reveal_at,rating_due_at,'
    || 'names_visible,cancel_reason',
    'invariant 5: my_hangouts returns exactly these columns');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Reports are invisible to the reported person, including the count.
--
-- Bruno reported Ana. If Ana could see the count, a revenge report becomes
-- observable, and an observable trigger is a trigger people learn to avoid
-- rather than a behaviour they stop.
create function tap.test_invariant_6_reports_are_invisible()
returns setof text language plpgsql as $fn$
declare
  v_ana uuid := tap.auth_of(tap.alice());
begin
  return next is(
    tap.count_as(v_ana, 'select 1 from public.reports'), 'denied',
    'invariant 6: the reported person cannot read the report');
  return next is(
    tap.count_as(v_ana,
      'select count(*) from public.reports where subject_id = '
      || quote_literal(tap.alice()) || '::uuid'),
    'denied',
    'invariant 6: nor the count');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.exclusions'), 'denied',
    'invariant 6: nor the exclusion a rather_not creates');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.infractions'), 'denied',
    'invariant 6: nor the infraction it wrote');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Standing, trust score and any respect aggregate are service-role only.
--
-- Not even to the person it is about: a visible standing becomes a status game
-- within a week, and the respect signal is one bit from three strangers — far
-- too coarse to justify telling anyone what it says about them.
--
-- The single exception is a *visible* sanction, and it is an exception on
-- purpose: a suspension a person cannot see is a suspension they cannot appeal
-- (GDPR Art. 22).
create function tap.test_invariant_7_standing_is_server_only()
returns setof text language plpgsql as $fn$
declare
  v_ana   uuid := tap.auth_of(tap.alice());
  v_bruno uuid := tap.auth_of(tap.bruno());
begin
  return next is(
    tap.count_as(v_ana, 'select 1 from public.standing'), 'denied',
    'invariant 7: a person cannot read their own standing');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.match_runs'), 'denied',
    'invariant 7: nor anything the matcher recorded about them');
  return next is(
    tap.count_as(v_ana, 'select 1 from public.match_run_groups'), 'denied',
    'invariant 7: nor why their group was built that way');

  return next is(
    tap.count_as(v_ana, 'select 1 from public.sanctions'), '1',
    'invariant 7: Ana sees the suspension she can already feel');
  return next is(
    tap.count_as(v_bruno, 'select 1 from public.sanctions'), '0',
    'invariant 7: Bruno''s silent throttle stays silent');
  return next is(
    tap.value_as(v_ana,
      'select kind::text from public.sanctions'), 'SUSPENSION',
    'invariant 7: and what she sees is the sanction, not the score behind it');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
